import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/watcher/watcher_status_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('writePhase stores host only, never the query string', () async {
    final store = WatcherStatusStore();
    await store.writePhase(
      phase: 'connected',
      wssUrl: 'wss://wss.example.com:443/?token=should-not-leak',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(StorageKeys.watcherHost), 'wss.example.com');
    expect(prefs.getString(StorageKeys.watcherHost), isNot(contains('token')));

    final snap = await store.read(enabled: true, running: true);
    expect(snap.host, 'wss.example.com');
  });
}
