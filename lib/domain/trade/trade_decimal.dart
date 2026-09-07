/// Exact base-10 decimal arithmetic for trade maths.
///
/// XRPL money is decimal, not binary: XRP is an integer number of drops
/// (6 dp) and an issued amount such as RLUSD carries **15 significant
/// figures**. A binary `double` represents neither exactly — `0.1 + 0.2` is
/// already wrong at the 17th digit — so every rate, slippage bound and derived
/// amount in `domain/trade/` goes through this type instead. There is no
/// floating point anywhere in the trade path.
///
/// The value is `unscaled / 10^scale`, both exact. Pure: no I/O, no Flutter.
class TradeDecimal implements Comparable<TradeDecimal> {
  const TradeDecimal._(this.unscaled, this.scale);

  /// Integer numerator. The value is [unscaled] / 10^[scale].
  final BigInt unscaled;

  /// Number of digits after the decimal point. Always >= 0.
  final int scale;

  static final TradeDecimal zero = TradeDecimal._(BigInt.zero, 0);
  static final TradeDecimal one = TradeDecimal._(BigInt.one, 0);

  static final BigInt _ten = BigInt.from(10);

  /// Parse a decimal string.
  ///
  /// Accepts an optional sign, digits with an optional fraction, and an
  /// optional `e`/`E` exponent — the ledger and some public nodes render
  /// small issued amounts in scientific notation (`1e-8`), and silently
  /// mis-reading one as zero would corrupt a fill record.
  ///
  /// Throws [FormatException] on anything else. There is deliberately no
  /// lenient fallback: an unparseable amount must fail loudly rather than
  /// become a wrong number.
  factory TradeDecimal.parse(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      throw const FormatException('Empty decimal value');
    }
    final match = RegExp(
      r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
    ).firstMatch(text);
    if (match == null) {
      throw FormatException('Invalid decimal value: $value');
    }
    final negative = match.group(1) == '-';
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final exponent = int.parse(match.group(4) ?? '0');

    var unscaled = BigInt.parse('$whole$fraction');
    var scale = fraction.length - exponent;
    if (negative) unscaled = -unscaled;

    // A negative scale means the exponent pushed digits above the point;
    // materialise them so scale stays >= 0 and the type has one shape.
    if (scale < 0) {
      unscaled *= _ten.pow(-scale);
      scale = 0;
    }
    return TradeDecimal._(unscaled, scale);
  }

  /// Parse, or null when [value] is null or not a valid decimal.
  ///
  /// For ledger fields that are legitimately absent. Never use this to swallow
  /// a malformed amount that was expected to be present.
  static TradeDecimal? tryParse(String? value) {
    if (value == null) return null;
    try {
      return TradeDecimal.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Build from an integer count of the smallest unit, e.g. XRP drops
  /// (`scale` 6).
  factory TradeDecimal.fromUnscaled(BigInt unscaled, int scale) {
    if (scale < 0) {
      throw ArgumentError.value(scale, 'scale', 'must not be negative');
    }
    return TradeDecimal._(unscaled, scale);
  }

  bool get isZero => unscaled == BigInt.zero;
  bool get isNegative => unscaled.isNegative;
  bool get isPositive => !isNegative && !isZero;

  TradeDecimal operator -() => TradeDecimal._(-unscaled, scale);

  TradeDecimal operator +(TradeDecimal other) {
    final s = scale > other.scale ? scale : other.scale;
    return TradeDecimal._(_at(s) + other._at(s), s);
  }

  TradeDecimal operator -(TradeDecimal other) => this + (-other);

  /// Exact product. The scale is the sum of the operand scales, so no
  /// information is lost here — rounding happens only where a caller asks for
  /// it, via [withScale] or [roundToSignificantFigures].
  TradeDecimal operator *(TradeDecimal other) =>
      TradeDecimal._(unscaled * other.unscaled, scale + other.scale);

  /// Divide, rounding at [scale] decimal places.
  ///
  /// [roundUp] rounds toward positive infinity (ceiling); otherwise toward
  /// negative infinity (floor). There is no "round half up" — trade amounts
  /// are bounds, and every caller must state which side of the bound it wants
  /// to land on.
  TradeDecimal divide(
    TradeDecimal divisor, {
    required int scale,
    required bool roundUp,
  }) {
    if (divisor.isZero) {
      throw ArgumentError.value(divisor, 'divisor', 'division by zero');
    }
    if (scale < 0) {
      throw ArgumentError.value(scale, 'scale', 'must not be negative');
    }
    // (a/10^sa) / (b/10^sb) at target scale s
    //   = a * 10^(sb + s) / (b * 10^sa)
    final numerator = unscaled * _ten.pow(divisor.scale + scale);
    final denominator = divisor.unscaled * _ten.pow(this.scale);
    return TradeDecimal._(
      _divRound(numerator, denominator, roundUp: roundUp),
      scale,
    );
  }

  /// Re-express at [targetScale], rounding when digits are dropped.
  TradeDecimal withScale(int targetScale, {required bool roundUp}) {
    if (targetScale < 0) {
      throw ArgumentError.value(
        targetScale,
        'targetScale',
        'must not be negative',
      );
    }
    if (targetScale == scale) return this;
    if (targetScale > scale) {
      return TradeDecimal._(
        unscaled * _ten.pow(targetScale - scale),
        targetScale,
      );
    }
    return TradeDecimal._(
      _divRound(unscaled, _ten.pow(scale - targetScale), roundUp: roundUp),
      targetScale,
    );
  }

  /// Round to at most [figures] significant digits.
  ///
  /// This is the issued-amount precision limit: an XRPL IOU mantissa holds 15
  /// significant figures, and submitting more is either rejected or silently
  /// truncated by the ledger. Doing it here, explicitly and in the stated
  /// direction, keeps the submitted number the same one the review screen
  /// showed.
  TradeDecimal roundToSignificantFigures(int figures, {required bool roundUp}) {
    if (figures <= 0) {
      throw ArgumentError.value(figures, 'figures', 'must be positive');
    }
    if (isZero) return this;
    final digits = unscaled.abs().toString().length;
    if (digits <= figures) return this;
    final drop = digits - figures;
    if (drop > scale) {
      // Rounding would have to reach above the decimal point. Keep the value
      // exact rather than fabricate a scale the caller did not ask for; the
      // amounts this code handles never get near this.
      return this;
    }
    return withScale(scale - drop, roundUp: roundUp);
  }

  /// Strip trailing fractional zeros without changing the value.
  TradeDecimal get normalized {
    if (isZero) return TradeDecimal._(BigInt.zero, 0);
    var u = unscaled;
    var s = scale;
    while (s > 0 && u % _ten == BigInt.zero) {
      u = u ~/ _ten;
      s -= 1;
    }
    return TradeDecimal._(u, s);
  }

  @override
  int compareTo(TradeDecimal other) {
    final s = scale > other.scale ? scale : other.scale;
    return _at(s).compareTo(other._at(s));
  }

  bool operator <(TradeDecimal other) => compareTo(other) < 0;
  bool operator <=(TradeDecimal other) => compareTo(other) <= 0;
  bool operator >(TradeDecimal other) => compareTo(other) > 0;
  bool operator >=(TradeDecimal other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is TradeDecimal && compareTo(other) == 0;

  @override
  int get hashCode {
    final n = normalized;
    return Object.hash(n.unscaled, n.scale);
  }

  /// Canonical plain-decimal rendering, trailing fractional zeros stripped.
  /// Never scientific notation — this string goes into XRPL amount fields and
  /// into the database.
  @override
  String toString() {
    final n = normalized;
    if (n.scale == 0) return n.unscaled.toString();
    final negative = n.unscaled.isNegative;
    final digits = n.unscaled.abs().toString().padLeft(n.scale + 1, '0');
    final cut = digits.length - n.scale;
    final text = '${digits.substring(0, cut)}.${digits.substring(cut)}';
    return negative ? '-$text' : text;
  }

  BigInt _at(int targetScale) => targetScale == scale
      ? unscaled
      : unscaled * _ten.pow(targetScale - scale);

  /// Floor/ceiling integer division. Dart's `~/` truncates toward zero, which
  /// is neither, and getting it wrong flips the rounding direction for
  /// negative values (balance deltas are routinely negative).
  static BigInt _divRound(
    BigInt numerator,
    BigInt denominator, {
    required bool roundUp,
  }) {
    var n = numerator;
    var d = denominator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final q = n ~/ d;
    final remainder = n - q * d;
    if (remainder == BigInt.zero) return q;
    if (roundUp) return n.isNegative ? q : q + BigInt.one;
    return n.isNegative ? q - BigInt.one : q;
  }
}
