import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';

/// One side of the direct XRP/RLUSD order book.
class BookLevel {
  const BookLevel({
    required this.rate,
    required this.baseAmount,
    required this.quoteAmount,
  });

  final TradeDecimal rate;
  final TradeDecimal baseAmount;
  final TradeDecimal quoteAmount;
}

/// Validated snapshot used for quoting market orders and displaying depth.
class BookSnapshot {
  const BookSnapshot({
    required this.ledgerIndex,
    required this.bids,
    required this.asks,
  });

  final int ledgerIndex;
  final List<BookLevel> bids;
  final List<BookLevel> asks;

  TradeDecimal? get bestBid => bids.isEmpty ? null : bids.first.rate;
  TradeDecimal? get bestAsk => asks.isEmpty ? null : asks.first.rate;
  TradeDecimal? get mid {
    final bid = bestBid;
    final ask = bestAsk;
    if (bid == null || ask == null) return null;
    return (bid + ask).divide(
      TradeDecimal.parse('2'),
      scale: bid.scale > ask.scale ? bid.scale : ask.scale,
      roundUp: false,
    );
  }
}
