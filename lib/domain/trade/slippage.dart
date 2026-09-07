import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';

/// A maximum acceptable price move, as a fraction of a reference rate.
///
/// `0.01` is 1%. This is the whole safety mechanism of a market order: an
/// `OfferCreate` always executes at its limit rate or better, so bounding the
/// slippage *is* bounding the worst price the account can get. There is no
/// unbounded market order — an order with no limit is an order that can be
/// filled at any price at all.
class Slippage {
  const Slippage._(this.fraction);

  /// Build from a fraction, e.g. `0.005` for 0.5%.
  factory Slippage.fraction(TradeDecimal value) {
    if (value.isNegative) {
      throw ArgumentError.value(
        value.toString(),
        'fraction',
        'slippage must not be negative',
      );
    }
    if (value > maxFraction) {
      throw ArgumentError.value(
        value.toString(),
        'fraction',
        'slippage must not exceed $maxFraction ($maxPercentLabel%)',
      );
    }
    return Slippage._(value);
  }

  /// Build from a percentage, e.g. `0.5` for 0.5%.
  factory Slippage.percent(String percent) => Slippage.fraction(
    TradeDecimal.parse(
      percent,
    ).divide(_hundred, scale: _percentScale, roundUp: false),
  );

  /// Build from basis points, e.g. `50` for 0.5%.
  factory Slippage.basisPoints(int bps) =>
      Slippage.fraction(TradeDecimal.fromUnscaled(BigInt.from(bps), 4));

  /// Fraction of the reference rate, e.g. `0.005`.
  final TradeDecimal fraction;

  /// Hard ceiling on how much slippage can be accepted: 50%.
  ///
  /// Not a UI preference — a typo that turns 0.5% into 50% is recoverable, one
  /// that turns it into 5000% is a donation to whoever is on the other side.
  static final TradeDecimal maxFraction = TradeDecimal.parse('0.5');
  static const maxPercentLabel = '50';

  static final TradeDecimal _hundred = TradeDecimal.parse('100');
  static const _percentScale = 12;

  bool get isZero => fraction.isZero;

  /// Percentage rendering for review copy, e.g. `0.5`.
  String get percentLabel => (fraction * _hundred).normalized.toString();

  /// Worst rate this bound allows, given a [reference] rate and a [side].
  ///
  /// Selling base, the limit is the **floor** on what you receive
  /// (`reference × (1 − slippage)`); buying base it is the **ceiling** on what
  /// you pay (`reference × (1 + slippage)`).
  ///
  /// Rounded in whichever direction makes the bound *stricter*, so the limit
  /// actually submitted is never looser than the slippage the user agreed to.
  TradeRate limitRate({required TradeRate reference, required TradeSide side}) {
    final sell = side == TradeSide.sell;
    final multiplier = sell
        ? TradeDecimal.one - fraction
        : TradeDecimal.one + fraction;
    final raw = reference.quotePerBase * multiplier;
    final bounded = raw.withScale(
      TradeRate.inverseScale,
      // Selling: the limit is a floor, round it up to stay strict.
      // Buying: the limit is a ceiling, round it down to stay strict.
      roundUp: sell,
    );
    if (!bounded.isPositive) {
      throw ArgumentError.value(
        raw.toString(),
        'reference',
        'slippage bound collapses the limit rate to zero',
      );
    }
    return TradeRate.quotePerBase(bounded);
  }

  @override
  bool operator ==(Object other) =>
      other is Slippage && other.fraction == fraction;

  @override
  int get hashCode => fraction.hashCode;

  @override
  String toString() => '$percentLabel%';
}
