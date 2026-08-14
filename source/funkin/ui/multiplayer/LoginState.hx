package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.multiplayer.MultiplayerAccountManager;

class LoginState extends MusicBeatState
{
  var bg:Null<FunkinSprite> = null;
  var title:Null<FlxText> = null;
  var statusText:Null<FlxText> = null;
  var usernameText:Null<FlxText> = null;
  var usernameValue:Null<FlxText> = null;
  var idText:Null<FlxText> = null;
  var idValue:Null<FlxText> = null;
  var loginButton:Null<FlxButton> = null;
  var createButton:Null<FlxButton> = null;
  var confirmButton:Null<FlxButton> = null;
  var backButton:Null<FlxButton> = null;
  var currentAccount:Dynamic = null;
  var isLoginMode:Bool = true;

  override function create():Void
  {
    super.create();

    FlxG.mouse.visible = true;

    bg = new FunkinSprite(0, 0);
    bg.makeSolidColor(FlxG.width, FlxG.height, 0xFF121826);
    add(bg);

    title = new FlxText(0, 40, FlxG.width, 'MULTIPLAYER LOGIN', 34);
    if (title != null)
    {
      title.setFormat(Paths.font('vcr.ttf'), 34, 0xFFFFFFFF, CENTER);
      add(title);
    }

    statusText = new FlxText(0, 110, FlxG.width, '', 18);
    if (statusText != null)
    {
      statusText.setFormat(Paths.font('vcr.ttf'), 18, 0xFFB7C8FF, CENTER);
      add(statusText);
    }

    usernameText = new FlxText(180, 200, 240, 'USERNAME', 20);
    if (usernameText != null)
    {
      usernameText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFFFF, LEFT);
      add(usernameText);
    }

    usernameValue = new FlxText(440, 200, 300, '', 20);
    if (usernameValue != null)
    {
      usernameValue.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFEE88, LEFT);
      add(usernameValue);
    }

    idText = new FlxText(180, 260, 240, 'ID', 20);
    if (idText != null)
    {
      idText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFFFFFFF, LEFT);
      add(idText);
    }

    idValue = new FlxText(440, 260, 300, '', 20);
    if (idValue != null)
    {
      idValue.setFormat(Paths.font('vcr.ttf'), 20, 0xFF9AF0C9, LEFT);
      add(idValue);
    }

    confirmButton = new FlxButton(360, 360, 'CONFIRMAR', onConfirm);
    if (confirmButton != null)
    {
      confirmButton.color = 0xFF4FA2FF;
      add(confirmButton);
    }

    loginButton = new FlxButton(200, 430, 'LOGIN', toggleMode);
    if (loginButton != null)
    {
      loginButton.color = 0xFF35D67A;
      loginButton.visible = false;
      add(loginButton);
    }

    createButton = new FlxButton(520, 430, 'CADASTRAR', toggleMode);
    if (createButton != null)
    {
      createButton.color = 0xFFFF6B35;
      createButton.visible = false;
      add(createButton);
    }

    backButton = new FlxButton(360, 500, 'VOLTAR', () -> FlxG.switchState(() -> new MainMenuState()));
    if (backButton != null)
    {
      backButton.color = 0xFF8C8C8C;
      add(backButton);
    }

    FunkinSound.playMusic('freakyMenu', {
      overrideExisting: true,
      loop: true
    });

    autoLogin();
  }

  function autoLogin():Void
  {
    currentAccount = MultiplayerAccountManager.getOrCreateAccount('Player');
    if (usernameValue != null) usernameValue.text = Std.string(currentAccount.username);
    if (idValue != null) idValue.text = Std.string(currentAccount.id);
    if (statusText != null) statusText.text = 'Conta carregada. Clique em CONFIRMAR para continuar.';
    isLoginMode = true;
  }

  function toggleMode():Void
  {
    isLoginMode = !isLoginMode;

    if (isLoginMode)
    {
      if (title != null) title.text = 'MULTIPLAYER LOGIN';
      if (statusText != null) statusText.text = 'Faça login em sua conta existente.';
      if (confirmButton != null) confirmButton.label.text = 'LOGAR';
      if (loginButton != null) loginButton.visible = false;
      if (createButton != null) createButton.visible = true;
    }
    else
    {
      if (title != null) title.text = 'CRIAR CONTA';
      if (statusText != null) statusText.text = 'Digite um nome para sua nova conta.';
      if (confirmButton != null) confirmButton.label.text = 'CRIAR';
      if (loginButton != null) loginButton.visible = true;
      if (createButton != null) createButton.visible = false;
      if (usernameValue != null) usernameValue.text = '';
    }
  }

  function onConfirm():Void
  {
    if (isLoginMode)
    {
      onLogin();
    }
    else
    {
      onCreateAccount();
    }
  }

  function onCreateAccount():Void
  {
    if (usernameValue == null) return;
    var username:String = usernameValue.text.trim();
    if (username.length == 0)
    {
      if (statusText != null) statusText.text = 'Digite um nome para a conta!';
      return;
    }

    currentAccount = MultiplayerAccountManager.createAccount(username);
    if (usernameValue != null) usernameValue.text = Std.string(currentAccount.username);
    if (idValue != null) idValue.text = Std.string(currentAccount.id);
    if (statusText != null) statusText.text = 'Conta criada! ID: ' + Std.string(currentAccount.id);

    if (statusText != null)
    {
      FlxTween.tween(statusText, {
        alpha: 1
      }, 0.3, {
        ease: FlxEase.linear
      });
    }
    var timer:FlxTimer = new FlxTimer();
    timer.start(2.0, function(_:FlxTimer):Void
    {
      FlxG.switchState(() -> new OnlineMenuState());
    });
  }

  function onLogin():Void
  {
    if (usernameValue == null) return;
    var username:String = usernameValue.text.trim();
    if (username.length == 0) username = 'Player';

    var account:Dynamic = MultiplayerAccountManager.login(username, currentAccount != null ? Std.string(Reflect.field(currentAccount, 'password')) : '');
    if (account == null)
    {
      if (statusText != null) statusText.text = 'Login falhou. Essa conta não existe.';
      return;
    }

    currentAccount = account;
    if (statusText != null) statusText.text = 'Login bem-sucedido! Entrando no lobby...';
    if (statusText != null)
    {
      FlxTween.tween(statusText, {
        alpha: 1
      }, 0.3, {
        ease: FlxEase.linear
      });
    }
    var timer:FlxTimer = new FlxTimer();
    timer.start(2.0, function(_:FlxTimer):Void
    {
      FlxG.switchState(() -> new OnlineMenuState());
    });
  }
}
