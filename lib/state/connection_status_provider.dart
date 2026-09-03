import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/watcher/watcher_status_store.dart';
import 'package:xrpl_mobile_wallet/domain/network/connection_health.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';

/// Combined UI-facing connection snapshot (RPC + watcher WSS).
class ConnectionStatusView {
  const ConnectionStatusView({
    required this.health,
    required this.networkLabel,
    required this.rpcConnected,
    required this.rpcConnecting,
    required this.rpcHost,
    required this.rpcError,
    required this.watcherEnabled,
    required this.wssConnected,
    required this.wssConnecting,
    required this.wssHost,
    required this.wssPhase,
  });

  final ConnectionHealth health;
  final String networkLabel;
  final bool rpcConnected;
  final bool rpcConnecting;
  final String? rpcHost;
  final String? rpcError;
  final bool watcherEnabled;
  final bool wssConnected;
  final bool wssConnecting;
  final String? wssHost;
  final String wssPhase;
}

/// Polls watcher heartbeat + network controller every few seconds.
final connectionStatusProvider =
    StreamProvider.autoDispose<ConnectionStatusView>((ref) async* {
  final store = WatcherStatusStore();

  Future<ConnectionStatusView> sample() async {
    final net = ref.read(networkControllerProvider);
    final bridge = ref.read(accountWatcherProvider);
    final enabled = await bridge.isEnabled();
    final running = await bridge.isRunning();
    final snap = await store.read(enabled: enabled, running: running);

    final rpcConnected = net.connection == NetworkConnectionState.connected;
    final rpcConnecting = net.connection == NetworkConnectionState.connecting;
    // If service not running while enabled, treat WSS as down (not connected).
    final wssConnected = enabled && running && snap.wssConnected;
    final wssConnecting =
        enabled && (snap.wssConnecting || (running && !snap.wssConnected));

    final health = ConnectionHealth.evaluate(
      ConnectionHealthInput(
        rpcConnected: rpcConnected,
        rpcConnecting: rpcConnecting,
        watcherEnabled: enabled,
        wssConnected: wssConnected,
        wssConnecting: wssConnecting,
      ),
    );

    return ConnectionStatusView(
      health: health,
      networkLabel: net.network.label,
      rpcConnected: rpcConnected,
      rpcConnecting: rpcConnecting,
      rpcHost: net.activeNodeHost,
      rpcError: net.errorMessage,
      watcherEnabled: enabled,
      wssConnected: wssConnected,
      wssConnecting: wssConnecting,
      wssHost: snap.host,
      wssPhase: snap.phase,
    );
  }

  yield await sample();
  final timer = Stream.periodic(const Duration(seconds: 3));
  await for (final _ in timer) {
    // Re-read network on each tick (Riverpod ref.read is fine).
    yield await sample();
  }
});
