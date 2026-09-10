import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/config/app_exit.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/lock_controller.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/settings/buy_coffee.dart';
import 'package:xrpl_mobile_wallet/ui/settings/network_settings.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/confirm_wallet_pin.dart';
import 'package:xrpl_mobile_wallet/ui/settings/security_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/escrow_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/monitoring_settings.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_category_screen.dart';
import 'package:xrpl_mobile_wallet/ui/settings/wallet_settings.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWatcherState();
    });
  }

  Future<void> _refreshWatcherState() async {
    await ref.read(walletListControllerProvider.notifier).reload();
    if (!mounted) return;
  }

  Future<void> _confirmExitApp() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Close Zerp Wallet completely.'),
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

    final pinOk = await promptAndVerifyWalletPin(
      context,
      ref,
      title: 'Confirm wipe',
      message: 'Enter your wallet PIN to erase all local data on this device.',
      confirmLabel: 'Wipe',
    );
    if (!pinOk || !mounted) return;

    await _wipeAll();
  }

  Future<void> _wipeAll() async {
    try {
      await ref.read(accountWatcherProvider).wipeLocalState();

      final db = ref.read(databaseProvider);
      await db.wipeAll();

      await ref.read(keyVaultProvider).deleteAllSecrets();
      await ref.read(pinServiceProvider).wipePins();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await ref.read(walletListControllerProvider.notifier).reload();
      await ref.read(activityControllerProvider.notifier).loadFromCache();

      ref.read(lockControllerProvider.notifier).resetToNeedsSetup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Wipe failed: $e')));
      }
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _category(
          context,
          PirateGlyph.spyglass,
          'Network',
          'RPC and WSS priority',
          SettingsCategoryScreen(
            title: 'Network',
            child: NetworkSettings(onNetworkChanged: _refreshWatcherState),
          ),
        ),
        _category(
          context,
          PirateGlyph.captain,
          'Wallet',
          'Create, import, and backup wallets',
          const SettingsCategoryScreen(
            title: 'Wallet',
            child: WalletSettings(),
          ),
        ),
        _category(
          context,
          PirateGlyph.sword,
          'Security',
          'PIN, biometrics, and auto-lock',
          const SettingsCategoryScreen(
            title: 'Security',
            child: SecuritySettings(),
          ),
        ),
        _category(
          context,
          PirateGlyph.cannon,
          'Monitoring',
          'Background watcher and notifications',
          const SettingsCategoryScreen(
            title: 'Monitoring',
            child: MonitoringSettings(),
          ),
        ),
        _category(
          context,
          PirateGlyph.shovel,
          'Escrow',
          'View and finish escrow payments',
          const SettingsCategoryScreen(
            title: 'Escrow',
            child: EscrowSettings(),
          ),
        ),
        _category(
          context,
          PirateGlyph.parrot,
          'About',
          'Version, support, and app information',
          _aboutScreen(context),
        ),
        ListTile(
          leading: const PirateIcon(glyph: PirateGlyph.plank),
          title: const Text('Exit'),
          subtitle: const Text('Close Zerp Wallet completely'),
          onTap: _confirmExitApp,
        ),
        ListTile(
          leading: PirateIcon(
            glyph: PirateGlyph.skull,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Wipe all local data',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: const Text('Danger zone · deletes wallets and secrets'),
          onTap: _confirmWipe,
        ),
      ],
    );
  }

  Widget _category(
    BuildContext context,
    PirateGlyph glyph,
    String title,
    String subtitle,
    Widget screen,
  ) => ListTile(
    leading: PirateIcon(glyph: glyph),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
  );

  Widget _aboutScreen(BuildContext context) => SettingsCategoryScreen(
    title: 'About',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const PirateIcon(glyph: PirateGlyph.parrot),
          title: const Text('Zerp Wallet'),
          subtitle: Text(
            'Version ${AppConfig.appVersionName}\nAndroid wallet for the XRP Ledger',
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: const PirateIcon(glyph: PirateGlyph.grog),
            onPressed: () => openBuyCoffee(context, ref),
          ),
        ),
      ],
    ),
  );
}
