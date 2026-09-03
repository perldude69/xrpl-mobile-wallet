/// XRP drop / decimal conversions using [BigInt] only (no floating point).
///
/// 1 XRP = 1_000_000 drops.
class XrpAmount {
  XrpAmount._();

  static final BigInt dropsPerXrp = BigInt.from(1000000);

  /// Convert a drops integer string to a display XRP decimal string.
  /// Trailing fractional zeros are stripped (`1000000` → `1`, `1500000` → `1.5`).
  static String dropsToXrp(String drops) {
    final value = BigInt.parse(drops.trim());
    final negative = value.isNegative;
    final abs = value.abs();
    final whole = abs ~/ dropsPerXrp;
    final frac = abs % dropsPerXrp;
    if (frac == BigInt.zero) {
      return negative ? '-$whole' : whole.toString();
    }
    final fracStr =
        frac.toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '');
    final result = '$whole.$fracStr';
    return negative ? '-$result' : result;
  }

  /// Convert an XRP decimal string to a drops integer string.
  /// At most 6 fractional digits are accepted; shorter fractions are padded.
  static String xrpToDrops(String xrp) {
    final trimmed = xrp.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Empty XRP amount');
    }

    final negative = trimmed.startsWith('-');
    final raw = negative ? trimmed.substring(1) : trimmed;
    if (raw.isEmpty) {
      throw FormatException('Invalid XRP amount: $xrp');
    }

    final parts = raw.split('.');
    if (parts.length > 2) {
      throw FormatException('Invalid XRP amount: $xrp');
    }

    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    if (!RegExp(r'^\d+$').hasMatch(wholePart)) {
      throw FormatException('Invalid XRP amount: $xrp');
    }

    var fracPart = parts.length == 2 ? parts[1] : '';
    if (fracPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fracPart)) {
      throw FormatException('Invalid XRP amount: $xrp');
    }
    if (fracPart.length > 6) {
      throw FormatException('XRP amount has more than 6 decimal places: $xrp');
    }
    fracPart = fracPart.padRight(6, '0');

    final whole = BigInt.parse(wholePart);
    final frac = BigInt.parse(fracPart);
    final drops = whole * dropsPerXrp + frac;
    return negative ? '-$drops' : drops.toString();
  }
}
