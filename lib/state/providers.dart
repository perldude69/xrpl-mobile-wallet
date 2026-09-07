import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_vault.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_service.dart';
import 'package:xrpl_mobile_wallet/data/watcher/account_watcher.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_reconciler.dart';
import 'package:xrpl_mobile_wallet/state/network_controller.dart';

export 'package:xrpl_mobile_wallet/state/network_controller.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final pinServiceProvider = Provider((ref) => PinService());
final keyVaultProvider = Provider((ref) {
  final vault = KeyVault();
  ref.onDispose(vault.lock);
  return vault;
});

final accountWatcherProvider = Provider<AccountWatcher>(
  (ref) => AccountWatcher(),
);

final paymentReconcilerProvider = Provider<PaymentReconciler>((ref) {
  return PaymentReconciler(
    database: ref.watch(databaseProvider),
    rpc: ref.watch(xrplRpcClientProvider),
    network: ref.watch(networkControllerProvider).network.name,
  );
});

final pendingPaymentsProvider = FutureProvider<List<PendingPayment>>((ref) {
  return ref.watch(databaseProvider).getPendingPayments();
});
