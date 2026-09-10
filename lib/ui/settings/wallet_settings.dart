import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/ui/settings/backup_settings.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/create/create_wallet_screen.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/import/import_screen.dart';

class WalletSettings extends ConsumerWidget {
  const WalletSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ListTile(
        leading: const PirateIcon(glyph: PirateGlyph.dice),
        title: const Text('Create wallet'),
        subtitle: const Text('New recovery phrase'),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateWalletScreen())),
      ),
      ListTile(
        leading: const PirateIcon(glyph: PirateGlyph.map),
        title: const Text('Import wallet'),
        subtitle: const Text('Mnemonic, family seed, or watch-only address'),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ImportScreen())),
      ),
      const Divider(),
      const BackupSettings(),
    ],
  );
}
