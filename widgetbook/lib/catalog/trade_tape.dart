import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:xrpl_mobile_wallet/domain/trade/amm_pool.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/ui/trade/order_book_panel.dart';

WidgetbookUseCase tradeTapeUseCase() {
  return WidgetbookUseCase(
    name: 'Order book tape',
    builder: (context) {
      final bid = context.knobs.string(label: 'Bid', initialValue: '1.4200');
      final ask = context.knobs.string(label: 'Ask', initialValue: '1.4280');
      final showAmm = context.knobs.boolean(
        label: 'Show AMM',
        initialValue: true,
      );
      final ammSpot = context.knobs.string(
        label: 'AMM spot',
        initialValue: '1.424',
      );
      BookSnapshot snapshot;
      try {
        snapshot = BookSnapshot(
          ledgerIndex: 106861391,
          bids: [
            BookLevel(
              rate: TradeDecimal.parse(bid),
              baseAmount: TradeDecimal.parse('1000'),
              quoteAmount: TradeDecimal.parse('1420'),
            ),
          ],
          asks: [
            BookLevel(
              rate: TradeDecimal.parse(ask),
              baseAmount: TradeDecimal.parse('800'),
              quoteAmount: TradeDecimal.parse('1142'),
            ),
          ],
        );
      } catch (_) {
        return const Center(child: Text('Invalid bid/ask decimal'));
      }
      AmmPoolSnapshot? amm;
      if (showAmm) {
        try {
          final spot = TradeDecimal.parse(ammSpot);
          amm = AmmPoolSnapshot(
            account: 'rhWTXC2m2gGGA9WozUaoMm6kLAVPb1tcS3',
            xrpReserve: TradeDecimal.parse('1000'),
            rlusdReserve: spot * TradeDecimal.parse('1000'),
            tradingFee: 205,
            ledgerIndex: 106861391,
          );
        } catch (_) {
          amm = null;
        }
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [OrderBookPanel(snapshot: snapshot, amm: amm)],
      );
    },
  );
}
