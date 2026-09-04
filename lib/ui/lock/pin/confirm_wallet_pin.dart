import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/state/lock_controller.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_dialogs.dart';

/// Prompt for the wallet PIN and verify it. Returns false on cancel or mismatch.
Future<bool> promptAndVerifyWalletPin(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final pin = await showDialog<String>(
    context: context,
    builder: (ctx) => ConfirmWalletPinDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    ),
  );
  if (pin == null) return false;
  final ok = await ref.read(lockControllerProvider.notifier).verifyWalletPin(pin);
  if (!context.mounted) return false;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet PIN is incorrect')),
    );
  }
  return ok;
}
