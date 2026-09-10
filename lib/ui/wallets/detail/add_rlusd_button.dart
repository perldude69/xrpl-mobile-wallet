import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/ledger_device/ledger_xrp_device.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/swipe_to_sign.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';

/// Adds the official RLUSD trust line for a signing or Ledger wallet.
class AddRlusdButton extends ConsumerStatefulWidget {
  const AddRlusdButton({super.key, required this.account});

  final WalletAccount account;

  @override
  ConsumerState<AddRlusdButton> createState() => _AddRlusdButtonState();
}

class _AddRlusdButtonState extends ConsumerState<AddRlusdButton> {
  final _payments = PaymentService();
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    final network = ref.read(networkControllerProvider).network;
    final issuer = Rlusd.issuerFor(network);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Ripple USD (RLUSD)'),
        content: SingleChildScrollView(
          child: Text(
            'Creates a trust line so this wallet can receive RLUSD on '
            '${network.label}.\n\n'
            'This uses a small XRP owner reserve (about 0.2 XRP) until the '
            'line is removed. Limit ${Rlusd.limit}. NoRipple is set.\n\n'
            'Issuer:\n$issuer',
            style: const TextStyle(height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add trust line'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final pinOk = await promptSwipeToSign(
      context,
      title: 'Confirm trust line',
      message: 'Slide to sign the RLUSD TrustSet.',
    );
    if (!pinOk || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    String? secret;
    try {
      final network = ref.read(networkControllerProvider).network;
      final rpc = ref.read(xrplRpcClientProvider).requireProvider();
      final account = widget.account;

      final PaymentSubmitResult result;
      if (account.useLedger) {
        result = await _submitWithLedger(
          account: account,
          network: network,
          rpc: rpc,
        );
      } else {
        secret = await ref.read(keyVaultProvider).readSecret(account.id);
        if (secret == null || secret.isEmpty) {
          throw StateError('No secret found for this wallet');
        }
        result = await _payments.setRlusdTrustLine(
          secret: secret,
          fromAddress: account.address,
          network: network,
          rpc: rpc,
        );
      }

      if (result.isSuccess) {
        await ref
            .read(walletListControllerProvider.notifier)
            .refreshBalances(walletIds: [account.id]);
        await ref
            .read(activityControllerProvider.notifier)
            .refreshFromNetwork();
      }

      if (!mounted) return;
      final hash = result.hash;
      final short = hash.length > 12 ? '${hash.substring(0, 12)}…' : hash;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? 'RLUSD trust line added ($short)'
                : result.engineResultMessage,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.account.useLedger
                ? LedgerXrpDevice.userFacingError(e)
                : userFacingError(e),
          ),
        ),
      );
    } finally {
      secret = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PaymentSubmitResult> _submitWithLedger({
    required WalletAccount account,
    required NetworkId network,
    required XRPProvider rpc,
  }) async {
    final pathHint = "m/44'/144'/${account.ledgerAccountIndex}'/0/0";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Connect Ledger (USB), open the XRP app ($pathHint), '
          'then approve on the device…',
        ),
        duration: const Duration(seconds: 8),
      ),
    );

    final session = await LedgerXrpDevice.connectUsb();
    try {
      final got = await LedgerXrpDevice.getAddress(
        session,
        accountIndex: account.ledgerAccountIndex,
      );
      if (got.address != account.address) {
        throw StateError(
          'Ledger path $pathHint derives ${got.address}, which does not '
          'match this wallet (${account.address}). Uncheck Ledger Device '
          'or change the account index so the device address matches.',
        );
      }

      Future<String> signTxBlob(List<int> blob) async {
        final der = await LedgerXrpDevice.signTransaction(
          session,
          blob,
          accountIndex: account.ledgerAccountIndex,
        );
        if (!verifyLedgerSignature(
          publicKeyHex: got.publicKeyHex,
          transactionBlob: blob,
          derSignature: der,
        )) {
          throw LedgerDeviceException(
            'Ledger returned an invalid signature.',
            step: 'sign',
          );
        }
        return BytesUtils.toHexString(der, lowerCase: false);
      }

      return await _payments.setRlusdTrustLineWithLedger(
        fromAddress: account.address,
        network: network,
        rpc: rpc,
        publicKeyHex: got.publicKeyHex,
        signTransactionBlob: signTxBlob,
      );
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : _onPressed,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const PirateIcon(glyph: PirateGlyph.doubloon),
      label: const Text('Add RLUSD'),
    );
  }
}
