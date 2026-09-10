import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/data/endpoints/endpoint_preferences.dart';
import 'package:xrpl_mobile_wallet/data/oracle/xrp_usd_rate_store.dart';
import 'package:xrpl_mobile_wallet/data/watcher/address_book.dart';
import 'package:xrpl_mobile_wallet/data/watcher/tx_notification_parser.dart';
import 'package:xrpl_mobile_wallet/data/watcher/watcher_status_store.dart';
import 'package:xrpl_mobile_wallet/domain/oracle/xrp_usd_oracle.dart';

/// Background isolate entry for the XRPL account watcher.
///
/// **Security:** This isolate must never import KeyVault, PinService, or any
/// secret-bearing module (`lib/data/secure/key_vault.dart`, `pin_service.dart`).
/// It only reads [WatcherAddressBook] (public addresses).
@pragma('vm:entry-point')
void watcherOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final androidPlugin = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      AppConfig.watcherStatusChannelId,
      AppConfig.watcherStatusChannelName,
      description: 'Sticky status for the XRPL account watcher',
      importance: Importance.low,
    ),
  );
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      AppConfig.walletActivityChannelId,
      AppConfig.walletActivityChannelName,
      description: 'Validated ledger activity for watched accounts',
      importance: Importance.high,
    ),
  );

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  final runner = _WatcherRunner(service: service, notifications: notifications);
  await runner.start();
}

class _WatcherRunner {
  _WatcherRunner({required this.service, required this.notifications});

  final ServiceInstance service;
  final FlutterLocalNotificationsPlugin notifications;
  final WatcherAddressBookStore _store = WatcherAddressBookStore();
  final WatcherStatusStore _statusStore = WatcherStatusStore();
  final XrpUsdRateStore _rateStore = XrpUsdRateStore();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;
  WatcherAddressBook _book = WatcherAddressBook.empty;
  final Set<String> _seenHashes = <String>{};
  bool _stopping = false;
  int _backoffSeconds = 2;
  int _activityNotificationId = 1000;
  Future<void>? _reloadFuture;

  /// Endpoint currently connected (for status); null when disconnected.
  String? _activeWss;

  static const _connectTimeout = Duration(seconds: 12);

  Future<void> start() async {
    service.on('stop').listen((_) async {
      await _shutdown(stopService: true);
    });
    service.on('reload').listen((_) async {
      await _reloadAndResubscribe();
    });

    await _loadSeenHashes();
    await _reloadAndResubscribe();
  }

  Future<void> _reloadAndResubscribe() {
    return _reloadFuture ??= _reloadAndResubscribeImpl().whenComplete(() {
      _reloadFuture = null;
    });
  }

  Future<void> _reloadAndResubscribeImpl() async {
    try {
      _book = await _store.load();
    } catch (_) {
      await _statusStore.writePhase(phase: 'error');
      await _updateStatusNotification('error');
      return;
    }
    if (!_book.shouldRun) {
      await _statusStore.writePhase(phase: 'idle');
      await _updateStatusNotification('idle');
      await _shutdown(stopService: true);
      return;
    }
    await _connect();
  }

  /// Ordered WSS URLs from user prefs (mainnet) or fixed catalog (testnet).
  ///
  /// Address-book `wss` is appended last so a custom value is still tried.
  Future<List<String>> _wssCandidates() async {
    final network = networkIdFromName(_book.network);
    final ordered = <String>[];
    void add(String url) {
      final t = url.trim();
      if (t.isEmpty) return;
      if (!ordered.contains(t)) ordered.add(t);
    }

    final prefs = EndpointPreferences();
    for (final url in await prefs.wssUrls(network)) {
      add(url);
    }
    // Legacy / custom book value last if not already listed.
    add(_book.wss);
    return ordered;
  }

  Future<void> _connect() async {
    await _closeSocket();
    _activeWss = null;
    if (_stopping || !_book.shouldRun) return;

    await _statusStore.writePhase(phase: 'connecting');
    await _updateStatusNotification('connecting');

    final candidates = await _wssCandidates();
    Object? lastError;

    for (final wss in candidates) {
      if (_stopping || !_book.shouldRun) return;
      try {
        final uri = Uri.parse(wss);
        final channel = WebSocketChannel.connect(uri);
        // Wait until the socket is actually open before treating as success.
        await channel.ready.timeout(_connectTimeout);

        if (_stopping) {
          try {
            await channel.sink.close();
          } catch (_) {}
          return;
        }

        _channel = channel;
        _activeWss = wss;

        final addresses = _subscribeAccounts();
        channel.sink.add(
          jsonEncode({'id': 1, 'command': 'subscribe', 'accounts': addresses}),
        );

        _backoffSeconds = 2;
        await _statusStore.writePhase(phase: 'connected', wssUrl: wss);
        await _updateStatusNotification('connected');

        _socketSub = channel.stream.listen(
          _onSocketData,
          onError: (_) => _scheduleReconnect(),
          onDone: () => _scheduleReconnect(),
          cancelOnError: true,
        );
        return;
      } catch (e) {
        lastError = e;
        _channel = null;
        _activeWss = null;
        // Try next endpoint in the failover list.
      }
    }

    // All endpoints failed.
    assert(lastError != null || candidates.isEmpty);
    await _statusStore.writePhase(phase: 'reconnecting');
    await _updateStatusNotification('reconnecting');
    _scheduleReconnect();
  }

  /// Wallet addresses plus mainnet XRP/USD oracle (public).
  List<String> _subscribeAccounts() {
    final addresses = _book.accounts.map((a) => a.address).toList();
    if (_book.network == NetworkId.mainnet.name ||
        _book.network.isEmpty ||
        _book.network == 'mainnet') {
      if (!addresses.contains(AppConfig.xrpUsdOracleAddress)) {
        addresses.add(AppConfig.xrpUsdOracleAddress);
      }
    }
    return addresses;
  }

  void _onSocketData(dynamic data) {
    try {
      final text = data is String ? data : data.toString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;
      final message = Map<String, dynamic>.from(decoded);

      // Subscribe ack / errors — ignore for notifications.
      if (message.containsKey('status') && message['result'] != null) {
        return;
      }
      if (message['type']?.toString() == 'response') return;

      // Oracle TrustSet → cache XRP/USD rate (no user notification).
      final quote = XrpUsdOracle.parseStreamMessage(message);
      if (quote != null) {
        unawaited(_rateStore.save(quote));
        return;
      }

      final event = TxNotificationParser.parseMessage(message);
      if (event == null) return;
      // Only validated ledger transactions are suitable for user activity.
      if (message['validated'] != true) return;
      // Never notify for oracle account activity.
      if (event.account == AppConfig.xrpUsdOracleAddress ||
          event.destination == AppConfig.xrpUsdOracleAddress) {
        return;
      }
      unawaited(_handleTxEvent(event));
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  Future<void> _handleTxEvent(WatcherTxEvent event) async {
    if (_seenHashes.contains(event.hash)) return;
    final matched = TxNotificationParser.matchWatchedAccount(
      event,
      _book.accounts,
    );
    if (matched == null) return;

    _seenHashes.add(event.hash);
    if (_seenHashes.length > 500) {
      // Bound memory; drop arbitrary older entries.
      final drop = _seenHashes.take(100).toList();
      _seenHashes.removeAll(drop);
    }
    await _persistSeenHashes();

    final copy = TxNotificationParser.notificationCopy(
      event: event,
      book: _book,
    );
    final prefs = await SharedPreferences.getInstance();
    final hideAmounts =
        prefs.getBool('watcher_hide_notification_amounts') ?? false;

    _activityNotificationId = (_activityNotificationId + 1).clamp(
      1000,
      2000000000,
    );
    await notifications.show(
      id: _activityNotificationId,
      title: copy.title,
      body: hideAmounts ? 'Validated ledger activity detected.' : copy.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConfig.walletActivityChannelId,
          AppConfig.walletActivityChannelName,
          channelDescription: 'Validated ledger activity for watched accounts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: event.hash,
    );
  }

  void _scheduleReconnect() {
    if (_stopping || !_book.shouldRun) return;
    unawaited(_statusStore.writePhase(phase: 'reconnecting'));
    unawaited(_updateStatusNotification('reconnecting'));
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _backoffSeconds);
    _backoffSeconds = (_backoffSeconds * 2).clamp(2, 60);
    _reconnectTimer = Timer(delay, () {
      unawaited(_connect());
    });
  }

  Future<void> _updateStatusNotification(String status) async {
    final networkLabel = switch (_book.network) {
      'testnet' => 'Testnet',
      _ => 'Mainnet',
    };
    final n = _book.accounts.length;
    final host = _activeWss == null
        ? null
        : (Uri.tryParse(_activeWss!)?.host ?? _activeWss);
    final hostPart = host == null ? '' : ' · $host';
    final content =
        'XRPL Watcher: $n account${n == 1 ? '' : 's'} · $networkLabel$hostPart · $status';

    // Field promotion does not apply; use a local for AndroidServiceInstance APIs.
    final svc = service;
    if (svc is AndroidServiceInstance) {
      await svc.setForegroundNotificationInfo(
        title: 'XRPL Watcher',
        content: content,
      );
    }

    // Also refresh the low-importance status notification payload when custom.
    await notifications.show(
      id: AppConfig.watcherStatusNotificationId,
      title: 'XRPL Watcher',
      body: content,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConfig.watcherStatusChannelId,
          AppConfig.watcherStatusChannelName,
          channelDescription: 'Sticky status for the XRPL account watcher',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> _loadSeenHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('watcher_seen_tx_hashes') ?? const [];
      _seenHashes
        ..clear()
        ..addAll(list);
    } catch (_) {}
  }

  Future<void> _persistSeenHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep a bounded ring of recent hashes for process restarts.
      final list = _seenHashes.toList();
      final tail = list.length > 200 ? list.sublist(list.length - 200) : list;
      await prefs.setStringList('watcher_seen_tx_hashes', tail);
    } catch (_) {}
  }

  Future<void> _closeSocket() async {
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> _shutdown({required bool stopService}) async {
    _stopping = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocket();
    await _statusStore.writePhase(phase: 'stopped');
    if (stopService) {
      service.stopSelf();
    }
  }
}
