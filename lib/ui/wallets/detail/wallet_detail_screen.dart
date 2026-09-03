import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/activity/tx_detail_screen.dart';
import 'package:xrpl_mobile_wallet/ui/send/send_screen.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_color.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/attach_keys/attach_keys_chooser_screen.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/receive/receive_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(a.label),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: listState.refreshing
                ? null
                : () => ref
                    .read(walletListControllerProvider.notifier)
                    .refreshBalances(walletIds: [walletId]),
            icon: listState.refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
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
              const PopupMenuItem(value: 'copy', child: Text('Copy address')),
              if (!a.canSign)
                const PopupMenuItem(value: 'add_keys', child: Text('Add keys')),
              const PopupMenuItem(value: 'delete', child: Text('Delete wallet')),
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
                      CircleAvatar(
                        backgroundColor: a.displayColor,
                        child: Text(
                          a.label.isNotEmpty ? a.label[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    a.useLedger
                                        ? 'Ledger'
                                        : a.hasLocalKeys
                                            ? 'Signing'
                                            : 'Watch-only',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    a.useLedger
                                        ? Icons.usb
                                        : a.hasLocalKeys
                                            ? Icons.key
                                            : Icons.visibility,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(a.preferredNetwork.label),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    a.address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Display name'),
            subtitle: Text(a.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editLabel(context, ref, a),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: a.displayColor,
            ),
            title: const Text('Color'),
            subtitle: Text(
              a.accentColorArgb == null
                  ? 'Auto (from address)'
                  : 'Custom',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editColor(context, ref, a),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.usb),
            title: const Text('Ledger Device'),
            subtitle: Text(
              a.useLedger
                  ? 'Send via USB Ledger · path m/44\'/144\'/${a.ledgerAccountIndex}\'/0/0'
                  : 'Enable Send with a connected Ledger (no seed on this phone)',
            ),
            value: a.useLedger,
            onChanged: (v) => _setUseLedger(context, ref, a, v),
          ),
          if (a.useLedger)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Ledger account index'),
              subtitle: Text('${a.ledgerAccountIndex}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editLedgerIndex(context, ref, a),
            ),
          // Actions immediately under the header so watch-only "Add keys" is
          // not buried under a long balances list.
          const SizedBox(height: 16),
          if (!a.canSign) ...[
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
                      'Enable “Ledger Device” above to send with a hardware '
                      'wallet, or add a recovery phrase / family seed that '
                      'matches this address.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _openAttachKeys(context, a),
                      icon: const Icon(Icons.key),
                      label: const Text('Add keys'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (a.useLedger) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.usb),
                title: const Text('Ledger signing'),
                subtitle: Text(
                  'Confirm each payment on the device. Path '
                  "m/44'/144'/${a.ledgerAccountIndex}'/0/0 must match this address.",
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              if (a.canSign)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final sent = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SendScreen(account: a),
                        ),
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
                    icon: const Icon(Icons.send),
                    label: Text(a.useLedger ? 'Send (Ledger)' : 'Send'),
                  ),
                ),
              if (a.canSign) const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceiveScreen(
                          address: a.address,
                          label: a.label,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Receive'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Balances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (balances.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No balance data'),
                subtitle: Text('Pull refresh or wait for network'),
              ),
            )
          else
            ...balances.map(
              (b) {
                final title = CurrencyDisplay.title(
                  b.currency,
                  issuer: b.issuer,
                );
                final symbol = CurrencyDisplay.symbol(
                  b.currency,
                  issuer: b.issuer,
                );
                return Card(
                  child: ListTile(
                    title: Text(title),
                    subtitle: b.issuer == null
                        ? (b.currency == symbol
                            ? null
                            : Text(b.currency, style: const TextStyle(fontSize: 11)))
                        : Text(
                            b.issuer!,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                    trailing: Text(
                      '${b.value} $symbol',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          _RecentActivitySection(walletId: walletId),
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
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
    await ref.read(walletListControllerProvider.notifier).setUseLedger(
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
    final controller =
        TextEditingController(text: '${a.ledgerAccountIndex}');
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
    await ref.read(walletListControllerProvider.notifier).setUseLedger(
          a.id,
          useLedger: true,
          ledgerAccountIndex: idx,
        );
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

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection({required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityControllerProvider);
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
            TextButton(
              onPressed: activity.refreshing
                  ? null
                  : () => ref
                      .read(activityControllerProvider.notifier)
                      .refreshFromNetwork(),
              child: const Text('Refresh'),
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
