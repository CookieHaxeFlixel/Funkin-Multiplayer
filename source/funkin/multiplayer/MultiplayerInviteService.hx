package funkin.multiplayer;

/**
 * Client de busca/convite por nick do Discord.
 *
 * Backend real: fala com o RelayServer (source/funkin/multiplayer/relay/RelayServer.hx)
 * através do RelayClient (source/funkin/multiplayer/RelayClient.hx). Isso resolve
 * o caso de convite entre PCs em redes diferentes, porque o relay é quem
 * sabe "quem tá online" e entrega a mensagem pro socket certo, sem
 * depender do host abrir porta na própria rede.
 *
 * A interface pública (métodos + typedef abaixo) é a mesma de quando isso
 * era stub — nenhuma tela (InviteSearchSubState / InviteResultRow /
 * InviteNotificationSubState / HostMenuSubState) precisa mudar.
 */
class MultiplayerInviteService
{
  public static var instance(default, null):MultiplayerInviteService = new MultiplayerInviteService();

  /** Endereço do relay central. Troque aqui se o relay morar em outro host/porta. */
  public static var RELAY_HOST:String = "127.0.0.1";
  public static var RELAY_PORT:Int = 8090;

  /** Chamado quando ALGUÉM te manda um convite (você é o convidado). */
  public var onInviteReceived:Null<InviteInfo->Void>;

  /**
   * Chamado do lado de quem CONVIDOU quando o destinatário aceita/recusa.
   * `sessionId` é o mesmo valor passado como `hostServerId` em sendInvite
   * (então dá pra comparar direto com o serverId que você já tem, tipo
   * no HostMenuSubState). Use isso pra saber a hora de trocar o
   * MultiplayerServer pro modo relay (server.startRelay(sessionId)).
   */
  public var onInviteAccepted:Null<String->Void>;
  public var onInviteDeclined:Null<String->Void>;

  var connected:Bool = false;
  var myDiscordId:Null<String> = null;
  var pendingIdentity:Null<{discordId:String, username:String, avatarUrl:String}> = null;

  function new()
  {
  }

  /**
   * Conecta de verdade no relay. Mesma assinatura de antes (sem
   * argumentos) pra não quebrar quem já chama isso hoje (ex: create() da
   * OnlineMenuState). Chame isso uma vez.
   *
   * Sozinho isso só abre a conexão — pra aparecer nas buscas e receber
   * convite de alguém, também é preciso chamar setIdentity(...) com o
   * discordId/username/avatarUrl (pode ser antes ou depois de connect();
   * se chamado antes, o registro é enviado assim que a conexão abrir).
   */
  public function connect():Void
  {
    if (connected) return;

    var relay = RelayClient.instance;

    relay.onError = (msg) -> trace('[Invite] erro no relay: $msg');

    relay.onInviteReceived = (sessionId, fromDiscordId, fromUsername, fromAvatarUrl, hostServerId, hostPort) ->
    {
      if (onInviteReceived == null) return;
      onInviteReceived({
        discordId: fromDiscordId,
        username: fromUsername,
        avatarUrl: fromAvatarUrl,
        inviteId: sessionId,
        serverId: hostServerId,
        port: hostPort
      });
    };

    relay.onInviteResponse = (sessionId, accept) ->
    {
      if (accept)
      {
        if (onInviteAccepted != null) onInviteAccepted(sessionId);
      }
      else
      {
        if (onInviteDeclined != null) onInviteDeclined(sessionId);
      }
    };

    try
    {
      relay.connect(RELAY_HOST, RELAY_PORT);
      connected = true;

      if (pendingIdentity != null)
      {
        relay.register(pendingIdentity.discordId, pendingIdentity.username, pendingIdentity.avatarUrl);
        myDiscordId = pendingIdentity.discordId;
      }
    }
    catch (e:Dynamic)
    {
      trace('[Invite] não deu pra conectar no relay ($RELAY_HOST:$RELAY_PORT): $e');
      connected = false;
    }
  }

  /**
   * Registra quem você é no relay (pra outros conseguirem te buscar/
   * convidar). Chame depois que o discordId/username/avatarUrl da conta
   * estiverem resolvidos (ex: depois do linkDiscordAccount no LoginSubState,
   * ou no create() da OnlineMenuState lendo a conta já vinculada).
   */
  public function setIdentity(discordId:String, username:String, avatarUrl:String):Void
  {
    myDiscordId = discordId;

    if (!connected)
    {
      pendingIdentity = {discordId: discordId, username: username, avatarUrl: avatarUrl};
      return;
    }

    RelayClient.instance.register(discordId, username, avatarUrl);
  }

  /**
   * Busca usuários do Discord por nick (prefixo/substring). Assíncrono
   * porque bate no relay de verdade.
   */
  public function searchByNick(query:String, callback:Array<InviteInfo>->Void):Void
  {
    if (query == null || query.length == 0)
    {
      callback([]);
      return;
    }

    if (!connected)
    {
      trace('[Invite] searchByNick chamado sem estar conectado ao relay.');
      callback([]);
      return;
    }

    RelayClient.instance.searchByNick(query, (results) ->
    {
      var parsed:Array<InviteInfo> = results.map((r) -> ({
        discordId: Std.string(Reflect.field(r, 'discordId')),
        username: Std.string(Reflect.field(r, 'username')),
        avatarUrl: Std.string(Reflect.field(r, 'avatarUrl'))
      } : InviteInfo));
      callback(parsed);
    });
  }

  /**
   * Manda um convite pro usuário `target`, apontando pro server que o
   * host já subiu. `hostServerId` é usado como o sessionId do relay
   * também — é por isso que ele tem que ser o mesmo id que o host mostra
   * na tela (ver HostMenuSubState.serverId) e depois passa pra
   * server.startRelay(serverId) quando o convite for aceito.
   */
  public function sendInvite(target:InviteInfo, hostServerId:String, hostPort:Int, ?onSent:Void->Void, ?onError:String->Void):Void
  {
    if (target == null)
    {
      if (onError != null) onError('destino inválido');
      return;
    }

    if (!connected)
    {
      if (onError != null) onError('sem conexão com o relay');
      return;
    }

    var sessionId:String = hostServerId;

    RelayClient.instance.onInviteError = (sid, reason) ->
    {
      if (sid != sessionId) return;
      if (onError != null) onError(reason);
    };

    RelayClient.instance.sendInvite(target.discordId, sessionId, hostServerId, hostPort);

    if (onSent != null) onSent();
  }

  /**
   * Chame do lado do convidado quando ele apertar ACCEPT/DISCARD.
   * `invite.inviteId` é o sessionId que o relay usa pra parear host e
   * convidado quando o modo relay entrar em jogo (ver MultiplayerServer.startRelay /
   * MultiplayerClient.connectRelay).
   */
  public function respondToInvite(invite:InviteInfo, accept:Bool):Void
  {
    if (!connected)
    {
      trace('[Invite] respondToInvite chamado sem estar conectado ao relay.');
      return;
    }

    RelayClient.instance.respondToInvite(invite.inviteId, accept);
  }

  /**
   * Só pra testar a UI sem precisar do relay: dispara onInviteReceived
   * manualmente, simulando que alguém te convidou.
   */
  public function debugSimulateIncomingInvite(fromUsername:String, fromAvatarUrl:String, serverId:String, port:Int):Void
  {
    if (onInviteReceived == null) return;
    onInviteReceived({
      discordId: 'debug_' + fromUsername,
      username: fromUsername,
      avatarUrl: fromAvatarUrl,
      inviteId: 'debug_invite',
      serverId: serverId,
      port: port
    });
  }
}

typedef InviteInfo =
{
  var discordId:String;
  var username:String;
  var avatarUrl:String;
  var ?inviteId:String;
  var ?serverId:String;
  var ?port:Int;
}
