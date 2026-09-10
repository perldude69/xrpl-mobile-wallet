import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/activity/tx_detail_screen.dart';
import 'package:xrpl_mobile_wallet/ui/send/send_screen.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_color.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/attach_keys/attach_keys_chooser_screen.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/confirm_wallet_pin.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/theme/treasure_icon.dart';
import 'package:xrpl_mobile_wallet/domain/amount/fiat_format.dart';
import 'package:xrpl_mobile_wallet/state/price_feed_controller.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/detail/add_rlusd_button.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/detail/wallet_action_tile.dart';
import 'package:xrpl_mobile_wallet/data/payments/escrow_service.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/ui/settings/escrow_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_category_screen.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/detail/create_escrow_screen.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/receive/receive_screen.dart';
import 'package:xrpl_mobile_wallet/ui/trade/trade_dashboard_screen.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/testnet_faucet_service.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletDetailScreen extends ConsumerWidget {
  const WalletDetailScreen({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(walletListControllerProvider);
    WalletAccount? account;
    for (final w in listState.wallets) {
      if (w.id == walletId) {
        account = w;
        break;
      }
    }

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: const Center(child: Text('Wallet not found')),
      );
    }

    final balances = listState.balances[walletId] ?? const <LedgerBalance>[];
    final a = account;
    final network = ref.watch(networkControllerProvider).network;
    final showAddRlusd = Rlusd.shouldShowAdd(
      canSign: a.canSign,
      network: network,
      lines: balances.map((b) => (currency: b.currency, issuer: b.issuer)),
    );
    final price = ref.watch(priceFeedControllerProvider);
    final xrp = listState.xrpBalance(walletId);
    final usd = FiatFormat.xrpToUsd(xrp, price.usdPerXrp);

    return Scaffold(
      appBar: AppBar(
        title: Text(a.label, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Copy address',
            onPressed: () => _copyAddress(context, a.address),
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: listState.refreshing
                ? null
                : () async {
                    await ref
                        .read(walletListControllerProvider.notifier)
                        .refreshBalances(walletIds: [walletId]);
                    await ref
                        .read(activityControllerProvider.notifier)
                        .refreshFromNetwork();
                  },
            icon: listState.refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const PirateIcon(glyph: PirateGlyph.helm),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'rename') {
                await _editLabel(context, ref, a);
              } else if (value == 'color') {
                await _editColor(context, ref, a);
              } else if (value == 'ledger') {
                await _setUseLedger(context, ref, a, !a.useLedger);
              } else if (value == 'ledger_index') {
                await _editLedgerIndex(context, ref, a);
              } else if (value == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete wallet?'),
                    content: Text(
                      'Remove "${a.label}" from this device?\n\n'
                      'The secret (if any) will be erased from secure storage. '
                      'This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  final pinOk = await promptAndVerifyWalletPin(
                    context,
                    ref,
                    title: 'Delete wallet',
                    message:
                        'Enter your wallet PIN to erase this wallet and its '
                        'secret from this device.',
                    confirmLabel: 'Delete',
                  );
                  if (!pinOk || !context.mounted) return;
                  await ref
                      .read(walletListControllerProvider.notifier)
                      .deleteWallet(walletId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              } else if (value == 'copy') {
                await Clipboard.setData(ClipboardData(text: a.address));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                }
              } else if (value == 'add_keys') {
                await _openAttachKeys(context, a);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Display name')),
              const PopupMenuItem(value: 'color', child: Text('Color')),
              PopupMenuItem(
                value: 'ledger',
                child: Text(
                  a.useLedger ? 'Disable Ledger Device' : 'Ledger Device',
                ),
              ),
              if (a.useLedger)
                const PopupMenuItem(
                  value: 'ledger_index',
                  child: Text('Ledger account index'),
                ),
              const PopupMenuItem(value: 'copy', child: Text('Copy address')),
              if (!a.canSign)
                const PopupMenuItem(value: 'add_keys', child: Text('Add keys')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete wallet'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TreasureAvatar(account: a, radius: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              xrp ?? '—',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                            Text(
                              price.displayFiat && usd != null
                                  ? 'XRP · ${FiatFormat.formatUsd(usd)}'
                                  : 'XRP',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: PirateIcon(
                          glyph: a.useLedger
                              ? PirateGlyph.compass
                              : a.hasLocalKeys
                              ? PirateGlyph.key
                              : PirateGlyph.spyglass,
                          size: 16,
                        ),
                        label: Text(
                          a.useLedger
                              ? 'Ledger'
                              : a.hasLocalKeys
                              ? 'Signing'
                              : 'Watch-only',
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(a.preferredNetwork.label),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _copyAddress(context, a.address),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                        const Icon(Icons.copy, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!a.canSign) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Watch-only — no keys on this device',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use Ledger Device in the menu to send with a hardware '
                      'wallet, or add a recovery phrase / family seed that '
                      'matches this address.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _openAttachKeys(context, a),
                      icon: const PirateIcon(glyph: PirateGlyph.key),
                      label: const Text('Add keys'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (a.useLedger) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const PirateIcon(glyph: PirateGlyph.compass),
                title: const Text('Ledger signing'),
                subtitle: Text(
                  'Confirm each payment on the device. Path '
                  "m/44'/144'/${a.ledgerAccountIndex}'/0/0 must match this address.",
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              WalletActionTile(
                glyph: PirateGlyph.bottle,
                label: 'Send',
                enabled: a.canSign,
                tooltip: a.useLedger ? 'Confirm on Ledger' : null,
                onPressed: () async {
                  final sent = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => SendScreen(account: a)),
                  );
                  if (sent == true && context.mounted) {
                    await ref
                        .read(walletListControllerProvider.notifier)
                        .refreshBalances(walletIds: [walletId]);
                    await ref
                        .read(activityControllerProvider.notifier)
                        .refreshFromNetwork();
                  }
                },
              ),
              WalletActionTile(
                glyph: PirateGlyph.chest,
                label: 'Receive',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReceiveScreen(address: a.address, label: a.label),
                    ),
                  );
                },
              ),
              WalletActionTile(
                glyph: PirateGlyph.crossedSwords,
                label: 'Trade',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TradeDashboardScreen(account: a),
                  ),
                ),
              ),
              WalletActionTile(
                glyph: PirateGlyph.shovel,
                label: 'Escrow',
                enabled: a.canSign,
                onPressed: () async {
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => CreateEscrowScreen(account: a),
                    ),
                  );
                  if (created == true && context.mounted) {
                    await ref
                        .read(walletListControllerProvider.notifier)
                        .refreshBalances(walletIds: [walletId]);
                    await ref
                        .read(activityControllerProvider.notifier)
                        .refreshFromNetwork();
                  }
                },
              ),
            ],
          ),
          if (showAddRlusd) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AddRlusdButton(account: a),
            ),
          ],
          const SizedBox(height: 12),
          _WalletEscrowSummary(key: ValueKey(xrp ?? 'none'), account: a),
          if (network == NetworkId.testnet) ...[
            const SizedBox(height: 12),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Testnet',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ListTile(
                    leading: const PirateIcon(glyph: PirateGlyph.barrel),
                    title: const Text('Fund XRP'),
                    onTap: () async {
                      try {
                        await const TestnetFaucetService().fund(a.address);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Testnet funding requested'),
                          ),
                        );
                        await ref
                            .read(walletListControllerProvider.notifier)
                            .refreshBalances(walletIds: [walletId]);
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Testnet faucet request failed'),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const PirateIcon(glyph: PirateGlyph.doubloon),
                    title: const Text('Official RLUSD faucet'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () async {
                      final opened = await launchUrl(
                        TestnetFaucetService.rlusdFaucetUri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open RLUSD faucet'),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const PirateIcon(glyph: PirateGlyph.spyglass),
                    title: const Text('Bithomp RLUSD faucet'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(
                      TestnetFaucetService.rlusdBithompFaucetUri,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Balances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: balances.isEmpty
                ? const ListTile(
                    title: Text('No balance data'),
                    subtitle: Text('Pull refresh or wait for network'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < balances.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _BalanceRow(balance: balances[i]),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          _RecentActivitySection(walletId: walletId),
        ],
      ),
    );
  }

  static Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Address copied')));
    }
  }

  Future<void> _openAttachKeys(BuildContext context, WalletAccount a) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AttachKeysChooserScreen(
          walletId: a.id,
          address: a.address,
          label: a.label,
        ),
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keys added — this wallet can send')),
      );
    }
  }

  Future<void> _editLabel(
    BuildContext context,
    WidgetRef ref,
    WalletAccount a,
  ) async {
    final controller = TextEditingController(text: a.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(walletListControllerProvider.notifier)
          .updateLabel(a.id, result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _setUseLedger(
    BuildContext context,
    WidgetRef ref,
    WalletAccount a,
    bool enabled,
  ) async {
    if (enabled && a.hasLocalKeys) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use Ledger for this wallet?'),
          content: const Text(
            'This wallet already has keys on the phone. Enabling Ledger means '
            'Send will use the device instead of the local secret. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable Ledger'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await ref
        .read(walletListControllerProvider.notifier)
        .setUseLedger(
          a.id,
          useLedger: enabled,
          ledgerAccountIndex: a.ledgerAccountIndex,
        );
    if (enabled && context.mounted) {
      final idx = a.ledgerAccountIndex;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ledger enabled. Connect USB Ledger + open XRP app when sending. '
            "Path m/44'/144'/$idx'/0/0 must match this address "
            '(change index if needed).',
          ),
        ),
      );
    }
  }

  Future<void> _editLedgerIndex(
    BuildContext context,
    WidgetRef ref,
    WalletAccount a,
  ) async {
    final controller = TextEditingController(text: '${a.ledgerAccountIndex}');
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ledger account index'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Account index (0, 1, 2…)',
            border: OutlineInputBorder(),
            helperText: "Path: m/44'/144'/index'/0/0",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || !context.mounted) return;
    final idx = int.tryParse(raw.trim());
    if (idx == null || idx < 0 || idx > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an index from 0 to 100')),
      );
      return;
    }
    await ref
        .read(walletListControllerProvider.notifier)
        .setUseLedger(a.id, useLedger: true, ledgerAccountIndex: idx);
  }

  Future<void> _editColor(
    BuildContext context,
    WidgetRef ref,
    WalletAccount a,
  ) async {
    final auto = WalletColor.fromAddress(a.address);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Wallet color', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: auto),
                  title: const Text('Auto (from address)'),
                  trailing: a.accentColorArgb == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    await ref
                        .read(walletListControllerProvider.notifier)
                        .updateAccentColor(a.id, null);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in WalletColor.presets)
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(walletListControllerProvider.notifier)
                              .updateAccentColor(a.id, c.toARGB32());
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: CircleAvatar(
                          backgroundColor: c,
                          radius: 18,
                          child: a.accentColorArgb == c.toARGB32()
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance});

  final LedgerBalance balance;

  @override
  Widget build(BuildContext context) {
    final symbol = CurrencyDisplay.symbol(
      balance.currency,
      issuer: balance.issuer,
    );
    final issuer = balance.issuer;
    return ListTile(
      leading: PirateIcon(
        glyph: balance.currency == 'XRP'
            ? PirateGlyph.chest
            : PirateGlyph.doubloon,
      ),
      title: Text(symbol),
      subtitle: issuer == null
          ? null
          : Text(
              issuer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
      trailing: Text(
        balance.value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection({required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activityControllerProvider);
    final recent = ref
        .read(activityControllerProvider.notifier)
        .itemsForWallet(walletId, limit: 5);
    final dateFmt = DateFormat.yMMMd().add_Hm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No transactions yet'),
              subtitle: Text('Tap refresh to load history'),
            ),
          )
        else
          ...recent.map((item) {
            final (icon, color) = switch (item.direction) {
              'in' => (Icons.call_received, Colors.greenAccent),
              'out' => (Icons.call_made, Colors.orangeAccent),
              'self' => (Icons.sync_alt, Theme.of(context).colorScheme.primary),
              _ => (Icons.swap_horiz, Theme.of(context).colorScheme.outline),
            };
            return Card(
              child: ListTile(
                leading: Icon(icon, color: color),
                title: Text(item.amountSummary),
                subtitle: Text(
                  '${dateFmt.format(item.date.toLocal())} · ${item.txType}',
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TxDetailScreen(item: item),
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }
}

class _WalletEscrowSummary extends ConsumerStatefulWidget {
  const _WalletEscrowSummary({super.key, required this.account});
  final WalletAccount account;

  @override
  ConsumerState<_WalletEscrowSummary> createState() =>
      _WalletEscrowSummaryState();
}

class _WalletEscrowSummaryState extends ConsumerState<_WalletEscrowSummary> {
  late Future<List<XrpEscrow>> _future;

  @override
  void initState() {
    super.initState();
    _future = EscrowService(
      ref.read(xrplRpcClientProvider),
    ).listVisible([widget.account.address]).then((c) => c.escrows);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XrpEscrow>>(
      future: _future,
      builder: (context, snapshot) {
        final escrows = snapshot.data;
        if (escrows == null || escrows.isEmpty) {
          return const SizedBox.shrink();
        }
        var drops = BigInt.zero;
        var owned = 0;
        for (final e in escrows) {
          if (e.isXrpAmount) {
            drops += BigInt.tryParse(e.amountDrops) ?? BigInt.zero;
          }
          if (e.owner == widget.account.address) owned++;
        }
        return Card(
          child: ListTile(
            leading: const PirateIcon(glyph: PirateGlyph.shovel),
            title: Text(
              '${XrpAmount.dropsToXrp(drops.toString())} XRP locked in escrow',
            ),
            subtitle: Text(
              owned == escrows.length
                  ? '${escrows.length} open escrow${escrows.length == 1 ? '' : 's'} · extra owner reserve until closed'
                  : '${escrows.length} open escrow${escrows.length == 1 ? '' : 's'} · $owned outgoing',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsCategoryScreen(
                  title: 'Escrow',
                  child: EscrowSettings(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
