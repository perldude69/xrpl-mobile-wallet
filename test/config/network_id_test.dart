import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';

void main() {
  group('mainnet WSS endpoints', () {
    test('primary is public cluster', () {
      expect(NetworkId.mainnet.defaultWss, 'wss://xrplcluster.com');
      final uri = Uri.parse(NetworkId.mainnet.defaultWss);
      expect(uri.scheme, 'wss');
      expect(uri.host, 'xrplcluster.com');
      expect(uri.queryParameters.containsKey('token'), isFalse);
    });

    test('two public endpoints: cluster, ankr', () {
      expect(NetworkId.mainnet.wssEndpoints, [
        'wss://xrplcluster.com',
        'wss://mainnet.xrpl-rpc.com',
      ]);
    });
  });

  group('mainnet HTTP RPC endpoints', () {
    test('primary is public cluster', () {
      expect(NetworkId.mainnet.defaultHttp, 'https://xrplcluster.com/');
      expect(NetworkId.mainnet.httpEndpoints.first, 'https://xrplcluster.com/');
    });

    test('two public endpoints: cluster, ankr', () {
      expect(NetworkId.mainnet.httpEndpoints, [
        'https://xrplcluster.com/',
        'https://mainnet.xrpl-rpc.com/',
      ]);
    });
  });

  group('testnet', () {
    test('keeps altnet WSS and HTTP', () {
      expect(
        NetworkId.testnet.defaultWss,
        'wss://s.altnet.rippletest.net:51233',
      );
      expect(NetworkId.testnet.defaultHttp, 'https://testnet.xrpl-rpc.com/');
      expect(NetworkId.testnet.httpEndpoints.length, 2);
      expect(NetworkId.testnet.wssEndpoints.length, 1);
    });
  });

  test('networkIdFromName', () {
    expect(networkIdFromName('testnet'), NetworkId.testnet);
    expect(networkIdFromName('mainnet'), NetworkId.mainnet);
    expect(networkIdFromName('unknown'), NetworkId.mainnet);
  });
}
