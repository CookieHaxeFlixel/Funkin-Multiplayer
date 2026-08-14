package funkin.multiplayer;

/**
 * Client de busca/convite por nick do Discord.
 *
 * ATENÇÃO: isso aqui é um STUB. Não fala com nenhum servidor de verdade
 * ainda. Pra convidar alguém que não tá na sua rede local, precisa de um
 * serviço de matchmaking/relay — um servidor central que sabe quem tá
 * online e consegue entregar o convite pro PC certo. Nenhum arquivo que
 * vocês têm hoje (MultiplayerServer/MultiplayerClient são só pra 1x1
 * direto, sem descoberta de usuário) implementa isso.
 *
 * A interface pública (métodos + typedef abaixo) foi desenhada pra não
 * precisar mudar nada na UI (InviteSearchSubState / InviteResultRow /
 * InviteNotificationSubState / HostMenuSubState) quando o backend real
 * existir — só troca o miolo de cada função marcada com TODO.
 */
class MultiplayerInviteService
{
  public static var instance(default, null):MultiplayerInviteService = new MultiplayerInviteService();

  /** Chamado quando ALGUÉM te manda um convite (você é o convidado). */
  public var onInviteReceived:Null<InviteInfo->Void>;

  var connected:Bool = false;

  function new()
  {
  }

  /**
   * TODO: conectar de verdade no relay/matchmaking (provavelmente um
   * WebSocket pra um server central, autenticado com o discordId que
   * já vem do LoginSubState/DiscordAuthServer). Chame isso uma vez,
   * por exemplo no create() da OnlineMenuState.
   */
  public function connect():Void
  {
    if (connected) return;
    connected = true;
    trace('[Invite] STUB: fingindo estar conectado ao relay de convites. Troque por uma conexão real quando o backend existir.');
  }

  /**
   * Busca usuários do Discord por nick (prefixo/substring). Assíncrono
   * de propósito (callback, não return) porque uma busca de verdade
   * vai bater num servidor.
   */
  public function searchByNick(query:String, callback:Array<InviteInfo>->Void):Void
  {
    if (query == null || query.length == 0)
    {
      callback([]);
      return;
    }

    trace('[Invite] STUB: buscando "$query" — sem backend ainda, devolvendo lista vazia.');
    // TODO: substituir por algo como:
    //   relayClient.send({ type: 'search_user', query: query });
    //   relayClient.onMessage = (data) -> if (data.type == 'search_result') callback(parseResults(data));
    callback([]);
  }

  /**
   * Manda um convite pro usuário `target`, apontando pro server que o
   * host já subiu (endereço/porta do MultiplayerServer local dele — ou
   * um ID que o relay resolve pro endereço real, se o convidado não
   * tiver como alcançar o IP local do host direto).
   */
  public function sendInvite(target:InviteInfo, hostServerId:String, hostPort:Int, ?onSent:Void->Void, ?onError:String->Void):Void
  {
    if (target == null)
    {
      if (onError != null) onError('destino inválido');
      return;
    }

    trace('[Invite] STUB: mandando convite pra ${target.username} (server=$hostServerId, porta=$hostPort). Sem backend ainda.');
    // TODO: relayClient.send({ type: 'invite', targetDiscordId: target.discordId, serverId: hostServerId, port: hostPort });
    if (onSent != null) onSent();
  }

  /** Chame do lado do convidado quando ele apertar ACCEPT/DISCARD. */
  public function respondToInvite(invite:InviteInfo, accept:Bool):Void
  {
    trace('[Invite] STUB: resposta ao convite de ${invite.username}: ' + (accept ? 'ACCEPT' : 'DISCARD') + '. Sem backend ainda.');
    // TODO: relayClient.send({ type: 'invite_response', inviteId: invite.inviteId, accept: accept });
  }

  /**
   * Só pra testar a UI sem precisar do relay: dispara onInviteReceived
   * manualmente, simulando que alguém te convidou. Chame isso do
   * console/debug enquanto o backend real não existe, ex:
   *   MultiplayerInviteService.instance.debugSimulateIncomingInvite(
   *     'amigo123', 'https://cdn.discordapp.com/embed/avatars/0.png', 'ABC123', 2082);
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
