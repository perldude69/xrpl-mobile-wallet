import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/network/connection_health.dart';

void main() {
  group('ConnectionHealth.evaluate', () {
    test('watcher off: green when RPC up', () {
      final h = ConnectionHealth.evaluate(
        const ConnectionHealthInput(
          rpcConnected: true,
          rpcConnecting: false,
          watcherEnabled: false,
          wssConnected: false,
        ),
      );
      expect(h.light, TrafficLight.green);
      expect(h.shortLabel, 'Live');
    });

    test('watcher off: red when RPC down', () {
      final h = ConnectionHealth.evaluate(
        const ConnectionHealthInput(
          rpcConnected: false,
          rpcConnecting: false,
          watcherEnabled: false,
          wssConnected: false,
        ),
      );
      expect(h.light, TrafficLight.red);
      expect(h.shortLabel, 'Offline');
    });

    test('both up → green', () {
      final h = ConnectionHealth.evaluate(
        const ConnectionHealthInput(
          rpcConnected: true,
          rpcConnecting: false,
          watcherEnabled: true,
          wssConnected: true,
        ),
      );
      expect(h.light, TrafficLight.green);
    });

    test('RPC up WSS down → yellow Partial', () {
      final h = ConnectionHealth.evaluate(
        const ConnectionHealthInput(
          rpcConnected: true,
          rpcConnecting: false,
          watcherEnabled: true,
          wssConnected: false,
        ),
      );
      expect(h.light, TrafficLight.yellow);
      expect(h.shortLabel, 'Partial');
    });

    test('both down → red', () {
      final h = ConnectionHealth.evaluate(
        const ConnectionHealthInput(
          rpcConnected: false,
          rpcConnecting: false,
          watcherEnabled: true,
          wssConnected: false,
        ),
      );
      expect(h.light, TrafficLight.red);
      expect(h.shortLabel, 'Offline');
    });

    test('connecting both sides → yellow Connecting', () {
      final h = ConnectionHealth.evaluate(
        const ConnectionHealthInput(
          rpcConnected: false,
          rpcConnecting: true,
          watcherEnabled: true,
          wssConnected: false,
          wssConnecting: true,
        ),
      );
      expect(h.light, TrafficLight.yellow);
      expect(h.shortLabel, 'Connecting');
    });
  });
}
