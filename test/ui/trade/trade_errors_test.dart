import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_error_slug.dart';
import 'package:xrpl_mobile_wallet/ui/trade/trade_errors.dart';

void main() {
  group('tradeFailureMessage — never leaks exception text (XRW-26)', () {
    final secret = 'r-secret-snoPBrXtMeMyMHUVTgbuqAfg1SUTb should not appear';

    final cases = <Object>[
      ArgumentError(secret),
      StateError(secret),
      FormatException(secret),
      TimeoutException(secret),
      const PaymentOperationException('signing'),
      Exception(secret),
      'raw string $secret',
    ];

    for (final e in cases) {
      test('${e.runtimeType}', () {
        final msg = tradeFailureMessage(e);
        expect(msg, isNotEmpty);
        expect(msg.contains(secret), isFalse, reason: 'must not echo input');
        expect(msg.contains('snoPBrXtMeMyMHUVTgbuqAfg1SUTb'), isFalse);
        // Ends as a plain sentence, no stack/exception decoration.
        expect(msg, isNot(contains('Exception')));
        expect(msg, isNot(contains('#0')));
      });
    }

    test(
      'PaymentOperationException surfaces only its fixed stage constant',
      () {
        expect(
          tradeFailureMessage(const PaymentOperationException('autofill')),
          'The order failed during autofill.',
        );
      },
    );
  });

  group('tradeErrorCategory — fixed slugs for persistence (XRW-28)', () {
    test('maps known types to stable slugs', () {
      expect(tradeErrorCategory(ArgumentError('x')), 'validation');
      expect(tradeErrorCategory(StateError('x')), 'no-signing-key');
      expect(tradeErrorCategory(TimeoutException('x')), 'network-timeout');
      expect(
        tradeErrorCategory(const PaymentOperationException('submit timeout')),
        'stage:submit timeout',
      );
      expect(tradeErrorCategory(Exception('x')), 'unknown');
    });

    test('slug never contains the original message', () {
      const marker = 'SEED-snoPBrXtMeMyMHUVTgbuqAfg1SUTb';
      expect(
        tradeErrorCategory(ArgumentError(marker)).contains(marker),
        isFalse,
      );
      expect(tradeErrorCategory(StateError(marker)).contains(marker), isFalse);
    });
  });
}
