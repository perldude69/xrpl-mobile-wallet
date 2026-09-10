import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';

/// Validated XRP/RLUSD AMM reserves. Display and estimates only — not a quote
/// that may be submitted. `OfferCreate` still lets the ledger mix book + AMM.
class AmmPoolSnapshot {
  const AmmPoolSnapshot({
    required this.account,
    required this.xrpReserve,
    required this.rlusdReserve,
    required this.tradingFee,
    required this.ledgerIndex,
    this.quoteFrozen = false,
  });

  final String account;
  final TradeDecimal xrpReserve;
  final TradeDecimal rlusdReserve;

  /// Protocol `TradingFee`: 0–1000, where 1000 = 1%.
  final int tradingFee;
  final int ledgerIndex;
  final bool quoteFrozen;

  /// RLUSD per XRP from reserves (constant-product spot).
  TradeDecimal get spot => rlusdReserve.divide(
    xrpReserve,
    scale: TradeAsset.issuedWorkingScale,
    roundUp: false,
  );

  /// Human fee, e.g. `0.501%` for [tradingFee] 501.
  String get feePercentLabel {
    final pct = TradeDecimal.fromUnscaled(
      BigInt.from(tradingFee),
      3,
    ).normalized;
    return '$pct%';
  }

  /// True when [spot] is strictly inside (bestBid, bestAsk).
  bool spotInsideSpread({
    required TradeDecimal? bestBid,
    required TradeDecimal? bestAsk,
  }) {
    final bid = bestBid;
    final ask = bestAsk;
    if (bid == null || ask == null) return false;
    return spot > bid && spot < ask;
  }

  /// Inbound XRP, outbound RLUSD if the swap were AMM-only (fee on inbound).
  TradeDecimal quoteOutForXrpIn(TradeDecimal xrpIn) {
    return _swapOut(
      reserveIn: xrpReserve,
      reserveOut: rlusdReserve,
      amountIn: xrpIn,
    );
  }

  /// Inbound RLUSD, outbound XRP if the swap were AMM-only.
  TradeDecimal xrpOutForRlusdIn(TradeDecimal rlusdIn) {
    return _swapOut(
      reserveIn: rlusdReserve,
      reserveOut: xrpReserve,
      amountIn: rlusdIn,
    );
  }

  TradeDecimal _swapOut({
    required TradeDecimal reserveIn,
    required TradeDecimal reserveOut,
    required TradeDecimal amountIn,
  }) {
    if (!amountIn.isPositive || reserveIn.isZero) {
      return TradeDecimal.zero;
    }
    final ein =
        (amountIn *
                TradeDecimal.fromUnscaled(BigInt.from(100000 - tradingFee), 0))
            .divide(
              TradeDecimal.fromUnscaled(BigInt.from(100000), 0),
              scale: TradeAsset.issuedWorkingScale,
              roundUp: false,
            );
    final denom = reserveIn + ein;
    if (denom.isZero) return TradeDecimal.zero;
    return (reserveOut * ein).divide(
      denom,
      scale: TradeAsset.issuedWorkingScale,
      roundUp: false,
    );
  }
}
