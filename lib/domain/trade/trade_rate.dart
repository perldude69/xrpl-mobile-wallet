import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';

/// A price, always expressed as **quote per unit of base** — RLUSD per XRP.
///
/// One direction only. A rate that could silently be either way round is how
/// an order gets placed at the reciprocal of the intended price, so the
/// inverse is a separate, explicitly named value ([basePerQuote]).
class TradeRate implements Comparable<TradeRate> {
  const TradeRate._(this.quotePerBase);

  factory TradeRate.quotePerBase(TradeDecimal value) {
    if (!value.isPositive) {
      throw ArgumentError.value(
        value.toString(),
        'quotePerBase',
        'rate must be greater than zero',
      );
    }
    return TradeRate._(value);
  }

  factory TradeRate.parse(String value) =>
      TradeRate.quotePerBase(TradeDecimal.parse(value));

  /// RLUSD per XRP.
  final TradeDecimal quotePerBase;

  /// XRP per RLUSD.
  ///
  /// Computed at [inverseScale] and rounded **down**, so a rate shown as an
  /// inverse never overstates what a unit of quote buys.
  TradeDecimal get basePerQuote => TradeDecimal.one.divide(
    quotePerBase,
    scale: inverseScale,
    roundUp: false,
  );

  /// Working precision for the reciprocal. Well beyond both XRP drops and the
  /// 15 significant figures of an issued amount, so the round trip through an
  /// inverse does not lose a digit that mattered.
  static const inverseScale = 20;

  @override
  int compareTo(TradeRate other) => quotePerBase.compareTo(other.quotePerBase);

  @override
  bool operator ==(Object other) =>
      other is TradeRate && other.quotePerBase == quotePerBase;

  @override
  int get hashCode => quotePerBase.hashCode;

  @override
  String toString() => quotePerBase.toString();
}

/// The two amount fields of an `OfferCreate`, already rounded to the precision
/// each asset actually stores.
///
/// XRPL naming, from the offer owner's point of view: [getsValue] of
/// [getsAsset] is what this account **gives up**, [paysValue] of [paysAsset]
/// is what it **wants**.
class TakerAmounts {
  const TakerAmounts({
    required this.getsAsset,
    required this.getsValue,
    required this.paysAsset,
    required this.paysValue,
  });

  final TradeAsset getsAsset;
  final TradeDecimal getsValue;
  final TradeAsset paysAsset;
  final TradeDecimal paysValue;

  /// Rate this pair of amounts actually implies, as quote per base.
  ///
  /// Pass the [side] the amounts were built for so base and quote are read off
  /// the correct field rather than guessed.
  TradeDecimal effectiveQuotePerBase(TradeSide side) => side == TradeSide.sell
      ? paysValue.divide(
          getsValue,
          scale: TradeRate.inverseScale,
          roundUp: false,
        )
      : getsValue.divide(
          paysValue,
          scale: TradeRate.inverseScale,
          roundUp: false,
        );

  @override
  String toString() =>
      'gets $getsValue $getsAsset / pays $paysValue $paysAsset';
}

/// Conversions between a rate, an amount and the `OfferCreate` taker fields.
///
/// Pure: no I/O, no Flutter, no floating point.
class TradeRates {
  TradeRates._();

  /// Build the taker fields for an order of [baseAmount] base units at [rate].
  ///
  /// [baseAmount] is the user's stated amount and is used exactly. Only the
  /// *derived* side is rounded, and always in the direction that favours the
  /// account:
  ///
  /// * selling base — the derived side is what you receive, rounded **up**, so
  ///   the offer demands at least the limit rate;
  /// * buying base — the derived side is what you pay, rounded **down**, so the
  ///   offer never pays more than the limit rate.
  ///
  /// The resulting offer's implied rate is therefore never worse than [rate].
  /// At the boundary this can cost a fill by one drop or one significant
  /// figure, which is the correct way for a price bound to fail.
  ///
  /// Throws [ArgumentError] when [baseAmount] is not positive, when it carries
  /// more precision than the base asset can hold, or when the derived side
  /// rounds away to zero (an order too small to express).
  static TakerAmounts takerAmounts({
    required TradePair pair,
    required TradeSide side,
    required TradeDecimal baseAmount,
    required TradeRate rate,
  }) {
    if (!baseAmount.isPositive) {
      throw ArgumentError.value(
        baseAmount.toString(),
        'baseAmount',
        'amount must be greater than zero',
      );
    }
    assertRepresentable(baseAmount, pair.base, field: 'baseAmount');

    final quoteAmount = baseAmount * rate.quotePerBase;
    final sell = side == TradeSide.sell;
    final roundedQuote = roundToAsset(
      quoteAmount,
      pair.quote,
      // Selling base: quote is received, round up. Buying base: quote is paid,
      // round down.
      roundUp: sell,
    );
    if (!roundedQuote.isPositive) {
      throw ArgumentError.value(
        quoteAmount.toString(),
        'baseAmount',
        'order is too small to express at this rate',
      );
    }

    final roundedBase = roundToAsset(baseAmount, pair.base, roundUp: !sell);
    return sell
        ? TakerAmounts(
            getsAsset: pair.base,
            getsValue: roundedBase,
            paysAsset: pair.quote,
            paysValue: roundedQuote,
          )
        : TakerAmounts(
            getsAsset: pair.quote,
            getsValue: roundedQuote,
            paysAsset: pair.base,
            paysValue: roundedBase,
          );
  }

  /// Round [value] to the precision [asset] actually stores.
  ///
  /// XRP snaps to whole drops (6 dp). An issued amount keeps at most 15
  /// significant figures — submitting more is not more precise, it is just a
  /// number the ledger will quietly reshape.
  static TradeDecimal roundToAsset(
    TradeDecimal value,
    TradeAsset asset, {
    required bool roundUp,
  }) {
    if (asset.isXrp) {
      return value.withScale(TradeAsset.xrpScale, roundUp: roundUp);
    }
    return value.roundToSignificantFigures(
      TradeAsset.issuedSignificantFigures,
      roundUp: roundUp,
    );
  }

  /// Throw unless [value] survives a round trip through [asset]'s precision.
  ///
  /// Guards the *user's own* amount: silently truncating a sub-drop XRP figure
  /// would move money the user did not agree to move.
  static void assertRepresentable(
    TradeDecimal value,
    TradeAsset asset, {
    required String field,
  }) {
    final rounded = roundToAsset(value, asset, roundUp: false);
    if (rounded != value) {
      throw ArgumentError.value(
        value.toString(),
        field,
        asset.isXrp
            ? 'XRP amounts cannot be finer than one drop (6 decimal places)'
            : 'issued amounts cannot exceed '
                  '${TradeAsset.issuedSignificantFigures} significant figures',
      );
    }
  }

  /// Rate implied by an executed pair of amounts, as quote per base.
  ///
  /// Used by the reconciler to record the rate a fill actually got, rather
  /// than the rate that was asked for. Returns null when [baseAmount] is zero,
  /// which is the shape of a metadata row that moved no base at all.
  static TradeDecimal? executedRate({
    required TradeDecimal baseAmount,
    required TradeDecimal quoteAmount,
  }) {
    final base = baseAmount.isNegative ? -baseAmount : baseAmount;
    final quote = quoteAmount.isNegative ? -quoteAmount : quoteAmount;
    if (base.isZero) return null;
    return quote.divide(base, scale: TradeRate.inverseScale, roundUp: false);
  }
}
