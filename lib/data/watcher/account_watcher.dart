import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/data/endpoints/endpoint_preferences.dart';
import 'package:xrpl_mobile_wallet/data/watcher/address_book.dart';
import 'package:xrpl_mobile_wallet/data/watcher/watcher_service.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';

/// UI-isolate control surface for the background XRPL watcher.
///
/// Writes a **public-only** address book JSON and starts/stops the Android
/// foreground service. Never touches KeyVault or PIN material.
class AccountWatcher {
  AccountWatcher({
    WatcherAddressBookStore? store,
    FlutterBackgroundService? service,
    EndpointPreferences? endpoints,
  })  : _store = store ?? WatcherAddressBookStore(),
        _service = service ?? FlutterBackgroundService(),
        _endpoints = endpoints ?? EndpointPreferences();

  final WatcherAddressBookStore _store;
  final FlutterBackgroundService _service;
  final EndpointPreferences _endpoints;
  static bool _configured = false;

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Configure background service + notification channels. Safe to call once.
  ///
  /// No-op on platforms without FGS support (desktop tests, web).
  Future<void> initialize() async {
    if (!isSupportedPlatform) return;
    if (_configured) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConfig.watcherStatusChannelId,
        AppConfig.watcherStatusChannelName,
        description: 'Sticky status for the XRPL account watcher',
        importance: Importance.low,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConfig.walletActivityChannelId,
        AppConfig.walletActivityChannelName,
        description: 'Validated ledger activity for watched accounts',
        importance: Importance.high,
      ),
    );
    // Android 13+ notification permission (no-op on older).
    await android?.requestNotificationsPermission();

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: watcherOnStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: AppConfig.watcherStatusChannelId,
        initialNotificationTitle: 'XRPL Watcher',
        initialNotificationContent: 'Starting…',
        foregroundServiceNotificationId:
            AppConfig.watcherStatusNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: watcherOnStart,
      ),
    );
    _configured = true;
  }

  Future<WatcherAddressBook> loadAddressBook() => _store.load();

  /// Rewrite the public address book from wallet metadata + active network.
  Future<void> syncAddressBook(
    List<WalletAccount> accounts,
    NetworkId network,
  ) async {
    final previous = await _store.load();
    final preferredWss = await _endpoints.preferredWss(network);
    final book = WatcherAddressBook(
      network: network.name,
      wss: preferredWss,
      enabled: previous.enabled,
      accounts: accounts
          .map(
            (a) => WatcherAccountEntry(
              address: a.address,
              label: a.label,
            ),
          )
          .toList(),
    );
    await _store.save(book);
    await _applyRunState(book);
  }

  /// Update network/WSS on the existing public address book (accounts unchanged).
  Future<void> updateNetwork(NetworkId network) async {
    final previous = await _store.load();
    final preferredWss = await _endpoints.preferredWss(network);
    final book = previous.copyWith(
      network: network.name,
      wss: preferredWss,
    );
    await _store.save(book);
    await _applyRunState(book);
  }

  /// Enable/disable watcher (persisted in address book JSON).
  ///
  /// Default for a brand-new book is **enabled** (`true`).
  Future<void> setEnabled(bool enabled) async {
    final previous = await _store.load();
    final book = previous.copyWith(enabled: enabled);
    await _store.save(book);
    await _applyRunState(book);
  }

  Future<bool> isEnabled() async {
    final book = await _store.load();
    return book.enabled;
  }

  Future<bool> isRunning() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _service.isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Start the FGS when the address book says it should run.
  Future<void> ensureStartedIfEnabled() async {
    if (!isSupportedPlatform) return;
    final book = await _store.load();
    await _applyRunState(book);
  }

  /// Stop the watcher and remove the public address book (full app wipe).
  Future<void> wipeLocalState() async {
    try {
      await setEnabled(false);
    } catch (_) {}
    await _stop();
    await _store.clear();
  }

  Future<void> _applyRunState(WatcherAddressBook book) async {
    if (!isSupportedPlatform) return;
    if (!_configured) {
      await initialize();
    }
    if (!book.shouldRun) {
      await _stop();
      return;
    }
    final running = await isRunning();
    if (running) {
      _service.invoke('reload');
    } else {
      await _service.startService();
    }
  }

  Future<void> _stop() async {
    try {
      final running = await isRunning();
      if (running) {
        _service.invoke('stop');
      }
    } catch (_) {}
  }
}
