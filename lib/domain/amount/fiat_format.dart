/// XRP ↔ USD display helpers (portfolio fiat mode).
class FiatFormat {
  FiatFormat._();

  /// Format USD amount for UI (e.g. `$1,234.56`).
  static String formatUsd(double amount) {
    if (!amount.isFinite) return '—';
    final neg = amount < 0;
    final a = amount.abs();
    final whole = a.floor();
    final frac = ((a - whole) * 100).round().clamp(0, 99);
    final wholeStr = _groupThousands(whole);
    final fracStr = frac.toString().padLeft(2, '0');
    final s = '\$$wholeStr.$fracStr';
    return neg ? '-$s' : s;
  }

  /// Format rate line (e.g. `$1.0748 / XRP`).
  static String formatRate(double usdPerXrp) {
    if (!usdPerXrp.isFinite || usdPerXrp <= 0) return 'Rate unavailable';
    // Up to 4 decimals for sub-$10 XRP, fewer for larger.
    final digits = usdPerXrp >= 100
        ? 2
        : usdPerXrp >= 10
            ? 3
            : 4;
    final s = usdPerXrp.toStringAsFixed(digits);
    // Trim trailing zeros after decimal
    final trimmed = s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
    return '\$$trimmed / XRP';
  }

  /// XRP decimal string × rate → USD.
  static double? xrpToUsd(String? xrp, double? usdPerXrp) {
    if (xrp == null || usdPerXrp == null || !usdPerXrp.isFinite) return null;
    final v = double.tryParse(xrp);
    if (v == null || !v.isFinite) return null;
    return v * usdPerXrp;
  }

  static String _groupThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
