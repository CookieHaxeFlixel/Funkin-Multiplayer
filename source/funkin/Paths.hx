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
    return getPreloadPath(file);
  }

  public static function animateAtlas(path:String, ?library:String):String
  {
    return getPreloadPath('$path');
  }

  public static function txt(key:String):String
  {
    return getPreloadPath('$key.txt');
  }

  public static function frag(key:String):String
  {
    return getPreloadPath('$key.frag');
  }

  public static function vert(key:String):String
  {
    return getPreloadPath('$key.vert');
  }

  public static function xml(key:String):String
  {
    return getPreloadPath('$key.xml');
  }

  public static function json(key:String):String
  {
    return getPreloadPath('$key.json');
  }

  public static function srt(key:String, ?library:String, ?directory:String = ''):String
  {
    return getPreloadPath('$directory$key.srt');
  }

  public static function sound(key:String, ?library:String):String
  {
    return getPreloadPath('$key.${Constants.EXT_SOUND}');
  }

  public static function soundRandom(key:String, min:Int, max:Int):String
  {
    return sound(key + FlxG.random.int(min, max));
  }

  public static function music(key:String):String
  {
    return getPreloadPath('$key.${Constants.EXT_SOUND}');
  }

  public static function videos(key:String):String
  {
    final path:Path = new Path(key);

    if (path.ext != null)
    {
      return getPreloadPath(key);
    }

    return getPreloadPath('$key.${Constants.EXT_VIDEO}');
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
    return getPreloadPath('$key.png');
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
    return FlxAtlasFrames.fromSparrow(image(key), file('$key.xml'));
  }

  public static function getAnimateAtlas(key:String, ?library:String, settings:AtlasSpriteSettings):FlxAnimateFrames
  {
    var graphicKey:String = getPreloadPath(key);

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

    return FlxAnimateFrames.fromAnimate(graphicKey, validatedSettings.spritemaps, validatedSettings.metadataJson, validatedSettings.cacheKey,
      validatedSettings.uniqueInCache, {
        swfMode: validatedSettings.swfMode,
        cacheOnLoad: validatedSettings.cacheOnLoad,
        filterQuality: validatedSettings.filterQuality,
        onSymbolCreate: validatedSettings.onSymbolCreate
      });
  }

  public static function getPackerAtlas(key:String):FlxAtlasFrames
  {
    return FlxAtlasFrames.fromSpriteSheetPacker(image(key), file('$key.txt'));
  }
}

enum abstract PathsFunction(String)
{
  public var MUSIC;
  public var INST;
  public var VOICES;
  public var SOUND;
}
