package funkin.ui.multiplayer;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.group.FlxGroup.FlxTypedGroup;
import funkin.graphics.FunkinSprite;
import funkin.ui.MusicBeatSubState;
import funkin.multiplayer.MultiplayerInviteService;
import funkin.multiplayer.MultiplayerInviteService.InviteInfo;

/**
 * Card de busca por nick do Discord. Abre por cima do HostMenuSubState
 * quando o host clica em CONVIDAR. Digita o nick, aperta BUSCAR, e cada
 * resultado vira uma InviteResultRow com botão CONVIDAR.
 *
 * ATENÇÃO — campo de texto: não sei qual lib de input de texto o
 * projeto de vocês usa (FlxUI tem FlxUIInputText; flixel puro não tem
 * nada pronto). Deixei `useTextInputField` abaixo bem sinalizado — troca
 * pela classe real de vocês. Por enquanto, se não trocar, o campo só
 * mostra um placeholder fixo e não deixa digitar (não vai quebrar
 * compilação, mas também não busca nada digitado de verdade).
 */
class InviteSearchSubState extends MusicBeatSubState
{
  var hostServerId:String;
  var hostPort:Int;
  var dim:Null<FunkinSprite> = null;
  var cardBg:Null<FunkinSprite> = null;
  var titleText:Null<FlxText> = null;
  var searchInputBg:Null<FunkinSprite> = null;
  var searchInputText:Null<FlxText> = null; // TODO: trocar por campo editável de verdade (ver nota da classe)
  var searchButton:Null<FlxButton> = null;
  var closeButton:Null<FlxButton> = null;
  var emptyText:Null<FlxText> = null;
  var resultsGroup:FlxTypedGroup<InviteResultRow> = new FlxTypedGroup();
  final cardW:Int = 520;
  final cardH:Int = 420;
  var typedQuery:String = '';

  public function new(hostServerId:String, hostPort:Int)
  {
    super();
    this.hostServerId = hostServerId;
    this.hostPort = hostPort;
  }

  override function create():Void
  {
    super.create();

    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;

    dim = new FunkinSprite(0, 0);
    dim.makeSolidColor(FlxG.width, FlxG.height, 0x99000000);
    add(dim);

    cardBg = new FunkinSprite(cardX, cardY);
    cardBg.makeSolidColor(cardW, cardH, 0xFF1B2436);
    add(cardBg);

    titleText = new FlxText(cardX, cardY + 16, cardW, 'CONVIDAR PELO DISCORD', 24);
    titleText.setFormat(Paths.font('vcr.ttf'), 24, 0xFFFFFFFF, CENTER);
    add(titleText);

    searchInputBg = new FunkinSprite(cardX + 20, cardY + 58);
    searchInputBg.makeSolidColor(cardW - 140, 40, 0xFF0F1622);
    add(searchInputBg);

    searchInputText = new FlxText(cardX + 28, cardY + 68, cardW - 156, 'Digite o nick do Discord...', 18);
    searchInputText.setFormat(Paths.font('vcr.ttf'), 18, 0xFF8B93A8, LEFT);
    add(searchInputText);

    // Captura teclado enquanto esse card tá aberto. Se vocês já tiverem
    // um FlxUIInputText ou similar no projeto, é só apagar isso e o
    // onKeyPress lá embaixo e usar o widget de verdade no lugar.
    FlxG.stage.window.onTextInput.add(onTextInput);
    FlxG.stage.window.onKeyDown.add(onKeyDown);

    searchButton = new FlxButton(cardX + cardW - 108, cardY + 56, 'BUSCAR', onSearchPressed);
    searchButton.color = 0xFF3B82F6;
    add(searchButton);

    emptyText = new FlxText(cardX, cardY + 120, cardW, 'Digite um nick e aperte BUSCAR.', 16);
    emptyText.setFormat(Paths.font('vcr.ttf'), 16, 0xFF8B93A8, CENTER);
    add(emptyText);

    add(resultsGroup);

    closeButton = new FlxButton(cardX + cardW - 40, cardY + 10, 'X', onClosePressed);
    closeButton.color = 0xFF8B8B8B;
    add(closeButton);

    MultiplayerInviteService.instance.connect();
  }

  function onTextInput(text:String):Void
  {
    typedQuery += text;
    refreshInputLabel();
  }

  function onKeyDown(key:lime.ui.KeyCode, modifier:lime.ui.KeyModifier):Void
  {
    if (key == lime.ui.KeyCode.BACKSPACE && typedQuery.length > 0)
    {
      typedQuery = typedQuery.substring(0, typedQuery.length - 1);
      refreshInputLabel();
    }
    else if (key == lime.ui.KeyCode.RETURN || key == lime.ui.KeyCode.NUMPAD_ENTER)
    {
      onSearchPressed();
    }
  }

  function refreshInputLabel():Void
  {
    if (searchInputText == null) return;
    if (typedQuery.length == 0)
    {
      searchInputText.text = 'Digite o nick do Discord...';
      searchInputText.color = 0xFF8B93A8;
    }
    else
    {
      searchInputText.text = typedQuery;
      searchInputText.color = 0xFFFFFFFF;
    }
  }

  function onSearchPressed():Void
  {
    if (typedQuery.length == 0) return;

    if (emptyText != null) emptyText.text = 'Buscando...';
    clearResults();

    MultiplayerInviteService.instance.searchByNick(typedQuery, onSearchResults);
  }

  function onSearchResults(results:Array<InviteInfo>):Void
  {
    clearResults();

    if (results == null || results.length == 0)
    {
      if (emptyText != null)
      {
        emptyText.text = 'Ninguém encontrado com esse nick.\n(Busca ainda é um stub — ver MultiplayerInviteService.)';
      }
      return;
    }

    if (emptyText != null) emptyText.text = '';

    final cardX:Float = (FlxG.width - cardW) / 2;
    final cardY:Float = (FlxG.height - cardH) / 2;
    var rowY:Float = cardY + 120;

    for (result in results)
    {
      var row:InviteResultRow = new InviteResultRow(cardX + 20, rowY, cardW - 40, result, onInvitePressed);
      resultsGroup.add(row);
      rowY += 62;
    }
  }

  function onInvitePressed(target:InviteInfo):Void
  {
    MultiplayerInviteService.instance.sendInvite(target, hostServerId, hostPort, () ->
    {
      trace('[Invite] convite enviado pra ' + target.username);
    }, (err) ->
      {
        trace('[Invite] falha ao convidar: ' + err);
      });
  }

  function clearResults():Void
  {
    resultsGroup.forEachAlive((row) -> row.destroy());
    resultsGroup.clear();
  }

  function onClosePressed():Void
  {
    close();
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);
    if (FlxG.keys.justPressed.ESCAPE) onClosePressed();
  }

  override function destroy():Void
  {
    FlxG.stage.window.onTextInput.remove(onTextInput);
    FlxG.stage.window.onKeyDown.remove(onKeyDown);
    super.destroy();
  }
}
