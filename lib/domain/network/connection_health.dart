/// Aggregate RPC + WSS health for the compact status chip.
enum TrafficLight {
  /// Both pipes healthy (or watcher N/A and RPC up).
  green,

  /// Exactly one of RPC/WSS unhealthy, or connecting.
  yellow,

  /// No usable connection.
  red,
}

/// Inputs for [ConnectionHealth.evaluate]. Pure / testable.
class ConnectionHealthInput {
  const ConnectionHealthInput({
    required this.rpcConnected,
    required this.rpcConnecting,
    required this.watcherEnabled,
    required this.wssConnected,
    this.wssConnecting = false,
  });

  /// HTTP JSON-RPC is up.
  final bool rpcConnected;

  /// RPC is in connecting state (not yet up).
  final bool rpcConnecting;

  /// Background watcher enabled by user.
  final bool watcherEnabled;

  /// WSS subscribe currently connected (only meaningful if [watcherEnabled]).
  final bool wssConnected;

  /// WSS is trying to connect / reconnect.
  final bool wssConnecting;
}

class ConnectionHealth {
  const ConnectionHealth({
    required this.light,
    required this.shortLabel,
  });

  final TrafficLight light;

  /// Chip text after network name, e.g. `Live`, `Partial`, `Offline`.
  final String shortLabel;

  /// Compute traffic light from RPC + watcher state.
  ///
  /// When watcher is **disabled**, status is RPC-only (green/red) so “WSS off”
  /// does not permanently yellow the chip.
  static ConnectionHealth evaluate(ConnectionHealthInput i) {
    if (!i.watcherEnabled) {
      if (i.rpcConnecting) {
        return const ConnectionHealth(
          light: TrafficLight.yellow,
          shortLabel: 'Connecting',
        );
      }
      if (i.rpcConnected) {
        return const ConnectionHealth(
          light: TrafficLight.green,
          shortLabel: 'Live',
        );
      }
      return const ConnectionHealth(
        light: TrafficLight.red,
        shortLabel: 'Offline',
      );
    }

    final rpcOk = i.rpcConnected;
    final wssOk = i.wssConnected;
    final busy = i.rpcConnecting || i.wssConnecting;

    if (rpcOk && wssOk) {
      return const ConnectionHealth(
        light: TrafficLight.green,
        shortLabel: 'Live',
      );
    }
    if (!rpcOk && !wssOk && !busy) {
      return const ConnectionHealth(
        light: TrafficLight.red,
        shortLabel: 'Offline',
      );
    }
    // Partial, or any side still connecting.
    if (busy && !rpcOk && !wssOk) {
      return const ConnectionHealth(
        light: TrafficLight.yellow,
        shortLabel: 'Connecting',
      );
    }
    return const ConnectionHealth(
      light: TrafficLight.yellow,
      shortLabel: 'Partial',
    );
  }
}
