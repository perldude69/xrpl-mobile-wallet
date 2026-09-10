/// Comic treasure assigned to a wallet from its classic address.
///
/// Stable for a given address. Uses the same FNV mix as wallet colors plus
/// an extra multiply so color and kind are not 1:1. Avatar art only.
enum TreasureKind {
  chest,
  coins,
  goblet,
  pearl,
  crown,
  compass,
  map,
  gem,
  spyglass,
  key,
  ring,
  anchor;

  String get semanticLabel => switch (this) {
    TreasureKind.chest => 'Treasure chest',
    TreasureKind.coins => 'Gold coins',
    TreasureKind.goblet => 'Goblet',
    TreasureKind.pearl => 'Pearl',
    TreasureKind.crown => 'Crown',
    TreasureKind.compass => 'Compass',
    TreasureKind.map => 'Treasure map',
    TreasureKind.gem => 'Gem',
    TreasureKind.spyglass => 'Spyglass',
    TreasureKind.key => 'Key',
    TreasureKind.ring => 'Ring',
    TreasureKind.anchor => 'Anchor',
  };

  /// Deterministic kind from a classic address.
  static TreasureKind fromAddress(String address) {
    final s = address.trim();
    if (s.isEmpty) return TreasureKind.chest;
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    h = (h * 2654435761) & 0xFFFFFFFF;
    return TreasureKind.values[h % TreasureKind.values.length];
  }
}
