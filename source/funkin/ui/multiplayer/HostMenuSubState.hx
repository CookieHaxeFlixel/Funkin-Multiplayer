package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerServer;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerAccountManager;
import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.data.song.SongRegistry;
import funkin.ui.transition.LoadingState;

/**
 * Card que abre por cima da OnlineMenuState quando o jogador clica em HOST.
 * Sobe um MultiplayerServer local. O botão PLAY só fica utilizável
 * quando o segundo jogador (o client) se conecta (2/2).
 */
class HostMenuSubState extends MusicBeatSubState
{
  var account:Dynamic;
  var onClosed:(success:Bool) -> Void;

  /**
   * Preencha isso com a música/dificuldade escolhida antes de abrir o card,
   * ou pluga aqui a tela de seleção de música do seu freeplay.
   * Sem isso o PLAY não tem o que carregar no PlayState.
   */
  public var targetSongId:Null<String> = null;
  public var targetDifficulty:String = 'normal';
  public var targetVariation:String = 'default';

  var cardBg:Null<FunkinSprite> = null;
  var dim:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var matchupText:Null<FlxText> = null;
  var portText:Null<FlxText> = null;
  var countText:Null<FlxText> = null;
  var serverIdText:Null<FlxText> = null;
  var playButton:Null<FlxButton> = null;
  var inviteButton:Null<FlxButton> = null;
  var closeButton:Null<FlxButton> = null;

  var server:Null<MultiplayerServer> = null;
  var serverId:String = '';
  var port:Int = 2082;

  // guardadas pra dar unregister certinho no MultiplayerInviteService quando o card fechar
  var onInviteAcceptedHandler:Null<String->Void> = null;
  var onInviteDeclinedHandler:Null<String->Void> = null;

  // Só fica true quando o segundo jogador conecta.
  var playerReady:Bool = false;

  public function new(account:Dynamic, onClosed:(success:Bool) -> Void)
  {
    super();
    this.account = account;
    this.onClosed = onClosed;
  }

  override function create():Void
  {
    super.create();

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    final cardW:Int = 640;
    final cardH:Int = 460;
    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    cardBg = new FunkinSprite(cardX, cardY);
    cardBg.makeSolidColor(cardW, cardH, 0xFF1B2436);
    add(cardBg);

    titleText = new FlxText(cardX, cardY + 20, cardW, 'HOST', 36);
    titleText.setFormat(Paths.font('vcr.ttf'), 36, 0xFFFFFFFF, CENTER);
    add(titleText);

    matchupText = new FlxText(cardX, cardY + 70, cardW, Std.string(account.username) + ' vs. ???', 20);
    matchupText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFB7C8FF, CENTER);
    add(matchupText);

    serverId = generateServerId();

    portText = new FlxText(cardX, cardY + 130, cardW, 'LAN PORTA: ' + Std.string(port), 22);
    portText.setFormat(Paths.font('vcr.ttf'), 22, 0xFFFFFFFF, CENTER);
    add(portText);

    countText = new FlxText(cardX, cardY + 180, cardW, '1/2', 30);
    countText.setFormat(Paths.font('vcr.ttf'), 30, 0xFF7CF6CF, CENTER);
    add(countText);

    serverIdText = new FlxText(cardX, cardY + 240, cardW, 'SERVER: ' + serverId, 20);
    serverIdText.setFormat(Paths.font('vcr.ttf'), 20, 0xFFB7C8FF, CENTER);
    add(serverIdText);

    // Só é "clicável de verdade" quando playerReady == true (checado no onPlayPressed).
    playButton = new FlxButton(cardX + (cardW / 2) - 60, cardY + cardH - 90, 'PLAY', onPlayPressed);
    playButton.scale.set(1.6, 1.6);
    playButton.updateHitbox();
    add(playButton);
    updatePlayButtonVisual();

    // Botão pra convidar alguém pelo nick do Discord. Fica do lado
    // esquerdo do PLAY, sempre clicável (não depende do playerReady).
    inviteButton = new FlxButton(cardX + 30, cardY + cardH - 90, 'CONVIDAR', onInvitePressed);
    inviteButton.color = 0xFF5865F2; // roxo/azulado, cor da marca do Discord
    inviteButton.label.color = 0xFFFFFFFF;
    inviteButton.scale.set(1.2, 1.2);
    inviteButton.updateHitbox();
    add(inviteButton);

    closeButton = new FlxButton(cardX + cardW - 40, cardY + 10, 'X', onClosePressed);
    closeButton.color = 0xFF8B8B8B;
    add(closeButton);

    connectToInviteService();
    startHosting();
  }

  /**
   * Garante que o MultiplayerInviteService tá conectado no relay e
   * registrado com o Discord dessa conta (se tiver vinculado), e escuta
   * quando o convite que a gente mandar for aceito/recusado — é o gatilho
   * pra trocar o server de LAN pra relay.
   */
  function connectToInviteService():Void
  {
    var invites = MultiplayerInviteService.instance;

    // idempotente: se a OnlineMenuState já chamou isso, não faz nada de novo.
    invites.connect();

    if (MultiplayerAccountManager.isDiscordLinked(account))
    {
      invites.setIdentity(Std.string(Reflect.field(account, 'discordId')), Std.string(Reflect.field(account, 'discordUsername')),
        Std.string(Reflect.field(account, 'discordAvatarUrl')));
    }

    invites.onInviteAccepted = onInviteAcceptedHandler = (sessionId:String) ->
    {
      if (sessionId != serverId) return; // convite de outra sessão, ignora

      if (playerReady)
      {
        trace('[Host] convite aceito mas já tem alguém conectado (LAN), ignorando.');
        return;
      }

      trace('[Host] convidado aceitou pelo Discord, trocando o server pro modo relay.');

      if (server != null)
      {
        // troca o transporte sem perder onClientConnect/onClientMessage/onClientDisconnect,
        // que continuam plugados na mesma instância.
        server.stop();
        server.startRelay(serverId);
      }
    };

    invites.onInviteDeclined = onInviteDeclinedHandler = (sessionId:String) ->
    {
      if (sessionId != serverId) return;
      trace('[Host] convite recusado.');
    };
  }

  function generateServerId():String
  {
    final chars:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var id:String = '';
    for (i in 0...6)
      id += chars.charAt(Std.int(Math.random() * chars.length));
    return id;
  }

  function startHosting():Void
  {
    try
    {
      server = new MultiplayerServer(port);

      server.onClientConnect = () ->
      {
        trace('[Host] client conectou');
        playerReady = true;
        if (countText != null) countText.text = '2/2';
        updatePlayButtonVisual();
      };

      server.onClientDisconnect = () ->
      {
        trace('[Host] client desconectou');
        playerReady = false;
        if (countText != null) countText.text = '1/2';
        if (matchupText != null) matchupText.text = Std.string(account.username) + ' vs. ???';
        updatePlayButtonVisual();
      };

      server.onClientMessage = (data:Dynamic) ->
      {
        if (data != null && Reflect.hasField(data, 'type') && Std.string(Reflect.field(data, 'type')) == 'connect')
        {
          var opponentName:String = Reflect.hasField(data, 'username') ? Std.string(Reflect.field(data, 'username')) : '???';
          if (matchupText != null) matchupText.text = Std.string(account.username) + ' vs. ' + opponentName;
        }
      };

      server.start();
      // Se chegou até aqui sem exception, o server subiu certinho na porta.
      trace('[Host] server rodando na porta ' + port);
    }
    catch (e:Dynamic)
    {
      trace('[Host] falha ao iniciar servidor: ' + e);
      if (portText != null) portText.text = 'Falha ao abrir a porta ' + Std.string(port);
      server = null;
    }
  }

  function onInvitePressed():Void
  {
    trace('[Host] CONVIDAR clicado, abrindo busca por nick do Discord');
    // Mesma package (funkin.ui.multiplayer), não precisa de import extra.
    openSubState(new InviteSearchSubState(serverId, port));
  }

  function updatePlayButtonVisual():Void
  {
    if (playButton == null) return;
    // Verde quando liberado, cinza (travado) quando ainda é 1/2.
    playButton.color = playerReady ? 0xFF3B82F6 : 0xFF4A4A4A;
  }

  function onPlayPressed():Void
  {
    // Trava real: só passa daqui se os dois jogadores estiverem conectados.
    if (!playerReady)
    {
      trace('[Host] PLAY ignorado, esperando o segundo jogador ainda');
      return;
    }

    if (targetSongId == null)
    {
      trace('[Host] ERRO: nenhuma música foi selecionada antes de abrir o HostMenuSubState (targetSongId == null)');
      if (portText != null) portText.text = 'Selecione uma música antes de dar PLAY.';
      return;
    }

    trace('[Host] PLAY pressionado, indo pro PlayState em modo multiplayer');

    // Avisa o client pra começar também.
    if (server != null)
    {
      server.broadcast({
        type: 'match_start',
        songId: targetSongId,
        difficulty: targetDifficulty,
        variation: targetVariation
      });
    }

    goToMultiplayerPlayState();
  }

  function goToMultiplayerPlayState():Void
  {
    if (targetSongId == null) return;

    var song:Null<Song> = SongRegistry.instance.fetchEntry(targetSongId);
    if (song == null)
    {
      trace('[Host] música não encontrada: ' + targetSongId);
      return;
    }

    #if MULTIPLAYER_FEATURE
    // O host NÃO vira client de si mesmo (o MultiplayerServer só aceita
    // uma conexão de cada vez, e essa vaga já é do convidado). O host
    // fala com o convidado direto pelo MultiplayerServer.instance
    // (server.broadcast / server.onClientMessage), que o PlayState
    // detecta sozinho. multiplayerClient fica null aqui de propósito.
    PlayState.multiplayerClient = null;
    PlayState.multiplayerMatchActive = true;
    PlayState.multiplayerMatchId = serverId;
    #end

    // NOTA: não chama server.stop() aqui (closeCard(true) já não chama,
    // já que só para quando success == false). O server precisa continuar
    // rodando durante a partida inteira pra sincronizar os dois lados.
    closeCard(true);

    LoadingState.loadPlayState({
      targetSong: song,
      targetDifficulty: targetDifficulty,
      targetVariation: targetVariation,
      isMultiplayerMode: true
    });
  }

  function onClosePressed():Void
  {
    closeCard(false);
  }

  // não pode se chamar "close" - o FlxSubState já tem um close() sem argumentos
  function closeCard(success:Bool):Void
  {
    if (server != null && !success)
    {
      server.stop();
    }
    unregisterFromInviteService();
    if (onClosed != null) onClosed(success);
    close();
  }

  /** Tira os callbacks daqui do MultiplayerInviteService pra não disparar num card já fechado. */
  function unregisterFromInviteService():Void
  {
    var invites = MultiplayerInviteService.instance;
    if (invites.onInviteAccepted == onInviteAcceptedHandler) invites.onInviteAccepted = null;
    if (invites.onInviteDeclined == onInviteDeclinedHandler) invites.onInviteDeclined = null;
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (FlxG.keys.justPressed.ESCAPE)
    {
      onClosePressed();
    }
  }

  override function destroy():Void
  {
    if (server != null) server.stop();
    unregisterFromInviteService();
    super.destroy();
  }
}
