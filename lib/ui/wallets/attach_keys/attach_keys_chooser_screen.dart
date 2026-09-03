import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/attach_keys/attach_keys_entry_screen.dart';

/// Chooser: how to enter secrets for upgrading a watch-only wallet.
class AttachKeysChooserScreen extends StatelessWidget {
  const AttachKeysChooserScreen({
    super.key,
    required this.walletId,
    required this.address,
    required this.label,
  });

  final String walletId;
  final String address;
  final String label;

  Future<void> _open(BuildContext context, AttachKeysMode mode) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AttachKeysEntryScreen(
          walletId: walletId,
          address: address,
          label: label,
          mode: mode,
        ),
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add keys')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Add signing keys to “$label”',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            address,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The secret must derive to this address. A mismatch will be rejected '
            'and no new wallet will be created.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          _OptionTile(
            icon: Icons.content_paste,
            title: 'Paste recovery phrase',
            subtitle: '12 or 24 words from clipboard or typed as one phrase',
            onTap: () => _open(context, AttachKeysMode.pasteMnemonic),
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.grid_on,
            title: 'Enter phrase (grid)',
            subtitle: '24 numbered fields · 8×3 with BIP39 autocomplete',
            onTap: () => _open(context, AttachKeysMode.gridMnemonic),
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.key,
            title: 'Family seed',
            subtitle: 'Classic XRPL seed starting with s…',
            onTap: () => _open(context, AttachKeysMode.familySeed),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
