package funkin.data.freeplay.player;

import funkin.ui.freeplay.charselect.PlayableCharacter;
import funkin.save.Save;
import funkin.util.tools.ISingleton;
import funkin.util.assets.DataAssets;
import funkin.data.DefaultRegistryImpl;

@:nullSafety
class PlayerRegistry extends BaseRegistry<PlayableCharacter, PlayerData, PlayerEntryParams> implements ISingleton implements DefaultRegistryImpl
{
  /**
   * The current version string for the stage data format.
   * Handle breaking changes by incrementing this value
   * and adding migration to the `migratePlayerData()` function.
   */
  public static final PLAYER_DATA_VERSION:thx.semver.Version = '1.0.0';

  public static final PLAYER_DATA_VERSION_RULE:thx.semver.VersionRule = '1.0.x';

  /**
   * A mapping between stage character IDs and Freeplay playable character IDs.
   */
  var ownedCharacterIds:Map<String, String> = [];

  public function new()
  {
    super('PLAYER', 'gameplay/playable-characters', PLAYER_DATA_VERSION_RULE);
  }

  /**
   * Override: os JSONs de playable character ficam dentro de uma subpasta
   * com o mesmo nome do ID (ex: gameplay/playable-characters/bf/bf.json).
   * listDataFilesInPath retorna o path completo incluindo a subpasta
   * (ex: "bf/bf"), então extraímos só o primeiro segmento como ID real,
   * igual o SongRegistry já faz.
   */
  override public function loadEntries():Void
  {
    trace('DEBUG listDataFilesInPath result: ' + DataAssets.listDataFilesInPath('${dataFilePath}/'));
    clearEntries();

    var scriptedEntryClassNames:Array<String> = getScriptedClassNames();
    log(' INFO '.info() + 'Parsing ${scriptedEntryClassNames.length} scripted entries...');

    for (entryCls in scriptedEntryClassNames)
    {
      var entry = createScriptedEntry(entryCls);
      if (entry != null)
      {
        entries.set(entry.id, entry);
        scriptedEntryIds.set(entry.id, entryCls);
        log('Successfully created scripted entry (${entryCls} = ${entry.id})');
      }
      else
      {
        log('Failed to create scripted entry (${entryCls})');
      }
    }

    var entryIdList:Array<String> = DataAssets.listDataFilesInPath('${dataFilePath}/').map(function(path:String):String
    {
      return path.split('/')[0];
    });
    var unscriptedEntryIds:Array<String> = entryIdList.filter(function(id:String):Bool
    {
      return !entries.exists(id);
    });
    log(' INFO '.info() + 'Parsing ${unscriptedEntryIds.length} unscripted entries...');

    for (entryId in unscriptedEntryIds)
    {
      try
      {
        var entry = createEntry(entryId);
        if (entry != null)
        {
          log('Loaded entry data: ${entry}');
          entries.set(entry.id, entry);
        }
      }
      catch (e)
      {
        log(' WARNING '.warning() + ' Failed to load entry data: ${entryId}');
        trace(e);
        continue;
      }
    }

    for (playerId in listEntryIds())
    {
      var player = fetchEntry(playerId);
      if (player == null) continue;

      var currentPlayerCharIds = player.getOwnedCharacterIds();
      for (characterId in currentPlayerCharIds)
      {
        ownedCharacterIds.set(characterId, playerId);
      }
    }

    log('Loaded ${countEntries()} playable characters with ${ownedCharacterIds.size()} associations.');
    trace('Loaded players: ' + PlayerRegistry.instance.listEntryIds());
  }

  /**
   * Override: o JSON de cada player fica em <dataFilePath>/<id>/<id>.json,
   * não em <dataFilePath>/<id>.json como o BaseRegistry assume por padrão.
   */
  override function loadEntryFile(id:String):JsonFile
  {
    var entryFilePath:String = Paths.json('$dataFilePath/$id/$id');
    var rawJson:String = openfl.Assets.getText(entryFilePath).trim();
    return {
      fileName: entryFilePath,
      contents: rawJson
    };
  }

  public function countUnlockedCharacters():Int
  {
    var count = 0;

    for (charId in listEntryIds())
    {
      var player = fetchEntry(charId);
      if (player == null) continue;

      #if UNLOCK_EVERYTHING
      count++;
      #else
      if (player.isUnlocked()) count++;
      #end
    }

    return count;
  }

  public function hasNewCharacter():Bool
  {
    #if (!UNLOCK_EVERYTHING)
    var charactersSeen = Save.instance.charactersSeen.value.clone();

    for (charId in listEntryIds())
    {
      var player = fetchEntry(charId);
      if (player == null) continue;

      if (!player.isUnlocked()) continue;
      if (charactersSeen.contains(charId)) continue;

      // This character is unlocked but we haven't seen them in Freeplay yet.
      return true;
    }
    #end

    // Fallthrough case.
    return false;
  }

  public function listNewCharacters():Array<String>
  {
    var result = [];

    #if (!UNLOCK_EVERYTHING)
    var charactersSeen = Save.instance.charactersSeen.value.clone();
    for (charId in listEntryIds())
    {
      var player = fetchEntry(charId);
      if (player == null) continue;

      if (!player.isUnlocked()) continue;
      if (charactersSeen.contains(charId)) continue;

      // This character is unlocked but we haven't seen them in Freeplay yet.
      result.push(charId);
    }
    #end

    return result;
  }

  /**
   * Get the playable character associated with a given stage character.
   * @param characterId The stage character ID.
   * @return The playable character.
   */
  public function getCharacterOwnerId(characterId:Null<String>):Null<String>
  {
    if (characterId == null) return null;
    return ownedCharacterIds[characterId];
  }

  /**
   * Return true if the given stage character is associated with a specific playable character.
   * If so, the level should only appear if that character is selected in Freeplay.
   * NOTE: This is NOT THE SAME as `player.isUnlocked()`!
   * @param characterId The stage character ID.
   * @return Whether the character is owned by any one character.
   */
  public function isCharacterOwned(characterId:String):Bool
  {
    return ownedCharacterIds.exists(characterId);
  }

  /**
   * @param characterId The character ID to check.
   * @return Whether the player saw the character unlock animation in Character Select.
   */
  public function isCharacterSeen(characterId:String):Bool
  {
    #if UNLOCK_EVERYTHING
    return true;
    #else
    return Save.instance.charactersSeen.value.contains(characterId);
    #end
  }
}

typedef PlayerEntryParams =
{
}
