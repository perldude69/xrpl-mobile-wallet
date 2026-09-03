import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';

/// Snapshot of background WSS watcher health for the UI process.
class WatcherStatusSnapshot {
  const WatcherStatusSnapshot({
    required this.enabled,
    required this.running,
    required this.phase,
    this.host,
    this.updatedAt,
  });

  final bool enabled;
  final bool running;

  /// `idle` | `connecting` | `connected` | `reconnecting` | `stopped`
  final String phase;
  final String? host;
  final DateTime? updatedAt;

  bool get wssConnected => phase == 'connected' && running;

  bool get wssConnecting =>
      phase == 'connecting' || phase == 'reconnecting';
}

/// Persist watcher connection phase for the UI (written from FGS isolate).
class WatcherStatusStore {
  WatcherStatusStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Call from watcher isolate on status transitions.
  Future<void> writePhase({
    required String phase,
    String? wssUrl,
  }) async {
    try {
      final p = await _ensure();
      final host = wssUrl == null || wssUrl.isEmpty
          ? null
          : (Uri.tryParse(wssUrl)?.host ?? wssUrl);
      await p.setString(StorageKeys.watcherStatus, phase);
      if (host != null && host.isNotEmpty) {
        await p.setString(StorageKeys.watcherHost, host);
      } else if (phase != 'connected') {
        // Keep last host for diagnostics unless fully stopped/idle.
      }
      if (phase == 'stopped' || phase == 'idle') {
        await p.remove(StorageKeys.watcherHost);
      }
      await p.setInt(
        StorageKeys.watcherUpdatedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<WatcherStatusSnapshot> read({
    required bool enabled,
    required bool running,
  }) async {
    try {
      final p = await _ensure();
      final phase =
          p.getString(StorageKeys.watcherStatus) ?? 'idle';
      final host = p.getString(StorageKeys.watcherHost);
      final ms = p.getInt(StorageKeys.watcherUpdatedAt);
      return WatcherStatusSnapshot(
        enabled: enabled,
        running: running,
        phase: phase,
        host: host,
        updatedAt: ms == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(ms),
      );
    } catch (_) {
      return WatcherStatusSnapshot(
        enabled: enabled,
        running: running,
        phase: running ? 'connecting' : 'idle',
      );
    }
  }
}
