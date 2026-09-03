import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';
import 'package:xrpl_mobile_wallet/data/endpoints/endpoint_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to full mainnet catalog', () async {
    final p = EndpointPreferences();
    expect(await p.selectedHttpIds(), EndpointPreferences.defaultHttpIds);
    expect(await p.selectedWssIds(), EndpointPreferences.defaultWssIds);
    final http = await p.httpUrls(NetworkId.mainnet);
    expect(http.first, 'https://xrplcluster.com/');
    expect(http.length, 2);
  });

  test('setHttpIds filters and persists order', () async {
    final p = EndpointPreferences();
    await p.setHttpIds(['ankr', 'cluster', 'unknown']);
    expect(await p.selectedHttpIds(), ['ankr', 'cluster']);
    final urls = await p.httpUrls(NetworkId.mainnet);
    expect(urls, [
      'https://mainnet.xrpl-rpc.com/',
      'https://xrplcluster.com/',
    ]);
  });

  test('empty set falls back to full catalog', () async {
    final p = EndpointPreferences();
    await p.setWssIds([]);
    expect(await p.selectedWssIds(), EndpointPreferences.defaultWssIds);
  });

  test('stale personal catalog ids are dropped', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.mainnetHttpEndpointIds: 'richlist,cluster',
    });
    final p = EndpointPreferences();
    expect(await p.selectedHttpIds(), ['cluster']);
  });

  test('testnet ignores mainnet prefs', () async {
    final p = EndpointPreferences();
    await p.setHttpIds(['ankr']);
    final urls = await p.httpUrls(NetworkId.testnet);
    expect(urls, NetworkId.testnet.httpEndpoints);
  });

  group('EndpointUrl.validate', () {
    test('rejects cleartext http and ws', () {
      expect(
        EndpointUrl.validate(kind: EndpointKind.http, url: 'http://example.com'),
        contains('https://'),
      );
      expect(
        EndpointUrl.validate(kind: EndpointKind.wss, url: 'ws://example.com'),
        contains('wss://'),
      );
    });

    test('accepts https and wss', () {
      expect(
        EndpointUrl.validate(
          kind: EndpointKind.http,
          url: 'https://rpc.example.com/',
        ),
        isNull,
      );
      expect(
        EndpointUrl.validate(
          kind: EndpointKind.wss,
          url: 'wss://wss.example.com:443/?token=secret',
        ),
        isNull,
      );
    });
  });

  test('hostOf never includes query tokens', () {
    expect(
      EndpointUrl.hostOf('wss://wss.example.com:443/?token=super-secret'),
      'wss.example.com',
    );
    expect(
      CustomEndpoint(
        id: 'c1',
        label: 'mine',
        kind: EndpointKind.wss,
        url: 'wss://wss.example.com:443/?token=super-secret',
      ).host,
      'wss.example.com',
    );
  });

  test('custom HTTPS is appended after built-in catalog', () async {
    final p = EndpointPreferences();
    await p.addCustom(
      id: 'c-http',
      label: 'home',
      kind: EndpointKind.http,
      url: 'https://rpc.example.com/',
    );
    expect(await p.httpUrls(NetworkId.mainnet), [
      'https://xrplcluster.com/',
      'https://mainnet.xrpl-rpc.com/',
      'https://rpc.example.com/',
    ]);
  });

  test('empty built-in still includes full catalog plus custom', () async {
    final p = EndpointPreferences();
    await p.setHttpIds([]);
    await p.addCustom(
      id: 'c-http',
      label: 'home',
      kind: EndpointKind.http,
      url: 'https://rpc.example.com/',
    );
    final urls = await p.httpUrls(NetworkId.mainnet);
    expect(urls, [
      'https://xrplcluster.com/',
      'https://mainnet.xrpl-rpc.com/',
      'https://rpc.example.com/',
    ]);
  });

  test('addCustom rejects http://', () async {
    final p = EndpointPreferences();
    expect(
      () => p.addCustom(
        label: 'bad',
        kind: EndpointKind.http,
        url: 'http://rpc.example.com/',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('custom WSS reorder stays in user order', () async {
    final p = EndpointPreferences();
    await p.addCustom(
      id: 'a',
      label: 'a',
      kind: EndpointKind.wss,
      url: 'wss://a.example.com',
    );
    await p.addCustom(
      id: 'b',
      label: 'b',
      kind: EndpointKind.wss,
      url: 'wss://b.example.com',
    );
    await p.moveCustom(id: 'b', kind: EndpointKind.wss, delta: -1);
    expect(await p.wssUrls(NetworkId.mainnet), [
      'wss://xrplcluster.com',
      'wss://mainnet.xrpl-rpc.com',
      'wss://b.example.com',
      'wss://a.example.com',
    ]);
  });
}
