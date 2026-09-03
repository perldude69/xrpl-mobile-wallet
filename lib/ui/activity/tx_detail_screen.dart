import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';

class TxDetailScreen extends StatelessWidget {
  const TxDetailScreen({super.key, required this.item});

  final ActivityTxItem item;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_Hms();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DirectionHeader(direction: item.direction, type: item.txType),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _DetailTile(
                  label: 'Amount',
                  value: item.amountSummary,
                  valueStyle: theme.textTheme.titleMedium,
                ),
                const Divider(height: 1),
                _DetailTile(label: 'Type', value: item.txType),
                const Divider(height: 1),
                _DetailTile(
                  label: 'Direction',
                  value: _directionLabel(item.direction),
                ),
                const Divider(height: 1),
                _DetailTile(
                  label: 'Date',
                  value: dateFmt.format(item.date.toLocal()),
                ),
                if (item.ledgerIndex != null) ...[
                  const Divider(height: 1),
                  _DetailTile(
                    label: 'Ledger index',
                    value: item.ledgerIndex.toString(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _CopyableTile(label: 'Hash', value: item.hash),
                const Divider(height: 1),
                _DetailTile(label: 'Wallet', value: item.walletLabel),
                if (item.walletAddress.isNotEmpty) ...[
                  const Divider(height: 1),
                  _CopyableTile(
                    label: 'Wallet address',
                    value: item.walletAddress,
                  ),
                ],
                if (item.counterpart != null &&
                    item.counterpart!.isNotEmpty) ...[
                  const Divider(height: 1),
                  _CopyableTile(
                    label: 'Counterpart',
                    value: item.counterpart!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _directionLabel(String direction) {
    return switch (direction) {
      'in' => 'Incoming',
      'out' => 'Outgoing',
      'self' => 'Self',
      _ => 'Other',
    };
  }
}

class _DirectionHeader extends StatelessWidget {
  const _DirectionHeader({required this.direction, required this.type});

  final String direction;
  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (direction) {
      'in' => (Icons.call_received, Colors.greenAccent),
      'out' => (Icons.call_made, Colors.orangeAccent),
      'self' => (Icons.sync_alt, Theme.of(context).colorScheme.primary),
      _ => (Icons.swap_horiz, Theme.of(context).colorScheme.outline),
    };

    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 12),
        Text(type, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: SelectableText(
        value,
        style: valueStyle ??
            Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontFamily: value.length > 20 ? 'monospace' : null,
                ),
      ),
    );
  }
}

class _CopyableTile extends StatelessWidget {
  const _CopyableTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: SelectableText(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
      ),
      trailing: IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy, size: 20),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied')),
            );
          }
        },
      ),
    );
  }
}
