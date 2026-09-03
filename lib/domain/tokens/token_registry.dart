import 'dart:convert';

import 'package:flutter/services.dart';

/// One XRPSCAN-derived token identity (currency + issuer).
class TokenMeta {
  const TokenMeta({
    required this.currency,
    required this.issuer,
    required this.code,
    required this.name,
  });

  final String currency;
  final String issuer;

  /// Short symbol (e.g. RLUSD).
  final String code;

  /// Friendly name (e.g. Ripple USD).
  final String name;

  factory TokenMeta.fromJson(Map<String, dynamic> json) {
    return TokenMeta(
      currency: (json['currency'] as String? ?? '').trim(),
      issuer: (json['issuer'] as String? ?? '').trim(),
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
    );
  }
}

/// In-memory token catalog loaded from XRPSCAN snapshot JSON.
///
/// Source: https://xrpscan.com/tokens via https://api.xrpscan.com/api/v1/tokens
class TokenRegistry {
  TokenRegistry._(this._byPair, this._byCurrency);

  final Map<String, TokenMeta> _byPair;
  final Map<String, TokenMeta> _byCurrency;

  static TokenRegistry empty() => TokenRegistry._({}, {});

  /// Load bundled asset `assets/tokens/xrpscan_tokens.json`.
  static Future<TokenRegistry> loadFromAsset({
    String assetPath = 'assets/tokens/xrpscan_tokens.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    return fromJsonString(raw);
  }

  /// Parse snapshot JSON (for tests and offline fixtures).
  static TokenRegistry fromJsonString(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = map['entries'] as List<dynamic>? ?? const [];
    final byPair = <String, TokenMeta>{};
    final byCurrency = <String, TokenMeta>{};

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final meta = TokenMeta.fromJson(item);
      if (meta.currency.isEmpty) continue;
      final curKey = meta.currency.toUpperCase();
      if (meta.issuer.isNotEmpty) {
        byPair[_pairKey(curKey, meta.issuer)] = meta;
      }
      // First entry wins for currency-only lookup (higher XRPSCAN score first).
      byCurrency.putIfAbsent(curKey, () => meta);
    }
    return TokenRegistry._(byPair, byCurrency);
  }

  static String _pairKey(String currencyUpper, String issuer) =>
      '$currencyUpper|$issuer';

  TokenMeta? lookup({required String currency, String? issuer}) {
    final cur = currency.trim();
    if (cur.isEmpty) return null;
    final curKey = cur.toUpperCase();
    final iss = issuer?.trim();
    if (iss != null && iss.isNotEmpty) {
      final hit = _byPair[_pairKey(curKey, iss)];
      if (hit != null) return hit;
    }
    return _byCurrency[curKey];
  }

  int get size => _byPair.length;
}
