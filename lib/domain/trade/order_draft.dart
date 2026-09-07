import 'package:xrpl_mobile_wallet/domain/trade/slippage.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';

/// How long an order may live before the ledger gives up on it.
enum TimeInForce {
  /// `tfImmediateOrCancel` — fill whatever crosses now, kill the rest. Nothing
  /// rests on the book, so no owner reserve is taken.
  immediateOrCancel,

  /// `tfFillOrKill` — fill completely at the limit or better, or do nothing.
  fillOrKill,

  /// No flag. Whatever does not cross immediately rests on the book and holds
  /// an owner reserve until it is filled or cancelled.
  resting,
}

/// A fully specified order, before it becomes an `OfferCreate`.
///
/// Sealed so every consumer has to handle both shapes: a market order is
/// bounded by slippage and never rests, a limit order carries an explicit
/// price and does. Pure — building a draft touches no network and signs
/// nothing.
sealed class OrderDraft {
  const OrderDraft({
    required this.pair,
    required this.side,
    required this.baseAmount,
  });

  final TradePair pair;
  final TradeSide side;

  /// Amount of the base asset (XRP), exactly as the user stated it.
  final TradeDecimal baseAmount;

  /// The worst rate this order may execute at, quote per base.
  TradeRate get limitRate;

  TimeInForce get timeInForce;

  /// `tfSell`: give up the whole `TakerGets` even when the rate is better than
  /// the limit, instead of stopping once `TakerPays` is satisfied.
  bool get sellAll;

  /// Optional ledger-side `Expiration`.
  DateTime? get expiration;

  /// Storage form for `trade_executions.order_type`.
  String get orderTypeStorageValue;

  /// The `OfferCreate` taker fields this draft produces.
  ///
  /// Throws [ArgumentError] when the amount is not representable or the order
  /// is too small to express at [limitRate].
  TakerAmounts takerAmounts() => TradeRates.takerAmounts(
    pair: pair,
    side: side,
    baseAmount: baseAmount,
    rate: limitRate,
  );
}

/// Buy or sell now, bounded by slippage against a reference rate.
///
/// IOC by default: the safest retail action, because nothing is left resting
/// and no reserve is taken. The reference rate comes from the order book at
/// review time, so a stale book must be refused before one of these is built.
class MarketOrderDraft extends OrderDraft {
  const MarketOrderDraft({
    required super.pair,
    required super.side,
    required super.baseAmount,
    required this.referenceRate,
    required this.slippage,
    this.timeInForce = TimeInForce.immediateOrCancel,
  }) : assert(
         timeInForce != TimeInForce.resting,
         'a market order must not rest on the book',
       );

  /// Mid or best-quote rate the slippage bound is measured against.
  final TradeRate referenceRate;

  final Slippage slippage;

  @override
  final TimeInForce timeInForce;

  @override
  TradeRate get limitRate =>
      slippage.limitRate(reference: referenceRate, side: side);

  /// Never. A market order that sold past its limit would defeat the bound.
  @override
  bool get sellAll => false;

  /// Never. An IOC/FOK order is resolved in the ledger it is submitted to.
  @override
  DateTime? get expiration => null;

  @override
  String get orderTypeStorageValue => 'market';
}

/// A priced order that rests on the book until filled, cancelled or expired.
///
/// Costs one owner-reserve increment for as long as it rests, and the offered
/// funds stay locked.
class LimitOrderDraft extends OrderDraft {
  const LimitOrderDraft({
    required super.pair,
    required super.side,
    required super.baseAmount,
    required TradeRate rate,
    this.sellAll = false,
    this.expiration,
  }) : _rate = rate;

  final TradeRate _rate;

  @override
  TradeRate get limitRate => _rate;

  @override
  final bool sellAll;

  @override
  final DateTime? expiration;

  @override
  TimeInForce get timeInForce => TimeInForce.resting;

  @override
  String get orderTypeStorageValue => 'limit';
}
