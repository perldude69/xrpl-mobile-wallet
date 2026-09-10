import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/send/send_screen.dart';
import 'package:xrpl_mobile_wallet/ui/theme/treasure_icon.dart';

/// Opens send, locked to [AppConfig.coffeeAddress], from a signing wallet.
Future<void> openBuyCoffee(BuildContext context, WidgetRef ref) async {
  final signers = ref
      .read(walletListControllerProvider)
      .wallets
      .where((w) => w.canSign && w.address != AppConfig.coffeeAddress)
      .toList();

  if (signers.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add a signing wallet to send a coffee in XRP'),
      ),
    );
    return;
  }

  final WalletAccount? account;
  if (signers.length == 1) {
    account = signers.first;
  } else {
    account = await showModalBottomSheet<WalletAccount>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Send coffee from',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final w in signers)
                ListTile(
                  leading: TreasureAvatar(account: w, radius: 18),
                  title: Text(w.label),
                  subtitle: Text(w.address),
                  onTap: () => Navigator.of(ctx).pop(w),
                ),
            ],
          ),
        );
      },
    );
  }

  if (account == null || !context.mounted) return;
  final from = account;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          SendScreen(account: from, presetDestination: AppConfig.coffeeAddress),
    ),
  );
}
