package funkin.multiplayer.relay;

#if sys
import haxe.Json;
import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;
import sys.thread.Mutex;

/**
 * Servidor relay standalone. NÃO é pra rodar dentro do jogo — é um
 * processo separado, num servidor/VPS com IP público, que:
 *
 *   1. Deixa cada instância do jogo se registrar com o discordId de quem
 *      logou (login/discord já resolvidos no client, isso aqui só guarda
 *      "esse discordId tá online nesse socket").
 *   2. Responde busca de usuário por nick (search_user).
 *   3. Entrega convite (invite) pro discordId de destino, e a resposta
 *      dele (invite_response) de volta pra quem convidou.
 *   4. Depois que o convite é aceito, faz o relay puro de mensagens
 *      (relay_data) entre host e convidado sob um sessionId — isso é o
 *      que resolve o problema de host e convidado estarem em redes/NAT
 *      diferentes, sem precisar de port-forward manual.
 *
 * Compile isso separado do jogo (veja relay.hxml), não faz parte do
 * build do V-Slice.
 */
class RelayServer
{
  public static function main():Void
  {
    var port:Int = 8090;
    var args = Sys.args();
    if (args.length > 0)
    {
      var parsed = Std.parseInt(args[0]);
      if (parsed != null) port = parsed;
    }

    var server = new RelayServer(port);
    server.start();

    Sys.println('[RelayServer] rodando na porta $port. Ctrl+C pra parar.');
    while (true)
    {
      Sys.sleep(60);
    }
  }

  var port:Int;
  var listener:Null<Socket>;
  var running:Bool = false;

  var mutex:Mutex = new Mutex();
  var clients:Map<String, ClientConn> = new Map(); // connId -> conn
  var byDiscordId:Map<String, ClientConn> = new Map(); // discordId -> conn
  var pendingInvites:Map<String, ClientConn> = new Map(); // sessionId -> quem convidou
  var sessions:Map<String, Array<ClientConn>> = new Map(); // sessionId -> [conn, conn]

  var nextConnId:Int = 0;

  public function new(port:Int = 8090)
  {
    this.port = port;
  }

  public function start():Void
  {
    if (running) return;

    listener = new Socket();
    listener.setFastSend(true);
    listener.bind(new Host("0.0.0.0"), port);
    listener.listen(64);
    running = true;

    Thread.create(acceptLoop);
  }

  public function stop():Void
  {
    running = false;
    if (listener != null)
    {
      try
        listener.close()
      catch (_)
      {
      }
      listener = null;
    }
  }

  function acceptLoop():Void
  {
    while (running && listener != null)
    {
      try
      {
        var sock:Socket = listener.accept();
        if (sock == null) continue;

        var conn = new ClientConn(sock, Std.string(nextConnId++));
        Thread.create(() -> handleClient(conn));
      }
      catch (e:Dynamic)
      {
        if (running) Sys.println('[RelayServer] erro no accept: $e');
      }
    }
  }

  function handleClient(conn:ClientConn):Void
  {
    try
    {
      WebSocketUtil.performServerHandshake(conn.socket);
    }
    catch (e:Dynamic)
    {
      Sys.println('[RelayServer] handshake falhou: $e');
      safeClose(conn);
      return;
    }

    mutex.acquire();
    clients.set(conn.id, conn);
    mutex.release();

    while (running)
    {
      var text:Null<String> = null;
      try
      {
        text = WebSocketUtil.readFrameText(conn.socket, () -> conn.send({type: 'pong'}));
      }
      catch (e:Dynamic)
      {
        break;
      }

      if (text == null) break;
      if (text.length == 0) continue;

      var data:Dynamic = null;
      try
      {
        data = Json.parse(text);
      }
      catch (e:Dynamic)
      {
        continue;
      }

      handleMessage(conn, data);
    }

    onDisconnect(conn);
  }

  function handleMessage(conn:ClientConn, data:Dynamic):Void
  {
    var type:String = Std.string(Reflect.field(data, 'type'));

    switch (type)
    {
      case 'register':
        conn.discordId = Std.string(Reflect.field(data, 'discordId'));
        conn.username = Std.string(Reflect.field(data, 'username'));
        conn.avatarUrl = Std.string(Reflect.field(data, 'avatarUrl'));

        mutex.acquire();
        byDiscordId.set(conn.discordId, conn);
        mutex.release();

        conn.send({type: 'registered', discordId: conn.discordId});

      case 'search_user':
        var query:String = Std.string(Reflect.field(data, 'query')).toLowerCase();
        var requestId:String = Std.string(Reflect.field(data, 'requestId'));
        var results:Array<Dynamic> = [];

        mutex.acquire();
        for (c in byDiscordId)
        {
          if (c.username != null && c.username.toLowerCase().indexOf(query) != -1 && c.discordId != conn.discordId)
          {
            results.push({discordId: c.discordId, username: c.username, avatarUrl: c.avatarUrl});
          }
        }
        mutex.release();

        conn.send({type: 'search_result', requestId: requestId, results: results});

      case 'invite':
        var targetDiscordId:String = Std.string(Reflect.field(data, 'targetDiscordId'));
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));

        mutex.acquire();
        var target:Null<ClientConn> = byDiscordId.get(targetDiscordId);
        mutex.release();

        if (target == null)
        {
          conn.send({type: 'invite_error', sessionId: sessionId, reason: 'user_offline'});
          return;
        }

        mutex.acquire();
        pendingInvites.set(sessionId, conn);
        mutex.release();

        target.send({
          type: 'invite_received',
          sessionId: sessionId,
          fromDiscordId: conn.discordId,
          fromUsername: conn.username,
          fromAvatarUrl: conn.avatarUrl,
          hostServerId: Reflect.field(data, 'hostServerId'),
          hostPort: Reflect.field(data, 'hostPort')
        });

        conn.send({type: 'invite_sent', sessionId: sessionId});

      case 'invite_response':
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));
        var accept:Bool = Reflect.field(data, 'accept') == true;

        mutex.acquire();
        var inviter:Null<ClientConn> = pendingInvites.get(sessionId);
        if (!accept) pendingInvites.remove(sessionId);
        mutex.release();

        if (inviter != null)
        {
          inviter.send({
            type: 'invite_response',
            sessionId: sessionId,
            accept: accept,
            fromDiscordId: conn.discordId,
            fromUsername: conn.username
          });
        }

      case 'relay_join':
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));

        mutex.acquire();
        var arr:Array<ClientConn> = sessions.exists(sessionId) ? sessions.get(sessionId) : [];
        if (arr.indexOf(conn) == -1) arr.push(conn);
        sessions.set(sessionId, arr);
        mutex.release();

        conn.send({type: 'relay_joined', sessionId: sessionId, peers: arr.length});

        // avisa o outro lado (se já tiver entrado) que o par está pronto
        for (peer in arr)
        {
          if (peer != conn) peer.send({type: 'relay_peer_ready', sessionId: sessionId});
        }

      case 'relay_data':
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));
        var payload:Dynamic = Reflect.field(data, 'payload');

        mutex.acquire();
        var arr:Null<Array<ClientConn>> = sessions.get(sessionId);
        mutex.release();

        if (arr == null) return;
        for (peer in arr)
        {
          if (peer != conn) peer.send({type: 'relay_data', sessionId: sessionId, payload: payload});
        }

      case 'relay_leave':
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));
        leaveSession(conn, sessionId);

      default:
      // tipo desconhecido, ignora
    }
  }

  function leaveSession(conn:ClientConn, sessionId:String):Void
  {
    mutex.acquire();
    var arr:Null<Array<ClientConn>> = sessions.get(sessionId);
    if (arr != null)
    {
      arr.remove(conn);
      if (arr.length == 0)
      {
        sessions.remove(sessionId);
      }
      else
      {
        sessions.set(sessionId, arr);
        for (peer in arr) peer.send({type: 'relay_peer_left', sessionId: sessionId});
      }
    }
    mutex.release();
  }

  function onDisconnect(conn:ClientConn):Void
  {
    mutex.acquire();
    clients.remove(conn.id);
    if (conn.discordId != null && byDiscordId.get(conn.discordId) == conn)
    {
      byDiscordId.remove(conn.discordId);
    }
    for (sessionId => arr in sessions)
    {
      if (arr.indexOf(conn) != -1)
      {
        arr.remove(conn);
        sessions.set(sessionId, arr);
        for (peer in arr) peer.send({type: 'relay_peer_left', sessionId: sessionId});
      }
    }
    mutex.release();

    safeClose(conn);
  }

  function safeClose(conn:ClientConn):Void
  {
    try
      conn.socket.close()
    catch (_)
    {
    }
  }
}

private class ClientConn
{
  public var socket:Socket;
  public var id:String;
  public var discordId:Null<String> = null;
  public var username:Null<String> = null;
  public var avatarUrl:Null<String> = null;

  var writeMutex:Mutex = new Mutex();

  public function new(socket:Socket, id:String)
  {
    this.socket = socket;
    this.id = id;
  }

  public function send(data:Dynamic):Void
  {
    writeMutex.acquire();
    try
    {
      var frame:Bytes = WebSocketUtil.buildFrame(Json.stringify(data));
      socket.output.writeBytes(frame, 0, frame.length);
      socket.output.flush();
    }
    catch (_)
    {
    }
    writeMutex.release();
  }
}
#end
