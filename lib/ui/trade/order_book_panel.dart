import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';

class OrderBookPanel extends StatelessWidget {
  const OrderBookPanel({super.key, required this.snapshot, this.onRefresh});
  final BookSnapshot snapshot;
  final VoidCallback? onRefresh;

  String _value(Object? value) => value?.toString() ?? 'Unavailable';

  @override
  Widget build(BuildContext context) {
    final spread = snapshot.bestBid != null && snapshot.bestAsk != null
        ? snapshot.bestAsk! - snapshot.bestBid!
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'XRP/RLUSD order book',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh order book',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Best bid  ${_value(snapshot.bestBid)}'),
            Text('Best ask  ${_value(snapshot.bestAsk)}'),
            Text('Spread    ${_value(spread)}'),
            Text('Mid       ${_value(snapshot.mid)}'),
            Text('Ledger    ${snapshot.ledgerIndex}'),
            Text(
              'Depth     ${snapshot.bids.length} bids / ${snapshot.asks.length} asks',
            ),
          ],
        ),
      ),
    );
  }
}
