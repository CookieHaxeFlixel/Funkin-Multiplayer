package funkin.multiplayer;

import funkin.multiplayer.MultiplayerServer;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.ui.transition.LoadingState;

/**
 * Ponte entre o HostMenuSubState e a tela de Freeplay.
 *
 * Fluxo novo:
 *   1. Host abre HostMenuSubState, espera o convidado conectar.
 *   2. Host aperta o botão LIGAR (só libera com o convidado dentro).
 *   3. HostMenuSubState fecha, marca `MultiplayerHostSession.active = true`
 *      e o OnlineMenuState troca de tela pro Freeplay.
 *   4. Host escolhe música + dificuldade no Freeplay normalmente.
 *
 * ATENÇÃO — isso aqui é o ponto que falta plugar: eu não tenho o
 * arquivo do FreeplayState de vocês, então não sei o nome exato do
 * callback/evento de "música confirmada" nele. Assim que tiver:
 * chama `MultiplayerHostSession.startMatch(song, difficulty, variation)`
 * no lugar onde o Freeplay hoje chama LoadingState.loadPlayState (ou
 * substitui essa chamada por essa daqui quando
 * `MultiplayerHostSession.active` for true). Me manda o FreeplayState.hx
 * que eu conecto certinho, sem chutar a API.
 */
class MultiplayerHostSession
{
  /** True entre o host apertar LIGAR e a partida realmente começar. */
  public static var active:Bool = false;

  /** ID de exibição da partida (o mesmo `serverId` do HostMenuSubState). */
  public static var serverId:String = '';

  /**
   * Chame isso quando o host confirmar a música no Freeplay (com
   * `active == true`). Avisa o convidado (via MultiplayerServer.instance,
   * que continua rodando desde o HostMenuSubState) e carrega o
   * PlayState multiplayer pros dois ao mesmo tempo.
   */
  public static function startMatch(song:Song, difficulty:String, variation:String):Void
  {
    if (!active) return;

    if (MultiplayerServer.instance != null)
    {
      MultiplayerServer.instance.broadcast({
        type: 'match_start',
        songId: song.id,
        difficulty: difficulty,
        variation: variation
      });
    }
    else
    {
      trace('[MultiplayerHostSession] ATENÇÃO: startMatch chamado sem MultiplayerServer.instance ativo.');
    }

    #if MULTIPLAYER_FEATURE
    // O host não é client de si mesmo — mesma lógica que já tinha no
    // HostMenuSubState antigo.
    PlayState.multiplayerClient = null;
    PlayState.multiplayerMatchActive = true;
    PlayState.multiplayerMatchId = serverId;
    #end

    active = false;

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      targetVariation: variation,
      isMultiplayerMode: true
    });
  }

  /** Cancela a sessão pendente (ex: host desistiu antes de escolher música). */
  public static function cancel():Void
  {
    active = false;
    serverId = '';
  }
}
