package funkin;

import flixel.graphics.frames.FlxAtlasFrames;
import animate.FlxAnimateFrames;
import funkin.graphics.FunkinSprite.AtlasSpriteSettings;
import openfl.utils.AssetType;
import funkin.util.macro.ConsoleMacro;
import haxe.io.Path;

@:nullSafety
class Paths implements ConsoleClass
{
  /**
   * Backward-compat: tracks the "current level" (used to pick which week's
   * assets to prioritize). Not load-bearing in the new single-library
   * structure, but kept so call sites compile and behave sanely.
   */
  public static var currentLevel:Null<String> = null;

  public static function setCurrentLevel(id:Null<String>):Void
  {
    currentLevel = id;
  }

  /**
   * Mapa de compatibilidade pra call sites antigos que ainda passam só o
   * nome curto do arquivo (ex: 'cancelMenu') em vez do caminho completo
   * novo (ex: 'ui/main-menu/cancel-menu'). Preenche aqui conforme os erros
   * de asset forem aparecendo — não é fallback automático/adivinhado,
   * é uma lista confirmada manualmente. Tem prioridade sobre o resolver
   * automático abaixo (LEGACY_KEY_MAP é checado primeiro).
   */
  static final LEGACY_KEY_MAP:Map<String, String> = [
    // menu / UI geral
    "cancelMenu" => "ui/main-menu/cancel-menu",
    "confirmMenu" => "ui/main-menu/confirm-menu",
    "scrollMenu" => "ui/main-menu/scroll-menu",
    "menuDesat" => "ui/main-menu/menu-desat",
    "menuBG" => "ui/main-menu/menu-bg",
    "menuBGMagenta" => "ui/main-menu/menu-bg-magenta",
    "screenshot" => "ui/main-menu/screenshot",
    "freakyMenu" => "ui/main-menu/freaky-menu",
    "freakyMenu/freakyMenu" => "ui/main-menu/freaky-menu/freaky-menu",
    "mainmenu/storymode" => "ui/main-menu/items/story-mode",
    "mainmenu/freeplay" => "ui/main-menu/items/freeplay",
    "mainmenu/merch" => "ui/main-menu/items/merch",
    "mainmenu/upgrade" => "ui/main-menu/items/upgrade",
    "mainmenu/options" => "ui/main-menu/items/options",
    "mainmenu/credits" => "ui/main-menu/items/credits",
    "mainmenu/optionsButton" => "ui/main-menu/items/options-button",
    "mainmenu/upgradeshine_big" => "ui/main-menu/items/upgrade-shine-big",
    "mainmenu/upgradeshine_small" => "ui/main-menu/items/upgrade-shine-small",
    "backButton" => "ui/back-button",
    // input-offsets
    "offsetsLoop/offsetsLoop" => "ui/input-offsets/offsets-loop/offsets-loop",
    "offsetsLoop/drumsLoop" => "ui/input-offsets/drums-loop/drums-loop",
    "latencyArrow" => "ui/input-offsets/arrow",
    "latencyReceptor" => "ui/input-offsets/receptor",
    "checkboxThingie" => "ui/options/checkbox",
    // pause
    "breakfast/breakfast" => "ui/pause/music/breakfast/breakfast",
    "breakfast-pico/breakfast-pico" => "ui/pause/music/breakfast-pico/breakfast-pico",
    "breakfast-pixel/breakfast-pixel" => "ui/pause/music/breakfast-pixel/breakfast-pixel",
    // character select
    "CS_select" => "ui/character-select/sounds/select",
    "CS_unlock" => "ui/character-select/sounds/unlock",
    "CS_locked" => "ui/character-select/sounds/locked",
    "CS_confirm" => "ui/character-select/sounds/confirm",
    "CS_Lights" => "ui/character-select/sounds/lights",
    "static loop" => "ui/character-select/sounds/static",
    "charSelect/charSelector" => "ui/character-select/interface/char-selector",
    "charSelect/charSelectorConfirm" => "ui/character-select/interface/char-selector-confirm",
    "charSelect/charSelectorDenied" => "ui/character-select/interface/char-selector-denied",
    "charSelect/charSelectBG" => "ui/character-select/interface/char-select-bg",
    "charSelect/curtains" => "ui/character-select/interface/curtains",
    "charSelect/charLight" => "ui/character-select/interface/char-light",
    "charSelect/foregroundBlur" => "ui/character-select/interface/foreground-blur",
    "charSelect/dipshitBlur" => "ui/character-select/interface/dipshit-blur",
    "charSelect/dipshitBacking" => "ui/character-select/interface/dipshit-backing",
    "charSelect/chooseDipshit" => "ui/character-select/interface/choose-your-dipshit",
    // chart editor
    "chartEditorLoop/chartEditorLoop" => "ui/editors/chart-editor/artistic-expression",
    "chartingSounds/ClickDown" => "ui/editors/chart-editor/charting-sounds/click-down",
    "chartingSounds/ClickUp" => "ui/editors/chart-editor/charting-sounds/click-up",
    "chartingSounds/noteLay" => "ui/editors/chart-editor/charting-sounds/note-place",
    "chartingSounds/noteErase" => "ui/editors/chart-editor/charting-sounds/note-erase",
    "chartingSounds/undo" => "ui/editors/chart-editor/charting-sounds/undo",
    "chartingSounds/stretch1_UI" => "ui/editors/chart-editor/charting-sounds/stretch-1",
    "chartingSounds/stretch2_UI" => "ui/editors/chart-editor/charting-sounds/stretch-2",
    "chartingSounds/stretchSNAP_UI" => "ui/editors/chart-editor/charting-sounds/stretch-snap",
    "chartingSounds/hitNotePlayer" => "ui/editors/chart-editor/charting-sounds/hitsound-player",
    "chartingSounds/hitNoteOpponent" => "ui/editors/chart-editor/charting-sounds/hitsound-opponent",
    "chartingSounds/openWindow" => "ui/editors/chart-editor/charting-sounds/window-open",
    "chartingSounds/exitWindow" => "ui/editors/chart-editor/charting-sounds/window-exit",
    "chartingSounds/metronome1" => "ui/editors/chart-editor/charting-sounds/metronome-1",
    "chartingSounds/metronome2" => "ui/editors/chart-editor/charting-sounds/metronome-2",
    "ui/chart-editor/toolbox/difficulty" => "ui/editors/chart-editor/toolbox/difficulty",
    "ui/chart-editor/toolbox/player-preview" => "ui/editors/chart-editor/toolbox/player-preview",
    "ui/chart-editor/toolbox/opponent-preview" => "ui/editors/chart-editor/toolbox/opponent-preview",
    "ui/chart-editor/toolbox/playtest-properties" => "ui/editors/chart-editor/toolbox/playtest-properties",
    "ui/chart-editor/dialogs/upload-inst" => "ui/editors/chart-editor/dialogs/upload-inst",
    "ui/chart-editor/dialogs/song-metadata" => "ui/editors/chart-editor/dialogs/song-metadata",
    "ui/chart-editor/dialogs/open-chart-parts" => "ui/editors/chart-editor/dialogs/open-chart-parts",
    "ui/chart-editor/dialogs/open-chart-parts-entry" => "ui/editors/chart-editor/dialogs/open-chart-parts-entry",
    "ui/chart-editor/dialogs/import-chart" => "ui/editors/chart-editor/dialogs/import-chart",
    "ui/chart-editor/dialogs/user-guide" => "ui/editors/chart-editor/dialogs/user-guide",
    "ui/chart-editor/dialogs/add-variation" => "ui/editors/chart-editor/dialogs/add-variation",
    "ui/chart-editor/dialogs/add-difficulty" => "ui/editors/chart-editor/dialogs/add-difficulty",
    "ui/chart-editor/dialogs/clone-difficulty" => "ui/editors/chart-editor/dialogs/clone-difficulty",
    "ui/chart-editor/dialogs/move-difficulty" => "ui/editors/chart-editor/dialogs/move-difficulty",
    "ui/chart-editor/dialogs/backup-available" => "ui/editors/chart-editor/dialogs/backup-available",
    "ui/chart-editor/events/Default" => "ui/editors/chart-editor/events/Default",
    "stage-editor/stage-editor-view" => "ui/editors/stage-editor/stage-editor-view",
    // freeplay
    "ranks/rankinbad" => "ui/freeplay/ranks/in/bad",
    "ranks/rankinnormal" => "ui/freeplay/ranks/in/normal",
    "ranks/rankinperfect" => "ui/freeplay/ranks/in/perfect",
    "ranks/loss" => "ui/freeplay/ranks/slam/loss",
    "ranks/good" => "ui/freeplay/ranks/slam/good",
    "ranks/great" => "ui/freeplay/ranks/slam/great",
    "ranks/excellent" => "ui/freeplay/ranks/slam/excellent",
    "ranks/perfect" => "ui/freeplay/ranks/slam/perfect",
    "fav" => "ui/freeplay/sounds/favorite",
    "unfav" => "ui/freeplay/sounds/unfavorite",
    "freeplay/transitionGradient" => "ui/freeplay/interface/transition-gradient",
    "freeplay/cardGlow" => "ui/freeplay/interface/card-glow",
    "freeplay/confirmGlow" => "ui/freeplay/interface/confirm-glow-1",
    "freeplay/confirmGlow2" => "ui/freeplay/interface/confirm-glow-2",
    "freeplay/glowingText" => "ui/freeplay/interface/glowing-text",
    "freeplay/seperator" => "ui/freeplay/interface/separator",
    "freeplay/freeplayFlame" => "ui/freeplay/difficulty/freeplay-flame",
    "freeplay/rankVignette" => "ui/freeplay/interface/rank-vignette",
    "freeplay/highscore" => "ui/freeplay/interface/highscore",
    "freeplay/clearBox" => "ui/freeplay/interface/clear-box",
    "freeplay/sparks" => "ui/freeplay/interface/sparks",
    "freeplay/sparksadd" => "ui/freeplay/interface/sparks-add",
    "freeplay/backingCards/newCharacter/darkback" => "ui/freeplay/styles/unlock/backing-card/dark-back",
    "freeplay/backingCards/newCharacter/multiplyBar" => "ui/freeplay/styles/unlock/backing-card/multiply-bar",
    "freeplay/backingCards/newCharacter/red" => "ui/freeplay/styles/unlock/backing-card/red",
    "freeplay/backingCards/newCharacter/orange gradient" => "ui/freeplay/styles/unlock/backing-card/orange-gradient",
    "freeplay/backingCards/newCharacter/red gradient" => "ui/freeplay/styles/unlock/backing-card/red-gradient",
    "freeplay/backingCards/newCharacter/yellow bg piece" => "ui/freeplay/styles/unlock/backing-card/yellow-bg",
    // result screen
    "resultScreen/tallieNumber" => "ui/results/interface/tallie-number",
    "resultScreen/score-digital-numbers" => "ui/results/interface/score-digital-numbers",
    "resultScreen/tardlingSpritesheet" => "ui/fonts/tardling",
    "resultScreen/highscoreNew" => "ui/results/interface/highscore-new",
    // story mode
    "storymenu/ui/lock" => "ui/story-mode/lock",
    "storymenu/ui/arrows" => "ui/story-mode/arrows",
    // title
    "introText" => "ui/title/intro-text",
    "title-screen-text" => "ui/title/title-screen-text",
    "title-screen-text-mobile" => "ui/title/title-screen-text-mobile",
    "girlfriendsRingtone/girlfriendsRingtone" => "ui/title/girlfriends-ringtone/girlfriends-ringtone",
    "logoBumpin" => "ui/title/logo-bumpin",
    "gfDanceTitle" => "ui/title/gf-dance-title",
    "newgrounds_logo_classic" => "ui/title/newgrounds-logo-classic",
    "newgrounds_logo_animated" => "ui/title/newgrounds-logo-animated",
    "newgrounds_logo" => "ui/title/newgrounds-logo",
    // newgrounds
    "NGFadeIn" => "ui/medals/ng-fade-in",
    "NGFadeOut" => "ui/medals/ng-fade-out",
    // gameplay geral
    "missnote1" => "gameplay/general/sounds/miss-note-1",
    "missnote2" => "gameplay/general/sounds/miss-note-2",
    "missnote3" => "gameplay/general/sounds/miss-note-3",
    "notes" => "gameplay/notestyles/funkin/notes",
    "noteSplashes" => "gameplay/notestyles/funkin/note-splashes",
    "noteStrumline" => "gameplay/notestyles/funkin/note-strumline",
    "NOTE_hold_assets" => "gameplay/notestyles/funkin/note-holds",
    "healthBar" => "gameplay/general/health-bar",
    // fonts
    "fonts/bold" => "ui/fonts/bold",
    "fonts/default" => "ui/fonts/default",
    "fonts/freeplay-clear" => "ui/fonts/freeplay-clear",
    // loading
    "funkay" => "ui/loading/funkay"
  ];

  /**
   * Resolvedor automático de fallback: quando um call site antigo passa só
   * o nome curto de um arquivo (ex: 'menuDesat', 'healthBar', 'logoBumpin')
   * e esse nome não está no LEGACY_KEY_MAP, esse resolver escaneia
   * assets/preload/ (uma única vez, na primeira falha) e monta um índice
   * de "nome do arquivo" -> "caminho relativo completo, sem extensão".
   * Assim, qualquer key antigo é encontrado onde quer que tenha ido parar
   * na reestruturação, sem precisar mapear cada um manualmente.
   *
   * Isso NÃO cobre keys que dependem de estrutura de pasta (ex: algo com
   * "/" no meio tipo 'freakyMenu/freakyMenu') — esses continuam precisando
   * de uma entrada manual no LEGACY_KEY_MAP.
   */
  #if sys
  static var _assetIndex:Null<Map<String, String>> = null;

  static function buildAssetIndex():Void
  {
    _assetIndex = new Map<String, String>();
    var root:String = 'assets/preload';
    if (!sys.FileSystem.exists(root)) return;
    indexDir(root, root);
  }

  static function indexDir(dir:String, root:String):Void
  {
    if (_assetIndex == null) return;
    var index:Map<String, String> = _assetIndex;

    for (entry in sys.FileSystem.readDirectory(dir))
    {
      var fullPath:String = '$dir/$entry';
      if (sys.FileSystem.isDirectory(fullPath))
      {
        indexDir(fullPath, root);
      }
      else
      {
        var nameNoExt:String = Path.withoutExtension(entry);
        var relNoExt:String = Path.withoutExtension(fullPath.substr(root.length + 1));

        var key:String = nameNoExt.toLowerCase();
        if (!index.exists(key)) index.set(key, relNoExt);
      }
    }
  }

  /**
   * Tenta resolver um key antigo/curto pelo nome do arquivo, buscando em
   * toda a árvore de assets. Retorna null se não achar nada.
   */
  public static function resolveByBasename(key:String):Null<String>
  {
    if (_assetIndex == null) buildAssetIndex();
    if (_assetIndex == null) return null;
    var index:Map<String, String> = _assetIndex;

    var lastSlash:Int = key.lastIndexOf('/');
    var baseName:String = lastSlash == -1 ? key : key.substr(lastSlash + 1);

    return index.get(baseName.toLowerCase());
  }
  #end

  static function resolveKey(key:String):String
  {
    var mapped:Null<String> = LEGACY_KEY_MAP.get(key);
    if (mapped != null) return mapped;

    #if sys
    // Só tenta o fallback automático se o path direto não existir.
    if (!sys.FileSystem.exists('assets/$key.png') && !sys.FileSystem.exists('assets/$key'))
    {
      var found:Null<String> = resolveByBasename(key);
      if (found != null) return found;
    }
    #end

    return key;
  }

  static inline function getPreloadPath(file:String):String
  {
    return 'assets/$file';
  }

  /**
   * Kept for backward compatibility with call sites that still expect a
   * "library" name for an asset path (pre-restructure concept). Since the
   * new asset structure only has a single embedded library, this always
   * returns 'default'.
   */
  public static function getLibrary(path:String):String
  {
    return 'default';
  }

  /**
   * Kept for backward compatibility. In the old asset format, a path could be
   * prefixed with "library:" (e.g. "week3:images/bf"). The new structure has
   * no such prefix, so this strips it if present and returns the path as-is
   * otherwise.
   */
  public static function stripLibrary(path:String):String
  {
    var colonIndex:Int = path.indexOf(':');
    if (colonIndex == -1) return path;
    return path.substr(colonIndex + 1);
  }

  public static function file(file:String, type:AssetType = TEXT):String
  {
    return getPreloadPath(resolveKey(file));
  }

  public static function animateAtlas(path:String, ?library:String):String
  {
    return getPreloadPath(resolveKey(path));
  }

  public static function txt(key:String):String
  {
    return getPreloadPath('${resolveKey(key)}.txt');
  }

  public static function frag(key:String):String
  {
    return getPreloadPath('${resolveKey(key)}.frag');
  }

  public static function vert(key:String):String
  {
    return getPreloadPath('${resolveKey(key)}.vert');
  }

  public static function xml(key:String):String
  {
    return getPreloadPath('${resolveKey(key)}.xml');
  }

  public static function json(key:String):String
  {
    return getPreloadPath('${resolveKey(key)}.json');
  }

  public static function srt(key:String, ?library:String, ?directory:String = ''):String
  {
    return getPreloadPath('$directory${resolveKey(key)}.srt');
  }

  public static function sound(key:String, ?library:String):String
  {
    return getPreloadPath('${resolveKey(key)}.${Constants.EXT_SOUND}');
  }

  public static function soundRandom(key:String, min:Int, max:Int):String
  {
    return sound(key + FlxG.random.int(min, max));
  }

  public static function music(key:String):String
  {
    return getPreloadPath('${resolveKey(key)}.${Constants.EXT_SOUND}');
  }

  public static function videos(key:String):String
  {
    final resolved:String = resolveKey(key);
    final path:Path = new Path(resolved);

    if (path.ext != null)
    {
      return getPreloadPath(resolved);
    }

    return getPreloadPath('$resolved.${Constants.EXT_VIDEO}');
  }

  public static function voices(song:String, ?suffix:String = ''):String
  {
    if (suffix == null) suffix = '';

    return getPreloadPath('gameplay/songs/${song.toLowerCase()}/Voices$suffix.${Constants.EXT_SOUND}');
  }

  public static function inst(song:String, ?suffix:String = '', withExtension:Bool = true):String
  {
    var ext:String = withExtension ? '.${Constants.EXT_SOUND}' : '';
    return getPreloadPath('gameplay/songs/${song.toLowerCase()}/Inst$suffix$ext');
  }

  public static function image(key:String, ?library:String):String
  {
    return getPreloadPath('${resolveKey(key)}.png');
  }

  public static function font(key:String):String
  {
    return getPreloadPath('ui/fonts/$key');
  }

  public static function ui(key:String):String
  {
    return xml('ui/$key');
  }

  public static function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
  {
    return FlxAtlasFrames.fromSparrow(image(key), file('${resolveKey(key)}.xml'));
  }

  public static function getAnimateAtlas(key:String, ?library:String, settings:AtlasSpriteSettings):FlxAnimateFrames
  {
    var graphicKey:String = getPreloadPath(resolveKey(key));

    var validatedSettings:AtlasSpriteSettings = {
      swfMode: settings?.swfMode ?? false,
      cacheOnLoad: settings?.cacheOnLoad ?? false,
      filterQuality: settings?.filterQuality ?? MEDIUM,
      spritemaps: settings?.spritemaps ?? null,
      metadataJson: settings?.metadataJson ?? null,
      cacheKey: settings?.cacheKey ?? null,
      uniqueInCache: settings?.uniqueInCache ?? false,
      onSymbolCreate: settings?.onSymbolCreate ?? null,
      applyStageMatrix: settings?.applyStageMatrix ?? false,
      useRenderTexture: settings?.useRenderTexture ?? false
    };

    if (!Assets.exists('${graphicKey}/Animation.json'))
    {
      throw 'No Animation.json file exists at the specified path (${graphicKey})';
    }

    return FlxAnimateFrames.fromAnimate(
      graphicKey,
      validatedSettings.spritemaps,
      validatedSettings.metadataJson,
      validatedSettings.cacheKey,
      validatedSettings.uniqueInCache,
      {
        swfMode: validatedSettings.swfMode,
        cacheOnLoad: validatedSettings.cacheOnLoad,
        filterQuality: validatedSettings.filterQuality,
        onSymbolCreate: validatedSettings.onSymbolCreate
      }
    );
  }

  public static function getPackerAtlas(key:String):FlxAtlasFrames
  {
    return FlxAtlasFrames.fromSpriteSheetPacker(image(key), file('${resolveKey(key)}.txt'));
  }
}

enum abstract PathsFunction(String)
{
  public var MUSIC;
  public var INST;
  public var VOICES;
  public var SOUND;
}
