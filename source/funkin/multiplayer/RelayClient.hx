package funkin.multiplayer;

#if sys
import haxe.Json;
import haxe.io.Bytes;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Thread;
import funkin.multiplayer.relay.WebSocketUtil;

/**
 * Conexão única e persistente com o RelayServer (source/funkin/multiplayer/relay/RelayServer.hx).
 * É o "miolo real" que o MultiplayerInviteService usa no lugar do stub, e
 * também o transporte que MultiplayerServer/MultiplayerClient usam quando
 * estão em "modo relay" (host e convidado em redes diferentes).
 *
 * Uso esperado (ver MultiplayerInviteService.connect()):
 *   RelayClient.instance.connect(RELAY_HOST, RELAY_PORT);
 *   RelayClient.instance.register(discordId, username, avatarUrl);
 */
class RelayClient
{
  public static var instance(default, null):RelayClient = new RelayClient();

  public var connected(get, never):Bool;
  public var onError:Null<String->Void>;

  // callbacks de alto nível pro MultiplayerInviteService plugar
  public var onInviteReceived:Null<(sessionId:String, fromDiscordId:String, fromUsername:String, fromAvatarUrl:String, hostServerId:String,
    hostPort:Int) -> Void>;
  public var onInviteResponse:Null<(sessionId:String, accept:Bool) -> Void>;
  public var onInviteError:Null<(sessionId:String, reason:String) -> Void>;

  var socket:Null<Socket>;
  var running:Bool = false;
  var readThread:Null<Thread> = null;

  var host:String = "127.0.0.1";
  var port:Int = 8090;

  var searchCallbacks:Map<String, Array<Dynamic>->Void> = new Map();
  var relayDataHandlers:Map<String, Dynamic->Void> = new Map();
  var relayPeerReadyHandlers:Map<String, Void->Void> = new Map();
  var nextRequestId:Int = 0;

  function new()
  {
  }

  function get_connected():Bool
  {
    return socket != null && running;
  }

  public function connect(host:String = "127.0.0.1", port:Int = 8090):Void
  {
    if (connected) return;

    this.host = host;
    this.port = port;

    socket = new Socket();
    socket.setTimeout(6000);
    socket.connect(new Host(host), port);

    WebSocketUtil.performClientHandshake(socket, host, port);

    running = true;
    readThread = Thread.create(readLoop);
  }

  public function disconnect():Void
  {
    running = false;
    if (socket != null)
    {
      try
        socket.close()
      catch (_)
      {
      }
      socket = null;
    }
  }

  public function register(discordId:String, username:String, avatarUrl:String):Void
  {
    send({type: 'register', discordId: discordId, username: username, avatarUrl: avatarUrl});
  }

  public function searchByNick(query:String, callback:Array<Dynamic>->Void):Void
  {
    var requestId:String = 'req_' + (nextRequestId++);
    searchCallbacks.set(requestId, callback);
    send({type: 'search_user', query: query, requestId: requestId});
  }

  public function sendInvite(targetDiscordId:String, sessionId:String, hostServerId:String, hostPort:Int):Void
  {
    send({type: 'invite', targetDiscordId: targetDiscordId, sessionId: sessionId, hostServerId: hostServerId, hostPort: hostPort});
  }

  public function respondToInvite(sessionId:String, accept:Bool):Void
  {
    send({type: 'invite_response', sessionId: sessionId, accept: accept});
  }

  /**
   * Entra numa sessão de relay (depois que o convite foi aceito). `onData`
   * é chamado toda vez que o outro lado manda algo por `sendRelayData`.
   * `onPeerReady` é chamado quando o outro lado também entrou na sessão —
   * é o sinal de "pode começar a jogar".
   */
  public function joinRelaySession(sessionId:String, onData:Dynamic->Void, ?onPeerReady:Void->Void):Void
  {
    relayDataHandlers.set(sessionId, onData);
    if (onPeerReady != null) relayPeerReadyHandlers.set(sessionId, onPeerReady);
    send({type: 'relay_join', sessionId: sessionId});
  }

  public function leaveRelaySession(sessionId:String):Void
  {
    relayDataHandlers.remove(sessionId);
    relayPeerReadyHandlers.remove(sessionId);
    send({type: 'relay_leave', sessionId: sessionId});
  }

  public function sendRelayData(sessionId:String, payload:Dynamic):Void
  {
    send({type: 'relay_data', sessionId: sessionId, payload: payload});
  }

  function send(data:Dynamic):Void
  {
    if (!connected || socket == null) return;
    try
    {
      var frame:Bytes = WebSocketUtil.buildFrame(Json.stringify(data));
      socket.output.writeBytes(frame, 0, frame.length);
      socket.output.flush();
    }
    catch (e:Dynamic)
    {
      if (onError != null) onError('RelayClient falhou ao enviar: $e');
    }
  }

  function readLoop():Void
  {
    while (running && socket != null)
    {
      var text:Null<String> = null;
      try
      {
        text = WebSocketUtil.readFrameText(socket, () -> send({type: 'pong'}));
      }
      catch (e:Dynamic)
      {
        if (onError != null) onError('RelayClient erro de socket: $e');
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

      dispatch(data);
    }

    running = false;
  }

  function dispatch(data:Dynamic):Void
  {
    var type:String = Std.string(Reflect.field(data, 'type'));

    switch (type)
    {
      case 'search_result':
        var requestId:String = Std.string(Reflect.field(data, 'requestId'));
        var cb:Null<Array<Dynamic>->Void> = searchCallbacks.get(requestId);
        if (cb != null)
        {
          searchCallbacks.remove(requestId);
          var results:Array<Dynamic> = Reflect.field(data, 'results');
          cb(results != null ? results : []);
        }

      case 'invite_received':
        if (onInviteReceived != null)
        {
          onInviteReceived(Std.string(Reflect.field(data, 'sessionId')), Std.string(Reflect.field(data, 'fromDiscordId')),
            Std.string(Reflect.field(data, 'fromUsername')), Std.string(Reflect.field(data, 'fromAvatarUrl')),
            Std.string(Reflect.field(data, 'hostServerId')), Std.int(Reflect.field(data, 'hostPort')));
        }

      case 'invite_response':
        if (onInviteResponse != null)
        {
          onInviteResponse(Std.string(Reflect.field(data, 'sessionId')), Reflect.field(data, 'accept') == true);
        }

      case 'invite_error':
        if (onInviteError != null)
        {
          onInviteError(Std.string(Reflect.field(data, 'sessionId')), Std.string(Reflect.field(data, 'reason')));
        }

      case 'relay_data':
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));
        var handler:Null<Dynamic->Void> = relayDataHandlers.get(sessionId);
        if (handler != null) handler(Reflect.field(data, 'payload'));

      case 'relay_peer_ready':
        var sessionId:String = Std.string(Reflect.field(data, 'sessionId'));
        var handler:Null<Void->Void> = relayPeerReadyHandlers.get(sessionId);
        if (handler != null) handler();

      case 'relay_peer_left', 'registered', 'invite_sent', 'relay_joined', 'pong':
      // sem ação necessária hoje; deixa aberto pra UI escutar via onError/logs se precisar

      default:
    }
  }
}
#else
class RelayClient
{
  public static var instance(default, null):RelayClient = new RelayClient();

  public var connected(get, never):Bool;
  public var onError:Null<String->Void>;
  public var onInviteReceived:Null<(sessionId:String, fromDiscordId:String, fromUsername:String, fromAvatarUrl:String, hostServerId:String,
    hostPort:Int) -> Void>;
  public var onInviteResponse:Null<(sessionId:String, accept:Bool) -> Void>;
  public var onInviteError:Null<(sessionId:String, reason:String) -> Void>;

  function new()
  {
  }

  function get_connected():Bool
  {
    return false;
  }

  public function connect(host:String = "127.0.0.1", port:Int = 8090):Void
  {
  }

  public function disconnect():Void
  {
  }

  public function register(discordId:String, username:String, avatarUrl:String):Void
  {
  }

  public function searchByNick(query:String, callback:Array<Dynamic>->Void):Void
  {
    callback([]);
  }

  public function sendInvite(targetDiscordId:String, sessionId:String, hostServerId:String, hostPort:Int):Void
  {
  }

  public function respondToInvite(sessionId:String, accept:Bool):Void
  {
  }

  public function joinRelaySession(sessionId:String, onData:Dynamic->Void, ?onPeerReady:Void->Void):Void
  {
  }

  public function leaveRelaySession(sessionId:String):Void
  {
  }

  public function sendRelayData(sessionId:String, payload:Dynamic):Void
  {
  }
}
#end
