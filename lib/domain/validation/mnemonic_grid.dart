/// Rules for assembling a BIP39 phrase from a fixed 24-slot grid.
///
/// Spec: always show 24 cells. Accept 24 filled words, or exactly slots 1–12
/// filled with 13–24 empty (12-word phrase). Any other pattern is rejected.
class MnemonicGrid {
  MnemonicGrid._();

  static const int slotCount = 24;

  /// Normalize a single cell: trim and lowercase (BIP39 English).
  static String normalizeWord(String raw) => raw.trim().toLowerCase();

  /// Join [cells] (length [slotCount]) into a phrase, or throw [ArgumentError].
  ///
  /// [cells] are raw field values; empty means unused.
  static String phraseFromCells(List<String> cells) {
    if (cells.length != slotCount) {
      throw ArgumentError('Grid must have $slotCount cells');
    }
    final words = cells.map(normalizeWord).toList();
    final nonEmptyIndexes = <int>[];
    for (var i = 0; i < words.length; i++) {
      if (words[i].isNotEmpty) nonEmptyIndexes.add(i);
    }

    if (nonEmptyIndexes.length == slotCount) {
      return words.join(' ');
    }

    // Exactly positions 0–11 filled (1–12), 12–23 empty.
    if (nonEmptyIndexes.length == 12) {
      final isFirstTwelve = nonEmptyIndexes.every((i) => i < 12) &&
          nonEmptyIndexes.length == 12 &&
          List.generate(12, (i) => i).every((i) => words[i].isNotEmpty);
      if (isFirstTwelve) {
        return words.sublist(0, 12).join(' ');
      }
    }

    throw ArgumentError('Enter 12 or 24 recovery words');
  }

  /// Split a pasted phrase into up to [slotCount] words (normalized).
  static List<String> splitPaste(String pasted) {
    final parts = pasted
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.length > slotCount) {
      return parts.sublist(0, slotCount);
    }
    return parts;
  }
}
