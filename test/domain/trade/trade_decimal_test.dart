import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';

/// Exact decimal arithmetic. Every case here is one a `double` gets wrong.
void main() {
  TradeDecimal d(String v) => TradeDecimal.parse(v);

  group('parse', () {
    test('plain decimals round-trip exactly', () {
      expect(d('0').toString(), '0');
      expect(d('1').toString(), '1');
      expect(d('1.5').toString(), '1.5');
      expect(d('-2.25').toString(), '-2.25');
      expect(d('0.000001').toString(), '0.000001');
      expect(d('  12.340  ').toString(), '12.34');
    });

    test('scientific notation from the ledger is understood', () {
      expect(d('1e-8').toString(), '0.00000001');
      expect(d('1.5E3').toString(), '1500');
      expect(d('2e+2').toString(), '200');
      expect(d('-3.25e-2').toString(), '-0.0325');
    });

    test('15 significant figures survive intact', () {
      const value = '1234.56789012345';
      expect(d(value).toString(), value);
    });

    test('a value a double cannot hold is kept exactly', () {
      // 0.1 + 0.2 in binary floating point is 0.30000000000000004.
      expect((d('0.1') + d('0.2')).toString(), '0.3');
      expect(d('0.1') + d('0.2') == d('0.3'), isTrue);
    });

    test('garbage throws rather than becoming a wrong number', () {
      for (final bad in [
        '',
        '   ',
        'abc',
        '1.2.3',
        '1,5',
        '--1',
        '1e',
        '0x10',
      ]) {
        expect(
          () => d(bad),
          throwsFormatException,
          reason: 'must reject "$bad"',
        );
      }
    });

    test('tryParse returns null instead of throwing', () {
      expect(TradeDecimal.tryParse(null), isNull);
      expect(TradeDecimal.tryParse('nope'), isNull);
      expect(TradeDecimal.tryParse('4.5'), d('4.5'));
    });
  });

  group('comparison', () {
    test('compares across differing scales', () {
      expect(d('1.50') == d('1.5'), isTrue);
      expect(d('1.5') > d('1.499999999999'), isTrue);
      expect(d('-1') < d('0'), isTrue);
      expect(d('0.0') == TradeDecimal.zero, isTrue);
    });

    test('equal values hash equally regardless of scale', () {
      expect(d('2.500').hashCode, d('2.5').hashCode);
    });
  });

  group('multiply', () {
    test('is exact, keeping the full product scale', () {
      expect((d('0.07') * d('0.03')).toString(), '0.0021');
      expect((d('1.005') * d('100')).toString(), '100.5');
    });
  });

  group('divide rounding direction', () {
    test('rounds toward +infinity when roundUp is true', () {
      expect(
        d('1').divide(d('3'), scale: 4, roundUp: true).toString(),
        '0.3334',
      );
      expect(d('10').divide(d('4'), scale: 0, roundUp: true).toString(), '3');
    });

    test('rounds toward -infinity when roundUp is false', () {
      expect(
        d('1').divide(d('3'), scale: 4, roundUp: false).toString(),
        '0.3333',
      );
      expect(d('10').divide(d('4'), scale: 0, roundUp: false).toString(), '2');
    });

    test('negatives use floor/ceiling, not truncation toward zero', () {
      // -2.5 floors to -3 and ceils to -2. Truncation would give -2 for both,
      // which would flip the rounding direction for a balance delta.
      expect(
        d('-10').divide(d('4'), scale: 0, roundUp: false).toString(),
        '-3',
      );
      expect(d('-10').divide(d('4'), scale: 0, roundUp: true).toString(), '-2');
    });

    test('exact division does not round at all', () {
      expect(d('1').divide(d('4'), scale: 6, roundUp: true).toString(), '0.25');
      expect(
        d('1').divide(d('4'), scale: 6, roundUp: false).toString(),
        '0.25',
      );
    });

    test('division by zero is rejected', () {
      expect(
        () => d('1').divide(TradeDecimal.zero, scale: 6, roundUp: true),
        throwsArgumentError,
      );
    });
  });

  group('withScale', () {
    test('extends without changing the value', () {
      expect(d('1.5').withScale(6, roundUp: false).toString(), '1.5');
      expect(d('1.5').withScale(6, roundUp: false).scale, 6);
    });

    test('truncating XRP to drops respects the direction', () {
      expect(d('1.0000005').withScale(6, roundUp: false).toString(), '1');
      expect(d('1.0000005').withScale(6, roundUp: true).toString(), '1.000001');
    });
  });

  group('roundToSignificantFigures', () {
    test('trims an issued amount to 15 figures', () {
      final value = d('1.2345678901234567890');
      expect(
        value.roundToSignificantFigures(15, roundUp: false).toString(),
        '1.23456789012345',
      );
      expect(
        value.roundToSignificantFigures(15, roundUp: true).toString(),
        '1.23456789012346',
      );
    });

    test('a value already within the limit is untouched', () {
      expect(
        d('1.5').roundToSignificantFigures(15, roundUp: true).toString(),
        '1.5',
      );
    });

    test('zero stays zero', () {
      expect(
        TradeDecimal.zero.roundToSignificantFigures(15, roundUp: true),
        TradeDecimal.zero,
      );
    });
  });

  group('fromUnscaled', () {
    test('drops become XRP', () {
      expect(
        TradeDecimal.fromUnscaled(BigInt.from(1500000), 6).toString(),
        '1.5',
      );
      expect(TradeDecimal.fromUnscaled(BigInt.one, 6).toString(), '0.000001');
    });

    test('a negative scale is rejected', () {
      expect(
        () => TradeDecimal.fromUnscaled(BigInt.one, -1),
        throwsArgumentError,
      );
    });
  });

  test('toString never emits scientific notation', () {
    expect(d('1e-15').toString(), '0.000000000000001');
    expect(d('1e20').toString(), '100000000000000000000');
  });
}
