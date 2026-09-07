import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/state/lock_controller.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_dialogs.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_styles.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';

/// PIN and game PIN settings.
class SecuritySettings extends ConsumerStatefulWidget {
  const SecuritySettings({super.key});

  @override
  ConsumerState<SecuritySettings> createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends ConsumerState<SecuritySettings> {
  bool _busy = false;
  bool _hasGamePin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGamePinFlag();
    });
  }

  Future<void> _loadGamePinFlag() async {
    final has = await ref.read(lockControllerProvider.notifier).hasGamePin();
    if (!mounted) return;
    setState(() => _hasGamePin = has);
  }

  Future<void> _changePin() async {
    final result = await showDialog<ChangePinResult>(
      context: context,
      builder: (ctx) => const ChangePinDialog(),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(lockControllerProvider.notifier)
          .changePin(currentPin: result.current, newPin: result.next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'PIN updated' : 'Current PIN is incorrect'),
        ),
      );
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to change PIN: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageGamePin() async {
    if (_hasGamePin) {
      final action = await showDialog<GamePinAction>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Game PIN'),
          content: const Text(
            'A second PIN that opens Zerpland instead of the wallet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(GamePinAction.clear),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(GamePinAction.change),
              child: const Text('Change'),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == GamePinAction.clear) {
        await _clearGamePin();
      } else {
        await _setOrChangeGamePin(changing: true);
      }
    } else {
      await _setOrChangeGamePin(changing: false);
    }
  }

  Future<void> _setOrChangeGamePin({required bool changing}) async {
    final result = await showDialog<GamePinDialogResult>(
      context: context,
      builder: (ctx) => GamePinDialog(
        title: changing ? 'Change game PIN' : 'Set game PIN',
        confirmLabel: changing ? 'Update' : 'Set',
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(lockControllerProvider.notifier)
          .setGamePin(walletPin: result.walletPin, gamePin: result.gamePin);
      if (!mounted) return;
      if (ok) {
        setState(() => _hasGamePin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changing ? 'Game PIN updated' : 'Game PIN set'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet PIN is incorrect')),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to set game PIN: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearGamePin() async {
    final walletPin = await showDialog<String>(
      context: context,
      builder: (ctx) => const ConfirmWalletPinDialog(
        title: 'Clear game PIN',
        message:
            'Enter your wallet PIN to remove the game PIN. '
            'After clearing, three wrong unlock attempts will open Zerpland again.',
        confirmLabel: 'Clear game PIN',
      ),
    );
    if (walletPin == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(lockControllerProvider.notifier)
          .clearGamePin(walletPin: walletPin);
      if (!mounted) return;
      if (ok) {
        setState(() => _hasGamePin = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Game PIN cleared')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet PIN is incorrect')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to clear game PIN: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionStyle = settingsSectionStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Security', style: sectionStyle),
        ),
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: const Text('Change PIN'),
          subtitle: const Text('Require current PIN, then set a new one'),
          enabled: !_busy,
          onTap: _busy ? null : _changePin,
        ),
        ListTile(
          leading: const Icon(Icons.sports_esports_outlined),
          title: const Text('Game PIN'),
          subtitle: Text(
            _hasGamePin
                ? 'Configured · opens Zerpland'
                : 'A second PIN that opens Zerpland instead of the wallet',
          ),
          enabled: !_busy,
          onTap: _busy ? null : _manageGamePin,
        ),
      ],
    );
  }
}
