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
    MultiplayerInviteService.instance.respondToInvite(invite, true);

    // TODO: aqui é a parte que ainda não existe de verdade — conectar no
    // server do host (invite.serverId / invite.port) igual o
    // connectOnline() da OnlineMenuState faz manualmente hoje, só que
    // automático a partir do convite recebido. Provavelmente:
    //
    //   var c = new MultiplayerClient(enderecoDoHost, invite.port);
    //   c.onConnect = () -> ...
    //   #if MULTIPLAYER_FEATURE
    //   PlayState.multiplayerClient = c;
    //   PlayState.multiplayerMatchActive = true;
    //   #end
    //   c.connect();
    //
    // O "enderecoDoHost" é o problema: hoje connectOnline() usa
    // '127.0.0.1' fixo (só funciona porque host e guest tão na mesma
    // máquina/rede local nos testes). Convite via Discord implica gente
    // em redes diferentes — vai precisar de NAT traversal ou de o relay
    // devolver um endereço público/túnel junto do convite.

    close();
  }

  function onDiscardPressed():Void
  {
    MultiplayerInviteService.instance.respondToInvite(invite, false);
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (FlxG.keys.justPressed.ESCAPE) onDiscardPressed();
  }
}
