import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_export.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_dialogs.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_styles.dart';

/// Encrypted public wallet-list export and import.
class BackupSettings extends ConsumerStatefulWidget {
  const BackupSettings({super.key});

  @override
  ConsumerState<BackupSettings> createState() => _BackupSettingsState();
}

class _BackupSettingsState extends ConsumerState<BackupSettings> {
  bool _busy = false;

  Future<void> _exportWallets() async {
    final wallets = ref.read(walletListControllerProvider).wallets;
    if (wallets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No wallets to export')));
      return;
    }

    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const PasswordDialog(
        title: 'Export password',
        message:
            'Encrypts addresses in the export file. You will need this '
            'password to import later. No seeds or keys are included.',
        confirmLabel: 'Export',
        requireConfirm: true,
      ),
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    File? tmp;
    try {
      final doc = await WalletExport.encryptExport(
        wallets: wallets,
        password: password,
      );
      final jsonBody = const JsonEncoder.withIndent('  ').convert(doc);
      final fileName = WalletExport.suggestedFileName();
      final dir = await getTemporaryDirectory();
      final jsonPath = p.join(dir.path, fileName);
      tmp = File(jsonPath);
      await tmp.writeAsString(jsonBody);

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(jsonPath, mimeType: 'application/json', name: fileName),
          ],
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${wallets.length} item(s) as $fileName '
            '(encrypted; no credentials).',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      try {
        if (tmp != null && await tmp.exists()) {
          await tmp.delete();
        }
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importWallets() async {
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => const PasswordDialog(
        title: 'Import password',
        message: 'Enter the password used when this file was exported.',
        confirmLabel: 'Continue',
        requireConfirm: false,
      ),
    );
    if (password == null || !mounted) return;

    setState(() => _busy = true);
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON',
        extensions: <String>['json'],
        mimeTypes: <String>['application/json'],
      );
      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;

      final raw = await file.readAsString();

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw ArgumentError('File is not a valid export document');
      }

      final entries = await WalletExport.decryptExport(
        document: decoded,
        password: password,
      );
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No wallets found in file')),
          );
        }
        return;
      }

      final existing = {
        for (final w in ref.read(walletListControllerProvider).wallets)
          w.address,
      };
      final importer = WalletImporter();
      var added = 0;
      var skipped = 0;
      var failed = 0;

      for (final e in entries) {
        if (existing.contains(e.address)) {
          skipped++;
          continue;
        }
        try {
          final result = importer.importWatchOnly(
            e.address,
            label: e.name,
            network: e.network,
          );
          await ref
              .read(walletListControllerProvider.notifier)
              .addImported(result);
          existing.add(e.address);
          added++;
        } catch (_) {
          failed++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import done: $added added'
            '${skipped > 0 ? ', $skipped already present' : ''}'
            '${failed > 0 ? ', $failed failed' : ''}. '
            'Imported as watch-only (no keys in file).',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletListControllerProvider).wallets;
    final hintStyle = settingsHintStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Export list'),
          subtitle: Text(
            wallets.isEmpty
                ? 'No wallets to export'
                : 'Password-encrypted JSON for ${wallets.length} wallet(s)\n'
                      'Names + addresses only · file name YYYYMMDD_HHMMSS.json',
          ),
          isThreeLine: true,
          enabled: !_busy && wallets.isNotEmpty,
          onTap: (_busy || wallets.isEmpty) ? null : _exportWallets,
        ),
        ListTile(
          leading: const Icon(Icons.file_open_outlined),
          title: const Text('Import list'),
          subtitle: const Text(
            'Load an encrypted export · adds as watch-only\n'
            'Never contains seeds or private keys',
          ),
          isThreeLine: true,
          enabled: !_busy,
          onTap: _busy ? null : _importWallets,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Create / import signing wallets here. Export encrypts names and '
            'addresses with AES-256-GCM (no seeds). Import list decrypts a prior '
            'export and adds missing addresses as watch-only.',
            style: hintStyle,
          ),
        ),
      ],
    );
  }
}
