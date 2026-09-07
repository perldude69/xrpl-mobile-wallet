import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/secure/pin_key.dart';

/// Argon2id PIN → master key.
///
/// Once seed confidentiality rests on this, the cost parameters are a security
/// parameter, not a preference — a silent regression here weakens every seed
/// stored afterwards.
void main() {
  const pin = '12345678';

  /// Cheap parameters for behavioural tests. The production cost is asserted
  /// and exercised separately, once, at the end.
  PinKdfParams cheap({List<int>? salt}) => PinKdfParams(
    salt: salt ?? List<int>.filled(PinKdfParams.saltLength, 7),
    memoryBlocks: 8,
    iterations: 1,
    parallelism: 1,
  );

  group('derivation', () {
    test('is deterministic for the same PIN, salt and cost', () async {
      final params = cheap();
      final a = await PinKey.derive(pin: pin, params: params);
      final b = await PinKey.derive(pin: pin, params: params);
      expect(a.bytes, b.bytes);
      expect(a.bytes.length, PinKdfParams.keyLength);
    });

    test('a different PIN gives a different key', () async {
      final params = cheap();
      final a = await PinKey.derive(pin: pin, params: params);
      final b = await PinKey.derive(pin: '87654321', params: params);
      expect(a.bytes, isNot(b.bytes));
    });

    test('one digit different gives a completely different key', () async {
      final params = cheap();
      final a = await PinKey.derive(pin: pin, params: params);
      final b = await PinKey.derive(pin: '12345679', params: params);
      var shared = 0;
      for (var i = 0; i < PinKdfParams.keyLength; i++) {
        if (a.bytes[i] == b.bytes[i]) shared++;
      }
      expect(shared, lessThan(8), reason: 'no structural similarity');
    });

    test('a different salt gives a different key', () async {
      final a = await PinKey.derive(pin: pin, params: cheap());
      final b = await PinKey.derive(
        pin: pin,
        params: cheap(salt: List<int>.filled(PinKdfParams.saltLength, 9)),
      );
      expect(a.bytes, isNot(b.bytes));
    });

    test('a different cost gives a different key', () async {
      final a = await PinKey.derive(pin: pin, params: cheap());
      final b = await PinKey.derive(
        pin: pin,
        params: PinKdfParams(
          salt: List<int>.filled(PinKdfParams.saltLength, 7),
          memoryBlocks: 8,
          iterations: 2,
          parallelism: 1,
        ),
      );
      expect(a.bytes, isNot(b.bytes));
    });

    test('an empty PIN is refused', () async {
      await expectLater(
        PinKey.derive(pin: '', params: cheap()),
        throwsA(isA<PinKdfFormatException>()),
      );
    });
  });

  group('PinMasterKey lifecycle', () {
    test('destroy zeroes the bytes and blocks further use', () async {
      final key = await PinKey.derive(pin: pin, params: cheap());
      expect(key.isDestroyed, isFalse);
      key.destroy();
      expect(key.isDestroyed, isTrue);
      expect(() => key.bytes, throwsStateError);
    });

    test('destroy is idempotent', () async {
      final key = await PinKey.derive(pin: pin, params: cheap());
      key.destroy();
      key.destroy();
      expect(key.isDestroyed, isTrue);
    });

    test('a key of the wrong length is refused', () {
      expect(() => PinMasterKey(List<int>.filled(16, 0)), throwsArgumentError);
      expect(() => PinMasterKey(const []), throwsArgumentError);
    });
  });

  group('parameter record', () {
    test('generate produces a fresh random salt at current cost', () {
      final a = PinKdfParams.generate();
      final b = PinKdfParams.generate();
      expect(a.salt, isNot(b.salt), reason: 'salt must be per-install random');
      expect(a.salt.length, PinKdfParams.saltLength);
      expect(a.memoryBlocks, PinKdfParams.currentMemoryBlocks);
      expect(a.iterations, PinKdfParams.currentIterations);
      expect(a.parallelism, PinKdfParams.currentParallelism);
    });

    test('encode / decode round-trips', () {
      final original = PinKdfParams.generate();
      final restored = PinKdfParams.decode(original.encode());
      expect(restored.salt, original.salt);
      expect(restored.memoryBlocks, original.memoryBlocks);
      expect(restored.iterations, original.iterations);
      expect(restored.parallelism, original.parallelism);
    });

    test('an old cheaper record still decodes, and is flagged', () {
      final old = PinKdfParams(
        salt: List<int>.filled(PinKdfParams.saltLength, 1),
        memoryBlocks: 16384,
        iterations: 2,
        parallelism: 1,
      );
      final restored = PinKdfParams.decode(old.encode());
      expect(restored.memoryBlocks, 16384);
      expect(
        restored.isBelowCurrentCost,
        isTrue,
        reason: 'so the app can re-seal at the newer cost',
      );
      expect(PinKdfParams.generate().isBelowCurrentCost, isFalse);
    });

    group('hostile records', () {
      // The record lives in app storage; if that is compromised it becomes
      // attacker-controlled input on the unlock path.
      void expectRejected(Map<String, dynamic> doc) {
        expect(
          () => PinKdfParams.decode(jsonEncode(doc)),
          throwsA(isA<PinKdfFormatException>()),
        );
      }

      Map<String, dynamic> valid() =>
          jsonDecode(PinKdfParams.generate().encode()) as Map<String, dynamic>;

      test('not JSON', () {
        expect(
          () => PinKdfParams.decode('nope'),
          throwsA(isA<PinKdfFormatException>()),
        );
      });

      test('unknown kdf', () => expectRejected(valid()..['kdf'] = 'scrypt'));

      test('absurd memory cost is refused before allocating', () {
        expectRejected(valid()..['m'] = 1 << 30);
      });

      test(
        'absurd iterations refused',
        () => expectRejected(valid()..['t'] = 999999),
      );

      test('absurd parallelism refused', () {
        expectRejected(valid()..['p'] = 1 << 20);
      });

      test('zero / negative cost refused', () {
        expectRejected(valid()..['t'] = 0);
        expectRejected(valid()..['m'] = -1);
      });

      test(
        'non-integer cost refused',
        () => expectRejected(valid()..['m'] = 'big'),
      );

      test('wrong salt length refused', () {
        expectRejected(
          valid()..['salt'] = base64Encode(List<int>.filled(4, 0)),
        );
      });

      test('missing fields refused', () {
        for (final field in ['salt', 'm', 't', 'p', 'kdf']) {
          expectRejected(valid()..remove(field));
        }
      });
    });
  });

  test('production cost is memory-hard and not accidentally lowered', () {
    // 64 MiB over 3 passes. Asserted rather than trusted: this is the only
    // thing making a numeric PIN expensive to attack in bulk.
    expect(PinKdfParams.currentMemoryBlocks, 65536);
    expect(PinKdfParams.currentIterations, 3);
    expect(PinKdfParams.currentParallelism, 1);
    expect(PinKdfParams.keyLength, 32);
    expect(PinKdfParams.saltLength, 16);
  });

  test('derives at full production cost end to end', () async {
    // The only test that pays the real cost, so a mistake in the production
    // parameters cannot hide behind the cheap ones above.
    final params = PinKdfParams.generate();
    final key = await PinKey.derive(pin: pin, params: params);
    expect(key.bytes.length, 32);
    final again = await PinKey.derive(pin: pin, params: params);
    expect(key.bytes, again.bytes);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
