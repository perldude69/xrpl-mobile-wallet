import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';

/// Resolves pending payment submissions without ever retrying them.
class PaymentReconciler {
  const PaymentReconciler({
    required this.database,
    required this.rpc,
    required this.network,
  });

  final AppDatabase database;
  final XrplRpcClient rpc;
  final String network;

  Future<void> reconcileAll() async {
    final pending = await database.getPendingPayments();
    if (pending.isEmpty) return;

    final validatedLedger = await rpc.fetchValidatedLedgerIndex();
    for (final row in pending) {
      if (row.network != network) continue;
      final detail = await rpc.fetchTransaction(row.txHash);
      if (detail?.validated == true) {
        final success = detail!.transactionResult == 'tesSUCCESS';
        await database.updatePendingPayment(
          row.id,
          status: success ? 'validated' : 'failed',
          lastError: success ? null : detail.transactionResult,
        );
        continue;
      }

      final expiry = row.lastLedgerSequence;
      if (expiry != null && validatedLedger > expiry) {
        await database.updatePendingPayment(
          row.id,
          status: 'expired',
          lastError: 'last ledger sequence passed without validation',
        );
      }
    }
  }
}
