package funkin.util;

/**
 * Traduz paths no formato antigo (pre-restructure) pro formato novo,
 * pra manter compatibilidade sem precisar reescrever call sites.
 *
 * Ex: "assets/preload/images/bf.png" -> "assets/preload/gameplay/characters/bf/bf.png"
 *
 * Uso: chame PathAlias.resolve(path) em QUALQUER lugar que resolve um path
 * antes de checar existência/ler o arquivo (getPath, exists, getBytes, etc.
 * no seu backend custom do Polymod).
 */
class PathTranslatorUtil
{
  // Prefixo antigo -> prefixo novo. Ordem importa: mais específico primeiro.
  static final ALIASES:Array<
    {from:String, to:String}> = [
    {
      from: 'assets/preload/images/',
      to: 'assets/preload/gameplay/'
    },
    {
      from: 'assets/preload/sounds/',
      to: 'assets/preload/gameplay/'
    },
    {
      from: 'assets/preload/music/',
      to: 'assets/preload/gameplay/'
    },
    {
      from: 'assets/preload/data/',
      to: 'assets/preload/gameplay/'
    },
    // adiciona mais linhas aqui conforme achar mais pastas movidas
  ];

  /**
   * Recebe um path pedido pelo código antigo e devolve o path real,
   * se ele existir no formato novo. Se não existir em lugar nenhum
   * dos dois, devolve o path original sem modificar.
   */
  public static function resolve(path:String):String
  {
    // Se já existe como pedido, não mexe.
    if (sys.FileSystem.exists(path)) return path;

    for (alias in ALIASES)
    {
      if (StringTools.startsWith(path, alias.from))
      {
        var remapped:String = alias.to + path.substr(alias.from.length);
        if (sys.FileSystem.exists(remapped)) return remapped;
      }
    }

    // Não achou em lugar nenhum: devolve original (deixa o erro real aparecer).
    return path;
  }
}
