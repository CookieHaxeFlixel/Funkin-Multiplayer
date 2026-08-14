package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.RemoteImageLoader;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;
import funkin.multiplayer.MultiplayerClient;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.data.song.SongRegistry;
import funkin.ui.transition.LoadingState;

/**
 * Card que aparece no PC do CONVIDADO quando alguém manda um convite.
 * Avatar + nick do Discord em cima, ACCEPT (verde, texto branco) e
 * DISCARD (vermelho, texto branco) embaixo.
 *
 * Quem abre esse card é quem estiver escutando
 * `MultiplayerInviteService.instance.onInviteReceived` — hoje isso tá
 * plugado na OnlineMenuState (ver ajuste nesse arquivo).
 */
class InviteNotificationSubState extends MusicBeatSubState
{
  var invite:InviteInfo;

  var dim:Null<FunkinSprite> = null;
  var cardBg:Null<FunkinSprite> = null;
  var avatarSprite:Null<FlxSprite> = null;
  var nickText:Null<FlxText> = null;
  var acceptButton:Null<FlxButton> = null;
  var discardButton:Null<FlxButton> = null;
  var cancelButton:Null<FlxButton> = null;

  var client:Null<MultiplayerClient> = null;
  var accepted:Bool = false;

  public function new(invite:InviteInfo)
  {
    super();
    this.invite = invite;
  }

  override function create():Void
  {
    super.create();

    final cardW:Int = 360;
    final cardH:Int = 260;
    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    cardBg = new FunkinSprite(cardX, cardY);
    cardBg.makeSolidColor(cardW, cardH, 0xFF1B2436);
    add(cardBg);

    avatarSprite = new FlxSprite(cardX + (cardW - 80) / 2, cardY + 24);
    avatarSprite.makeGraphic(80, 80, 0xFF4A4A4A); // placeholder até o avatar real carregar
    add(avatarSprite);
    RemoteImageLoader.loadInto(avatarSprite, invite.avatarUrl, () ->
    {
      avatarSprite.setGraphicSize(80, 80);
      avatarSprite.updateHitbox();
      avatarSprite.x = cardX + (cardW - avatarSprite.width) / 2;
    });

    nickText = new FlxText(cardX, cardY + 112, cardW, invite.username + ' te convidou pra jogar!', 18);
    nickText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFFFFFFF, CENTER);
    add(nickText);

    acceptButton = new FlxButton(cardX + 24, cardY + cardH - 70, 'ACCEPT', onAcceptPressed);
    acceptButton.color = 0xFF2ECC71; // verde
    acceptButton.label.color = 0xFFFFFFFF;
    acceptButton.scale.set(1.3, 1.3);
    acceptButton.updateHitbox();
    add(acceptButton);

    discardButton = new FlxButton(cardX + cardW - 24 - acceptButton.width, cardY + cardH - 70, 'DISCARD', onDiscardPressed);
    discardButton.color = 0xFFE74C3C; // vermelho
    discardButton.label.color = 0xFFFFFFFF;
    discardButton.scale.set(1.3, 1.3);
    discardButton.updateHitbox();
    add(discardButton);
  }

  function onAcceptPressed():Void
  {
    if (accepted) return; // já clicou, evita clique duplo
    accepted = true;

    MultiplayerInviteService.instance.respondToInvite(invite, true);

    var sessionId:Null<String> = invite.inviteId;
    if (sessionId == null)
    {
      trace('[Invite] convite sem sessionId (inviteId), não dá pra conectar.');
      close();
      return;
    }
    final relaySessionId:String = sessionId; // narrow pra String de verdade, pra usar dentro das closures abaixo

    // troca os botões por um estado de "conectando", com um jeito de desistir
    showWaitingState();

    client = new MultiplayerClient();

    client.onConnect = () ->
    {
      trace('[Invite] conectado ao host pelo relay, aguardando o host escolher a música.');
      if (nickText != null) nickText.text = 'Conectado! Aguardando o host começar...';
    };

    client.onDisconnect = () ->
    {
      trace('[Invite] desconectado do host antes da partida começar.');
      if (nickText != null) nickText.text = 'O host saiu antes de começar.';
    };

    client.onMessage = (data:Dynamic) ->
    {
      if (data == null || !Reflect.hasField(data, 'type')) return;
      if (Std.string(Reflect.field(data, 'type')) != 'match_start') return;

      startMatch(relaySessionId, data);
    };

    #if MULTIPLAYER_FEATURE
    PlayState.multiplayerClient = client;
    PlayState.multiplayerMatchActive = true;
    PlayState.multiplayerMatchId = relaySessionId;
    #end

    client.connectRelay(relaySessionId);
  }

  /** Substitui ACCEPT/DISCARD por uma mensagem de espera + botão de cancelar. */
  function showWaitingState():Void
  {
    if (nickText != null) nickText.text = 'Conectando com ' + invite.username + '...';

    if (acceptButton != null)
    {
      remove(acceptButton);
      acceptButton = null;
    }
    if (discardButton != null)
    {
      remove(discardButton);
      discardButton = null;
    }

    final cardW:Int = 360;
    final cardH:Int = 260;
    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    cancelButton = new FlxButton(cardX + (cardW - 140) / 2, cardY + cardH - 70, 'CANCELAR', onCancelWaitingPressed);
    cancelButton.color = 0xFFE74C3C;
    cancelButton.label.color = 0xFFFFFFFF;
    cancelButton.scale.set(1.1, 1.1);
    cancelButton.updateHitbox();
    add(cancelButton);
  }

  function onCancelWaitingPressed():Void
  {
    if (client != null)
    {
      client.disconnect();
      client = null;
    }

    #if MULTIPLAYER_FEATURE
    if (PlayState.multiplayerMatchId == invite.inviteId)
    {
      PlayState.multiplayerClient = null;
      PlayState.multiplayerMatchActive = false;
      PlayState.multiplayerMatchId = null;
    }
    #end

    close();
  }

  function startMatch(sessionId:String, data:Dynamic):Void
  {
    var songId:String = Std.string(Reflect.field(data, 'songId'));
    var difficulty:String = Reflect.hasField(data, 'difficulty') ? Std.string(Reflect.field(data, 'difficulty')) : 'normal';
    var variation:String = Reflect.hasField(data, 'variation') ? Std.string(Reflect.field(data, 'variation')) : 'default';

    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);
    if (song == null)
    {
      trace('[Invite] host mandou match_start com música desconhecida: ' + songId);
      if (nickText != null) nickText.text = 'Erro: música não encontrada (' + songId + ').';
      return;
    }

    trace('[Invite] match_start recebido, indo pro PlayState em modo multiplayer.');

    close();

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      targetVariation: variation,
      isMultiplayerMode: true
    });
  }

  function onDiscardPressed():Void
  {
    MultiplayerInviteService.instance.respondToInvite(invite, false);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (FlxG.keys.justPressed.ESCAPE)
    {
      if (accepted)
      {
        onCancelWaitingPressed();
      }
      else
      {
        onDiscardPressed();
      }
    }
  }

  override function destroy():Void
  {
    // se o card for destruído sem passar por close() normal (ex: troca de tela abrupta),
    // não deixa o client pendurado tentando falar com um relay que ninguém mais escuta.
    if (client != null && !accepted)
    {
      client.disconnect();
    }
    super.destroy();
  }
}
