import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';

class MonitoringSettings extends ConsumerStatefulWidget {
  const MonitoringSettings({super.key});

  @override
  ConsumerState<MonitoringSettings> createState() => _MonitoringSettingsState();
}

class _MonitoringSettingsState extends ConsumerState<MonitoringSettings> {
  bool? _enabled;
  bool _running = false;
  bool _hideAmounts = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await ref.read(walletListControllerProvider.notifier).reload();
    final watcher = ref.read(accountWatcherProvider);
    final enabled = await watcher.isEnabled();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hideAmounts =
          prefs.getBool('watcher_hide_notification_amounts') ?? false;
    });
    final running = await watcher.isRunning();
    if (mounted) setState(() => _running = running);
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _busy = true);
    try {
      final watcher = ref.read(accountWatcherProvider);
      await watcher.setEnabled(value);
      await watcher.syncAddressBook(
        ref.read(walletListControllerProvider).wallets,
        ref.read(networkControllerProvider).network,
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setHideAmounts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('watcher_hide_notification_amounts', value);
    if (mounted) setState(() => _hideAmounts = value);
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletListControllerProvider).wallets;
    final enabled = _enabled ?? true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Background watcher'),
          subtitle: Text(
            enabled
                ? (_running
                      ? 'Running · ${wallets.length} account(s)'
                      : 'Starting…')
                : 'Disabled',
          ),
          value: enabled,
          onChanged: _busy ? null : _setEnabled,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hide notification amounts'),
          subtitle: const Text('Hide transaction amounts on the lock screen.'),
          value: _hideAmounts,
          onChanged: _setHideAmounts,
        ),
        const SizedBox(height: 12),
        const Text(
          'Monitoring watches public addresses only. Private keys never enter the watcher service.',
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
