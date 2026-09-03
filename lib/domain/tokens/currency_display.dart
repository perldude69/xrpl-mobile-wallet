import 'package:xrpl_mobile_wallet/domain/tokens/token_registry.dart';

/// Resolves ledger currency codes to human-readable symbols and names.
///
/// Prefer [TokenRegistry] (XRPSCAN snapshot). Fall back to XRPL nonstandard
/// hex → ASCII decode, then raw code.
///
/// Spec: https://xrpl.org/docs/references/protocol/data-types/currency-formats
/// Catalog: https://xrpscan.com/tokens
class CurrencyDisplay {
  CurrencyDisplay._();

  static TokenRegistry _registry = TokenRegistry.empty();

  /// Install registry (call once after loading asset / test fixture).
  static void setRegistry(TokenRegistry registry) {
    _registry = registry;
  }

  static TokenRegistry get registry => _registry;

  /// Short symbol for UI (e.g. RLUSD, USD, XRP).
  static String symbol(String currency, {String? issuer}) {
    final c = currency.trim();
    if (c.isEmpty) return c;
    if (c == 'XRP') return 'XRP';

    final meta = _registry.lookup(currency: c, issuer: issuer);
    if (meta != null && meta.code.isNotEmpty) {
      return meta.code;
    }

    final decoded = decodeHexCurrency(c);
    if (decoded != null) return decoded;

    if (c.length == 3) return c;

    // Long opaque hex: shorten for readability
    if (_isHex40(c)) {
      return '${c.substring(0, 8)}…';
    }
    return c;
  }

  /// Friendly name (e.g. Ripple USD). Falls back to [symbol].
  static String name(String currency, {String? issuer}) {
    final c = currency.trim();
    if (c.isEmpty) return c;
    if (c == 'XRP') return 'XRP';

    final meta = _registry.lookup(currency: c, issuer: issuer);
    if (meta != null) {
      if (meta.name.isNotEmpty) return meta.name;
      if (meta.code.isNotEmpty) return meta.code;
    }

    return symbol(currency, issuer: issuer);
  }

  /// List-tile style title: preferred name, or symbol.
  static String title(String currency, {String? issuer, bool preferName = true}) {
    if (preferName) {
      final n = name(currency, issuer: issuer);
      final s = symbol(currency, issuer: issuer);
      // If name equals symbol or is empty, just show symbol once.
      if (n.isEmpty || n == s) return s;
      // For short symbols, show "Ripple USD (RLUSD)" when distinct.
      if (s.isNotEmpty && n != s) return '$n ($s)';
      return n;
    }
    return symbol(currency, issuer: issuer);
  }

  /// Decode 40-char nonstandard currency hex to printable ASCII, or null.
  static String? decodeHexCurrency(String currency) {
    final c = currency.trim();
    if (!_isHex40(c)) return null;

    final bytes = <int>[];
    for (var i = 0; i < 40; i += 2) {
      bytes.add(int.parse(c.substring(i, i + 2), radix: 16));
    }

    // Standard-serialized ISO codes start with 0x00 (3 chars in later bytes).
    if (bytes.isNotEmpty && bytes[0] == 0x00) {
      // Layout: 0x00 + 88 zero bits + 24 bits ASCII (bytes 12-14 typically).
      // Try extract printable from non-zero tail.
      final nonZero = bytes.skipWhile((b) => b == 0).toList();
      if (nonZero.length >= 3) {
        final three = nonZero.take(3).toList();
        if (three.every(_isPrintableAscii)) {
          return String.fromCharCodes(three);
        }
      }
      return null;
    }

    // Nonstandard: ASCII + null padding (e.g. RLUSD).
    final end = bytes.lastIndexWhere((b) => b != 0);
    if (end < 0) return null;
    final slice = bytes.sublist(0, end + 1);
    if (slice.isEmpty || slice.length > 20) return null;
    if (!slice.every(_isPrintableAscii)) return null;
    return String.fromCharCodes(slice);
  }

  static bool _isHex40(String c) =>
      c.length == 40 && RegExp(r'^[0-9A-Fa-f]+$').hasMatch(c);

  static bool _isPrintableAscii(int b) => b >= 0x20 && b <= 0x7E;
}
