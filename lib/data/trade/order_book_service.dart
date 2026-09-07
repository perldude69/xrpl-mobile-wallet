// xrpl_dart does not expose its currency constructors from its public barrel.
// ignore: implementation_imports
import 'package:xrpl_dart/src/xrpl/models/currencies/currencies.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';

class OrderBookService {
  OrderBookService(this._client);

  final XrplRpcClient _client;

  Future<BookSnapshot> fetch(TradePair pair, {int limit = 20}) async {
    await _client.fetchValidatedLedgerIndex();
    final asks = await _client
        .fetchBookOffers(
          takerGets: _currency(pair.base),
          takerPays: _currency(pair.quote),
          limit: limit,
        )
        .timeout(const Duration(seconds: 12));
    final bids = await _client
        .fetchBookOffers(
          takerGets: _currency(pair.quote),
          takerPays: _currency(pair.base),
          limit: limit,
        )
        .timeout(const Duration(seconds: 12));
    final asksLedger = asks['ledger_index'] as int?;
    final bidsLedger = bids['ledger_index'] as int?;
    final ledger = asksLedger;
    // Public nodes commonly omit `validated` when the request explicitly
    // targets ledger_index=validated. Reject an explicit false, but accept the
    // omitted flag because the request class defaults to the validated ledger.
    if (asks['validated'] == false ||
        bids['validated'] == false ||
        ledger == null ||
        bidsLedger == null ||
        (bidsLedger - ledger).abs() > 1 ||
        ledger <= 0) {
      throw const FormatException('Order book is not validated.');
    }
    final current = await _client.fetchCurrentLedgerIndex();
    if (current < ledger || current - ledger > 4) {
      throw const FormatException('Order book is stale.');
    }
    return BookSnapshot(
      ledgerIndex: ledger,
      asks: _levels(asks['offers'] as List? ?? const [], TradeSide.sell),
      bids: _levels(bids['offers'] as List? ?? const [], TradeSide.buy),
    );
  }

  BaseCurrency _currency(TradeAsset asset) => asset.isXrp
      ? XRPCurrency()
      : IssuedCurrency(currency: asset.currency, issuer: asset.issuer!);

  List<BookLevel> _levels(List offers, TradeSide side) {
    final result = <BookLevel>[];
    for (final offer in offers) {
      final row = Map<String, dynamic>.from(offer as Map);
      final getsRaw = row['TakerGets'] ?? row['taker_gets'];
      final paysRaw = row['TakerPays'] ?? row['taker_pays'];
      var gets = TradeDecimal.tryParse(
        getsRaw is Map ? getsRaw['value']?.toString() : getsRaw?.toString(),
      );
      var pays = TradeDecimal.tryParse(
        paysRaw is Map ? paysRaw['value']?.toString() : paysRaw?.toString(),
      );
      if (gets == null || pays == null || gets.isZero || pays.isZero) continue;
      // Native XRP is serialized as drops in both book directions. Rates and
      // displayed depth use XRP units, while issued amounts remain decimal.
      if (side == TradeSide.sell) {
        gets = TradeDecimal.fromUnscaled(gets.unscaled, TradeAsset.xrpScale);
      } else {
        pays = TradeDecimal.fromUnscaled(pays.unscaled, TradeAsset.xrpScale);
      }
      final base = side == TradeSide.sell ? gets : pays;
      final quote = side == TradeSide.sell ? pays : gets;
      result.add(
        BookLevel(
          rate: quote.divide(base, scale: 12, roundUp: false),
          baseAmount: base,
          quoteAmount: quote,
        ),
      );
    }
    result.sort(
      (a, b) => side == TradeSide.sell
          ? a.rate.compareTo(b.rate)
          : b.rate.compareTo(a.rate),
    );
    return result;
  }
}
