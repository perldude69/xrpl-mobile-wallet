import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/app_exit.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/watcher/account_watcher.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/lock_controller.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/settings/backup_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/buy_coffee.dart';
import 'package:xrpl_mobile_wallet/ui/settings/network_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/security_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_styles.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/create/create_wallet_screen.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/import/import_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _watcherEnabled;
  bool _watcherRunning = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWatcherState();
    });
  }

  Future<void> _refreshWatcherState() async {
    final watcher = ref.read(accountWatcherProvider);
    final enabled = await watcher.isEnabled();
    final running = await watcher.isRunning();
    if (!mounted) return;
    setState(() {
      _watcherEnabled = enabled;
      _watcherRunning = running;
    });
  }

  Future<void> _setWatcherEnabled(bool value) async {
    setState(() => _busy = true);
    try {
      final watcher = ref.read(accountWatcherProvider);
      await watcher.setEnabled(value);
      final wallets = ref.read(walletListControllerProvider).wallets;
      final network = ref.read(networkControllerProvider).network;
      await watcher.syncAddressBook(wallets, network);
      await _refreshWatcherState();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmExitApp() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Close XRPL Mobile Wallet completely.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (ok == true) await exitApplication();
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Wipe all local data?'),
          content: const Text(
            'This permanently deletes wallets, secrets, transaction cache, '
            'and your PIN from this device. You cannot undo this.\n\n'
            'Make sure you have your recovery phrases or family seeds backed up.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Wipe'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
            'All local data will be erased and you will set up a new PIN.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Wipe everything'),
            ),
          ],
        );
      },
    );
    if (doubleConfirmed != true || !mounted) return;

    await _wipeAll();
  }

  Future<void> _wipeAll() async {
    setState(() => _busy = true);
    try {
      final watcher = ref.read(accountWatcherProvider);
      await watcher.wipeLocalState();

      final db = ref.read(databaseProvider);
      await db.wipeAll();

      await ref.read(keyVaultProvider).deleteAllSecrets();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.biometricsEnabled);

      await ref.read(walletListControllerProvider.notifier).reload();
      await ref.read(activityControllerProvider.notifier).loadFromCache();

      ref.read(lockControllerProvider.notifier).resetToNeedsSetup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wipe failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletListControllerProvider).wallets;
    final enabled = _watcherEnabled ?? true;
    final theme = Theme.of(context);
    final hintStyle = settingsHintStyle(context);
    final sectionStyle = settingsSectionStyle(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        NetworkSettings(onNetworkChanged: _refreshWatcherState),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Watcher', style: sectionStyle),
        ),
        SwitchListTile(
          title: const Text('Background watcher'),
          subtitle: Text(
            enabled
                ? (_watcherRunning
                    ? 'Running · ${wallets.length} account(s)'
                    : wallets.isEmpty
                        ? 'Enabled · add a wallet to start'
                        : 'Enabled · starting…')
                : 'Disabled',
          ),
          value: enabled,
          onChanged: _busy ? null : _setWatcherEnabled,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Watches public addresses only (no private keys in the service). '
            'Uses an Android foreground notification while connected.\n\n'
            'Tip: disable battery optimization for this app if the watcher '
            'stops after the app is swiped away.',
            style: hintStyle,
          ),
        ),
        if (!AccountWatcher.isSupportedPlatform)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Foreground watcher runs on Android/iOS only. '
              'Desktop builds keep the address book in sync but do not start a service.',
              style: hintStyle,
            ),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Wallets', style: sectionStyle),
        ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Create wallet'),
          subtitle: const Text(
            'New 24-word BIP39 recovery phrase · write it down offline',
          ),
          enabled: !_busy,
          onTap: _busy
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateWalletScreen(),
                    ),
                  );
                },
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Import wallet'),
          subtitle: const Text(
            'Mnemonic, family seed, or watch-only classic address',
          ),
          enabled: !_busy,
          onTap: _busy
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportScreen()),
                  );
                },
        ),
        const BackupSettings(),
        const Divider(),
        const SecuritySettings(),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Danger zone', style: sectionStyle),
        ),
        ListTile(
          leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
          title: Text(
            'Wipe all local data',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: const Text(
            'Deletes wallets, secrets, cache, and PIN from this device',
          ),
          enabled: !_busy,
          onTap: _busy ? null : _confirmWipe,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('About', style: sectionStyle),
        ),
        ListTile(
          title: const Text('XRPL Mobile Wallet'),
          subtitle: const Text(
            'Android wallet manager for the XRP Ledger\n'
            'Version 1.0.0 · Create or import BIP39 wallets',
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: 'Buy the developer a coffee',
            icon: const Icon(Icons.coffee),
            onPressed: _busy ? null : () => openBuyCoffee(context, ref),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('App', style: sectionStyle),
        ),
        ListTile(
          leading: const Icon(Icons.power_settings_new),
          title: const Text('Exit app'),
          subtitle: const Text('Close XRPL Mobile Wallet completely'),
          enabled: !_busy,
          onTap: _busy ? null : _confirmExitApp,
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
