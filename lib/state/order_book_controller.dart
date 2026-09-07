import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/trade/order_book_service.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';

final orderBookServiceProvider = Provider(
  (ref) => OrderBookService(ref.watch(xrplRpcClientProvider)),
);

/// Emits only when the validated ledger advances. This stays in the UI process
/// so the watcher isolate remains address-only and never owns trade state.
final validatedLedgerStreamProvider = StreamProvider.autoDispose<int>((
  ref,
) async* {
  final client = ref.watch(xrplRpcClientProvider);
  var previous = -1;
  while (true) {
    try {
      final ledger = await client.fetchValidatedLedgerIndex();
      if (ledger != previous) {
        previous = ledger;
        yield ledger;
      }
    } catch (_) {
      // The next interval retries without invalidating a good order book.
    }
    await Future<void>.delayed(const Duration(seconds: 4));
  }
});

final orderBookProvider = FutureProvider.family<BookSnapshot, TradePair>((
  ref,
  pair,
) async {
  ref.listen(validatedLedgerStreamProvider, (_, next) {
    if (next.hasValue) ref.invalidateSelf();
  });
  return ref.watch(orderBookServiceProvider).fetch(pair);
});
