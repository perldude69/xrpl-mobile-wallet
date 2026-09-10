import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/secure/screen_security.dart';
import 'package:xrpl_mobile_wallet/state/lock_controller.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/pin_text_field.dart';
import 'package:xrpl_mobile_wallet/ui/lock/runner/zerpland_runner_screen.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_marks.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _busy = false;

  /// Whether a game PIN is configured (disables 3-fail decoy).
  bool? _hasGamePin;

  /// Wrong PIN attempts this session; 3rd failure opens Zerpland
  /// only when no game PIN is set.
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGamePinFlag();
    });
  }

  Future<void> _loadGamePinFlag() async {
    final has = await ref.read(lockControllerProvider.notifier).hasGamePin();
    if (!mounted) return;
    setState(() => _hasGamePin = has);
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    _pinController.clear();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _openGame() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ZerplandRunnerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text;
    if (pin.isEmpty) {
      setState(() => _error = 'Enter your PIN');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    final outcome = await ref
        .read(lockControllerProvider.notifier)
        .unlockWithPin(pin);
    if (!mounted) return;

    switch (outcome) {
      case UnlockOutcome.wallet:
        _failedAttempts = 0;
        // Gate switches to MainShell; no local setState needed.
        return;
      case UnlockOutcome.game:
        _failedAttempts = 0;
        _pinController.clear();
        setState(() {
          _error = null;
          _busy = false;
        });
        await _openGame();
        if (!mounted) return;
        // Silent return — no mention of PIN/wallet (decoy game cover).
        setState(() {
          _error = null;
          _busy = false;
        });
        return;
      case UnlockOutcome.failed:
        break;
    }

    _failedAttempts++;
    _pinController.clear();

    // 3-fail decoy only when no dedicated game PIN is configured.
    final useFailDecoy = _hasGamePin != true;
    if (useFailDecoy && _failedAttempts >= 3) {
      _failedAttempts = 0;
      setState(() {
        _error = null;
        _busy = false;
      });
      await _openGame();
      if (!mounted) return;
      setState(() {
        _error = null;
        _busy = false;
      });
      return;
    }

    // Don't telegraph remaining tries (helps the decoy feel natural).
    setState(() {
      _error = 'Incorrect PIN';
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: JollyRogerMark(size: 36),
        ),
        leadingWidth: 48,
        title: const Text('Unlock'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: PirateMascot(size: 112)),
              const SizedBox(height: 16),
              Text(
                'Enter your PIN to unlock',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              PinTextField(
                controller: _pinController,
                label: 'PIN',
                enabled: !_busy,
                onSubmitted: (_) => _unlockWithPin(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _unlockWithPin,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
