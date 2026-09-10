import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/domain/trade/amm_pool.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/ui/trade/book_tape.dart';

class OrderBookPanel extends StatelessWidget {
  const OrderBookPanel({
    super.key,
    required this.snapshot,
    this.amm,
    this.onRefresh,
  });
  final BookSnapshot snapshot;
  final AmmPoolSnapshot? amm;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
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
                    'XRP/RLUSD',
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
            BookTape(snapshot: snapshot, amm: amm),
          ],
        ),
      ),
    );
  }
}
