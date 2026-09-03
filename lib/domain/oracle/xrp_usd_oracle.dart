import 'dart:convert';

/// Parsed XRP→USD quote from the XRPL-Labs TrustSet oracle.
class XrpUsdQuote {
  const XrpUsdQuote({
    required this.usdPerXrp,
    required this.at,
    this.hash,
    this.exchangeRates = const {},
  });

  /// Aggregate USD price of 1 XRP ([TrustSet.LimitAmount.value]).
  final double usdPerXrp;

  /// Best-effort wall clock for the quote (tx date or receive time).
  final DateTime at;

  final String? hash;

  /// Optional per-venue last sample from memos (`rates:Binance` → last field).
  final Map<String, double> exchangeRates;

  bool get isPositive => usdPerXrp > 0 && usdPerXrp.isFinite;
}

/// Pure parser for XRPL-Labs oracle account transactions / stream messages.
///
/// Account: [oracleAddress] publishes ~1/min `TrustSet` with
/// `LimitAmount.currency=USD` and aggregate in `LimitAmount.value`.
class XrpUsdOracle {
  XrpUsdOracle._();

  static const oracleAddress = 'rXUMMaPpZqPutoRszR29jtC8amWq3APkx';

  /// Ripple epoch → UTC (seconds since 2000-01-01).
  static DateTime rippleEpochToUtc(int seconds) =>
      DateTime.utc(2000, 1, 1).add(Duration(seconds: seconds));

  /// Parse a stream or RPC transaction map (`tx` / `transaction` / `tx_json`).
  static XrpUsdQuote? parseTransaction(
    Map<String, dynamic> tx, {
    DateTime? receivedAt,
    String? hash,
  }) {
    final type = tx['TransactionType']?.toString();
    if (type != 'TrustSet') return null;

    final account = tx['Account']?.toString() ?? '';
    if (account != oracleAddress) return null;

    final limit = tx['LimitAmount'];
    if (limit is! Map) return null;
    final currency = limit['currency']?.toString();
    if (currency != 'USD') return null;
    final valueRaw = limit['value']?.toString();
    if (valueRaw == null || valueRaw.isEmpty) return null;
    final value = double.tryParse(valueRaw);
    if (value == null || !value.isFinite || value <= 0) return null;

    DateTime at = receivedAt ?? DateTime.now().toUtc();
    final date = tx['date'];
    if (date is int) {
      at = rippleEpochToUtc(date);
    } else if (date is num) {
      at = rippleEpochToUtc(date.toInt());
    }

    final h = hash ?? tx['hash']?.toString();

    return XrpUsdQuote(
      usdPerXrp: value,
      at: at,
      hash: h,
      exchangeRates: _parseExchangeMemos(tx['Memos']),
    );
  }

  /// Parse flexible WSS `transaction` message.
  static XrpUsdQuote? parseStreamMessage(Map<String, dynamic> message) {
    if (message['validated'] == false) return null;
    final tx = _asMap(message['transaction']) ??
        _asMap(message['tx_json']) ??
        _asMap(message['tx']);
    if (tx == null) return null;
    final hash = tx['hash']?.toString() ??
        message['hash']?.toString() ??
        _asMap(message['meta'])?['TransactionHash']?.toString();
    return parseTransaction(tx, hash: hash);
  }

  /// Parse `account_tx` item (`tx` + optional outer hash).
  static XrpUsdQuote? parseAccountTxItem(Map<String, dynamic> item) {
    final tx = _asMap(item['tx']) ??
        _asMap(item['tx_json']) ??
        _asMap(item['transaction']);
    if (tx == null) return null;
    final hash = tx['hash']?.toString() ?? item['hash']?.toString();
    return parseTransaction(tx, hash: hash);
  }

  static Map<String, double> _parseExchangeMemos(Object? memos) {
    if (memos is! List) return const {};
    final out = <String, double>{};
    for (final m in memos) {
      final memo = _asMap(m is Map ? m['Memo'] : null) ?? _asMap(m);
      if (memo == null) continue;
      final typeHex = memo['MemoType']?.toString();
      final dataHex = memo['MemoData']?.toString() ?? '';
      if (typeHex == null || typeHex.isEmpty) continue;
      final type = _hexToUtf8(typeHex);
      if (type == null || !type.startsWith('rates:')) continue;
      final venue = type.substring('rates:'.length);
      if (dataHex.isEmpty) continue;
      final data = _hexToUtf8(dataHex);
      if (data == null || data.isEmpty) continue;
      final parts = data.split(';');
      for (var i = parts.length - 1; i >= 0; i--) {
        final v = double.tryParse(parts[i].trim());
        if (v != null && v.isFinite && v > 0) {
          out[venue] = v;
          break;
        }
      }
    }
    return out;
  }

  static String? _hexToUtf8(String hex) {
    try {
      final cleaned = hex.trim();
      if (cleaned.isEmpty || cleaned.length.isOdd) return null;
      final bytes = <int>[];
      for (var i = 0; i < cleaned.length; i += 2) {
        bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _asMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}
