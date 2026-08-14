package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.math.FlxPoint;
import funkin.audio.FunkinSound;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatState;
import funkin.ui.mainmenu.MainMenuState;
import funkin.multiplayer.MultiplayerClient;
import funkin.multiplayer.MultiplayerAccountManager;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.data.song.SongRegistry;
import funkin.ui.transition.LoadingState;

class OnlineMenuState extends MusicBeatState
{
  var bg:Null<FunkinSprite> = null;
  var title:Null<FlxText> = null;
  var subtitle:Null<FlxText> = null;
  var statusText:Null<FlxText> = null;
  // HOST agora é um FunkinSprite animado, não mais um FlxButton
  var hostButton:Null<FunkinSprite> = null;
  var hostLocked:Bool = false; // trava input durante a anim de "confirm"
  var connectButton:Null<FlxButton> = null;
  var backButton:Null<FlxButton> = null;
  var client:Null<MultiplayerClient> = null;
  var currentAccount:Dynamic = null;
  // ---- Navegação por teclado (setas/WASD + ENTER) ----
  // 0 = HOST, 1 = CONNECT, 2 = BACK
  var selectedIndex:Int = 0;

  static final OPTION_COUNT:Int = 3;

  override function create():Void
  {
    super.create();

    FlxG.mouse.visible = true;

    bg = new FunkinSprite(0, 0);
    bg.makeSolidColor(FlxG.width, FlxG.height, 0xFF101722);
    add(bg);

    title = new FlxText(0, 40, FlxG.width, 'ONLINE MENU', 42);
    if (title != null)
    {
      title.setFormat(Paths.font('vcr.ttf'), 42, 0xFFFFFFFF, CENTER);
      add(title);
    }

    subtitle = new FlxText(0, 100, FlxG.width, 'Aguardando jogadores...', 18);
    if (subtitle != null)
    {
      subtitle.setFormat(Paths.font('vcr.ttf'), 18, 0xFFB7C8FF, CENTER);
      add(subtitle);
    }

    statusText = new FlxText(0, 150, FlxG.width, '1/2 connected', 22);
    if (statusText != null)
    {
      statusText.setFormat(Paths.font('vcr.ttf'), 22, 0xFF7CF6CF, CENTER);
      add(statusText);
    }

    // ---- HOST como FunkinSprite animado ----
    hostButton = new FunkinSprite(220, 280);
    hostButton.frames = Paths.getSparrowAtlas('mainmenu/host');
    hostButton.animation.addByPrefix('idle', 'host idle', 24, true);
    hostButton.animation.addByPrefix('confirm', 'host selected', 24, false);
    hostButton.animation.play('idle');
    hostButton.antialiasing = true;
    add(hostButton);

    connectButton = new FlxButton(460, 280, 'CONNECT', connectOnline);
    if (connectButton != null)
    {
      connectButton.color = 0xFF27C7A4;
      connectButton.scale.set(2.0, 2.0);
      connectButton.updateHitbox();
      connectButton.onOver.callback = () ->
      {
        connectButton.color = 0xFF3FE9D6;
        connectButton.scale.set(2.1, 2.1);
      };
      connectButton.onOut.callback = () ->
      {
        connectButton.color = 0xFF27C7A4;
        connectButton.scale.set(2.0, 2.0);
      };
      add(connectButton);
    }

    backButton = new FlxButton(340, 400, 'BACK', () ->
    {
      trace('[MP] Back button clicked');
      FlxG.switchState(() -> new MainMenuState());
    });
    if (backButton != null)
    {
      backButton.color = 0xFF8B8B8B;
      backButton.scale.set(1.8, 1.8);
      backButton.updateHitbox();
      backButton.onOver.callback = () ->
      {
        backButton.color = 0xFFC0C0C0;
        backButton.scale.set(1.9, 1.9);
      };
      backButton.onOut.callback = () ->
      {
        backButton.color = 0xFF8B8B8B;
        backButton.scale.set(1.8, 1.8);
      };
      add(backButton);
    }

    currentAccount = MultiplayerAccountManager.getOrCreateAccount('Player');
    if (statusText != null)
    {
      statusText.text = 'Conta ativa: ' + Std.string(currentAccount.username) + ' | ID: ' + Std.string(currentAccount.id) + ' | 1/2 connected';
    }

    // Liga o serviço de convite e escuta convites recebidos enquanto essa
    // tela estiver aberta. openSubState empilha por cima do que já tiver
    // aberto (ex: LoginSubState), então convite chegando durante o login
    // não se perde, só fica esperando na fila do flixel.
    MultiplayerInviteService.instance.connect();
    MultiplayerInviteService.instance.onInviteReceived = onInviteReceived;

    FunkinSound.playMusic('chartEditorloop', {
      overrideExisting: true,
      loop: true
    });

    // Se a conta ainda não tem Discord vinculado, mostra o card de login
    // por cima assim que a tela abre.
    // NOTA: presumindo MultiplayerAccountManager.isDiscordLinked(account).
    // Se o nome real for diferente, só trocar aqui.
    // TEMPORARIAMENTE DESATIVADO: LoginSubState tava travando o update()
    // do OnlineMenuState pra sempre (fecha visualmente mas não chama
    // close() certinho, então o Flixel continua achando que ela tá
    // aberta e nunca mais processa clique no menu por trás dela).
    // Reativar assim que o bug de fechamento dela for corrigido.
    if (!MultiplayerAccountManager.isDiscordLinked(currentAccount))
    {
      openSubState(new LoginSubState(currentAccount, (profile) ->
      {
        if (statusText != null)
        {
          statusText.text = 'Conta ativa: ' + Std.string(currentAccount.username) + ' | ID: ' + Std.string(currentAccount.id) + ' | 1/2 connected';
        }
      }));
    }
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (!hostLocked)
    {
      // ---- Navegação: setas/WASD movem a seleção ----
      final pressedNext:Bool = FlxG.keys.justPressed.DOWN || FlxG.keys.justPressed.S || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D;
      final pressedPrev:Bool = FlxG.keys.justPressed.UP || FlxG.keys.justPressed.W || FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A;

      if (pressedNext)
      {
        selectedIndex = (selectedIndex + 1) % OPTION_COUNT;
        FunkinSound.playOnce(Paths.sound('scrollMenu'));
      }
      else if (pressedPrev)
      {
        selectedIndex = (selectedIndex - 1 + OPTION_COUNT) % OPTION_COUNT;
        FunkinSound.playOnce(Paths.sound('scrollMenu'));
      }

      // ---- Confirmar com ENTER/SPACE ----
      if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
      {
        confirmSelection();
      }

      // ---- ESC volta pro menu principal ----
      if (FlxG.keys.justPressed.ESCAPE)
      {
        trace('[MP] ESC pressionado - voltando pro MainMenuState');
        FlxG.switchState(() -> new MainMenuState());
      }
    }

    updateSelectionVisuals();

    // ---- Mouse continua funcionando como bônus, se um dia o clique
    // passar a chegar direito no motor. Não é mais o caminho principal. ----
    final mouseWorld:FlxPoint = FlxG.mouse.getWorldPosition();

    if (hostButton != null && !hostLocked)
    {
      final overHost:Bool = hostButton.overlapsPoint(mouseWorld, false);
      if (overHost && FlxG.mouse.justPressed)
      {
        selectedIndex = 0;
        confirmSelection();
      }
    }
  }

  /**
   * Atualiza o visual (escala/cor) de HOST/CONNECT/BACK de acordo com
   * qual opção tá selecionada no momento (`selectedIndex`), igual um
   * hover, só que controlado pelo teclado em vez do mouse.
   */
  function updateSelectionVisuals():Void
  {
    if (hostButton != null && !hostLocked)
    {
      final scale:Float = (selectedIndex == 0) ? 1.05 : 1.0;
      if (hostButton.scale.x != scale)
      {
        hostButton.scale.set(scale, scale);
        hostButton.updateHitbox();
      }
    }

    if (connectButton != null)
    {
      final selected:Bool = selectedIndex == 1;
      connectButton.color = selected ? 0xFF3FE9D6 : 0xFF27C7A4;
      connectButton.scale.set(selected ? 2.1 : 2.0, selected ? 2.1 : 2.0);
    }

    if (backButton != null)
    {
      final selected:Bool = selectedIndex == 2;
      backButton.color = selected ? 0xFFC0C0C0 : 0xFF8B8B8B;
      backButton.scale.set(selected ? 1.9 : 1.8, selected ? 1.9 : 1.8);
    }
  }

  /**
   * Executa a ação da opção selecionada no momento (equivalente a
   * "clicar" nela, mas disparado pelo ENTER/SPACE).
   */
  function confirmSelection():Void
  {
    switch (selectedIndex)
    {
      case 0:
        if (hostButton != null && !hostLocked)
        {
          hostLocked = true;
          hostButton.animation.play('confirm', true);
          hostButton.animation.finishCallback = (_) -> startHost();
        }
      case 1:
        connectOnline();
      case 2:
        trace('[MP] Back selecionado');
        FlxG.switchState(() -> new MainMenuState());
    }
  }

  function connectOnline():Void
  {
    trace('[MP] Connect button clicked');
    try
    {
      final localClient:MultiplayerClient = new MultiplayerClient('127.0.0.1', 2082);
      client = localClient;
      final localStatus:Null<FlxText> = statusText;
      final localAccount:Dynamic = currentAccount;

      localClient.onConnect = () ->
      {
        trace('[MP] connected to server');
        if (localStatus != null) localStatus.text = 'Conectado. Aguardando partida...';
        if (localAccount != null)
        {
          localClient.send({
            type: 'connect',
            id: Std.string(localAccount.id),
            username: Std.string(localAccount.username),
            password: Std.string(localAccount.password)
          });
        }
      };
      localClient.onError = (msg:String) ->
      {
        trace('[MP] error: $msg');
        if (localStatus != null) localStatus.text = 'Erro: ' + msg;
      };
      localClient.onMessage = (msg:Dynamic) ->
      {
        trace('[MP] message: ' + haxe.Json.stringify(msg));
        if (msg != null && Reflect.hasField(msg, 'type'))
        {
          switch (Std.string(Reflect.field(msg, 'type')))
          {
            case 'match_start':
              if (localStatus != null) localStatus.text = 'Partida iniciada! 2/2 connected';
              onMatchStart(msg);
            case 'waiting_for_opponent':
              if (localStatus != null) localStatus.text = 'Aguardando oponente... 1/2 connected';
            case 'oponent_disconnected':
              if (localStatus != null) localStatus.text = 'Oponente desconectou. 1/2 connected';
            default:
          }
        }
      };
      localClient.onDisconnect = () -> trace('[MP] disconnected');
      localClient.connect();
    }
    catch (e:Dynamic)
    {
      if (statusText != null) statusText.text = 'Falha ao conectar ao servidor.';
      trace('[MP] failed to start: ' + e);
    }
  }

  // Chamado quando o host manda 'match_start'. Carrega a mesma música
  // pro lado do client e entra no PlayState em modo multiplayer.

  function onMatchStart(msg:Dynamic):Void
  {
    if (!Reflect.hasField(msg, 'songId')) return;

    var songId:String = Std.string(Reflect.field(msg, 'songId'));
    var difficulty:String = Reflect.hasField(msg, 'difficulty') ? Std.string(Reflect.field(msg, 'difficulty')) : 'normal';
    var variation:String = Reflect.hasField(msg, 'variation') ? Std.string(Reflect.field(msg, 'variation')) : 'default';

    var song:Null<Song> = SongRegistry.instance.fetchEntry(songId);
    if (song == null)
    {
      trace('[MP] música recebida do host não encontrada: ' + songId);
      return;
    }

    #if MULTIPLAYER_FEATURE
    PlayState.multiplayerClient = client;
    PlayState.multiplayerMatchActive = true;
    #end

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: difficulty,
      targetVariation: variation,
      isMultiplayerMode: true
    });
  }

  // Chamado (via MultiplayerInviteService.onInviteReceived) quando ALGUÉM
  // te convida. Mostra o card com avatar/nick + ACCEPT/DISCARD.

  function onInviteReceived(invite:InviteInfo):Void
  {
    trace('[MP] convite recebido de ' + invite.username);
    openSubState(new InviteNotificationSubState(invite));
  }

  // Abre o card do host por cima da tela, como no rascunho (card em baixo)

  function startHost():Void
  {
    trace('[MP] HOST clicked - abrindo HostMenuSubState');
    if (statusText != null) statusText.text = 'Abrindo host...';

    openSubState(new HostMenuSubState(currentAccount, (success:Bool) ->
    {
      hostLocked = false;
      if (hostButton != null) hostButton.animation.play('idle', true);

      if (success && statusText != null)
      {
        statusText.text = 'Indo pra partida...';
      }
      else if (statusText != null)
      {
        statusText.text = 'Host fechado. 1/2 connected';
      }
    }));
  }

  override function destroy():Void
  {
    if (client != null) client.disconnect();
    if (MultiplayerInviteService.instance.onInviteReceived == onInviteReceived)
    {
      MultiplayerInviteService.instance.onInviteReceived = null;
    }
    super.destroy();
  }
}
