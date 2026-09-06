import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'state/lock_controller.dart';
import 'state/providers.dart';
import 'state/wallet_list_controller.dart';
import 'ui/lock/pin/setup_pin_screen.dart';
import 'ui/lock/pin/unlock_screen.dart';
import 'ui/shell/main_shell.dart';

class XrplWalletApp extends StatelessWidget {
  const XrplWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Zerp Wallet',
        theme: buildAppTheme(),
        home: const _AppGate(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class _AppGate extends ConsumerWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(lockControllerProvider);
    return switch (phase) {
      LockPhase.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      LockPhase.needsSetup => const SetupPinScreen(),
      LockPhase.locked => const UnlockScreen(),
      LockPhase.unlocked => const LockLifecycle(child: MainShell()),
    };
  }
}

/// Locks the app after [AppConfig.autoLockSeconds] in the background.
class LockLifecycle extends ConsumerStatefulWidget {
  const LockLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockLifecycle> createState() => _LockLifecycleState();
}

class _LockLifecycleState extends ConsumerState<LockLifecycle>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After unlock, ensure public address book is synced and FGS started if enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final wallets = ref.read(walletListControllerProvider).wallets;
        final network = ref.read(networkControllerProvider).network;
        final watcher = ref.read(accountWatcherProvider);
        await watcher.syncAddressBook(wallets, network);
        await watcher.ensureStartedIfEnabled();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null) {
        final elapsed = DateTime.now().difference(pausedAt).inSeconds;
        if (elapsed >= AppConfig.autoLockSeconds) {
          ref.read(lockControllerProvider.notifier).lock();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
