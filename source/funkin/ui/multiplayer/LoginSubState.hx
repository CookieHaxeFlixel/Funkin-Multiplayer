package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.math.FlxPoint;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerAccountManager;
import funkin.api.discord.auth.DiscordAuthServer;
import funkin.api.discord.auth.DiscordAuthServer.DiscordProfile;

/**
 * Card que aparece por cima da OnlineMenuState quando a conta ainda
 * não tem login do Discord vinculado. Fundo é o FunkinSprite
 * "bgAttentionInternet" (só tem anim idle), com um botão roxo
 * "Logar com Discord" por cima.
 */
class LoginSubState extends MusicBeatSubState
{
  var account:Dynamic;
  var onLoggedIn:Null<(profile:DiscordProfile) -> Void>;
  var dim:Null<FunkinSprite> = null;
  var cardSprite:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var loginButton:Null<FlxButton> = null;
  var statusText:Null<FlxText> = null;
  var authServer:Null<DiscordAuthServer> = null;
  var loginHovered:Bool = false;

  public function new(account:Dynamic, ?onLoggedIn:(profile:DiscordProfile) -> Void)
  {
    super();
    this.account = account;
    this.onLoggedIn = onLoggedIn;
  }

  override function create():Void
  {
    super.create();

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    // ---- Card (FunkinSprite, só tem idle) ----
    cardSprite = new FunkinSprite(0, 0);
    cardSprite.frames = Paths.getSparrowAtlas('bgAttentionInternet');
    cardSprite.animation.addByPrefix('idle', 'bgAttentionIdle', 24, true);
    cardSprite.animation.play('idle');
    cardSprite.antialiasing = true;
    cardSprite.screenCenter();
    add(cardSprite);

    titleText = new FlxText(cardSprite.x, cardSprite.y + 24, cardSprite.width, 'FAÇA LOGIN PRA JOGAR ONLINE', 20);
    titleText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFFFF, CENTER);
    add(titleText);

    statusText = new FlxText(cardSprite.x, cardSprite.y + cardSprite.height - 70, cardSprite.width, '', 16);
    statusText.setFormat(Paths.font('vcr.ttf'), 16, 0xFFB7C8FF, CENTER);
    add(statusText);

    // ---- Botão roxo "Logar com Discord" ----
    loginButton = new FlxButton(0, 0, 'LOGAR COM DISCORD', onLoginPressed);
    loginButton.color = 0xFF5865F2; // roxo/azulado, cor da marca do Discord
    loginButton.label.color = 0xFFFFFFFF;
    loginButton.scale.set(1.4, 1.4);
    loginButton.updateHitbox();
    loginButton.x = cardSprite.x + (cardSprite.width - loginButton.width) / 2;
    loginButton.y = cardSprite.y + cardSprite.height - 110;
    add(loginButton);
  }

  function onLoginPressed():Void
  {
    if (statusText != null) statusText.text = 'Abrindo navegador pra login...';

    authServer = new DiscordAuthServer(8083);
    authServer.onLogin = onDiscordLogin;

    try
    {
      authServer.start();
      authServer.openLoginPage();
    }
    catch (e:Dynamic)
    {
      trace('[Login] falha ao abrir servidor de auth: ' + e);
      if (statusText != null) statusText.text = 'Falha ao abrir o navegador. Tenta de novo.';
    }
  }

  // Chamado (de outra thread) quando o navegador manda o perfil do Discord de volta.

  function onDiscordLogin(profile:DiscordProfile):Void
  {
    trace('[Login] logado como ' + profile.username);

    // Volta pra main thread antes de mexer em sprites/flixel.
    haxe.MainLoop.runInMainThread(() ->
    {
      // NOTA: presumindo que MultiplayerAccountManager tem esse método.
      // Se o nome real for diferente, só trocar aqui.
      MultiplayerAccountManager.linkDiscordAccount(account, profile);

      if (statusText != null) statusText.text = 'Logado como ' + profile.username + '!';

      if (authServer != null)
      {
        authServer.stop();
        authServer = null;
      }

      if (onLoggedIn != null) onLoggedIn(profile);

      close();
    });
  }

  override function destroy():Void
  {
    if (authServer != null)
    {
      authServer.stop();
      authServer = null;
    }
    super.destroy();
  }
}
