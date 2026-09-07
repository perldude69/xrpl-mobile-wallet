import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/trade/order_book_service.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';

final orderBookServiceProvider = Provider(
  (ref) => OrderBookService(ref.watch(xrplRpcClientProvider)),
);

final orderBookProvider = FutureProvider.family<BookSnapshot, TradePair>(
  (ref, pair) => ref.watch(orderBookServiceProvider).fetch(pair),
);
