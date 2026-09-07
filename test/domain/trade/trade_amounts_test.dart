import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_amounts.dart';

void main() {
  group('offerAmount — XRP↔drops and issued amounts', () {
    test('XRP is converted to integer drops (any case, trimmed)', () {
      final a = TradeAmounts.offerAmount(' 1.234567 ', 'xrp', '');
      expect(a, isA<XRPAmount>());
      expect((a as XRPAmount).toJson(), '1234567');
    });

    test('whole XRP', () {
      expect(
        (TradeAmounts.offerAmount('10', 'XRP', '') as XRPAmount).toJson(),
        '10000000',
      );
    });

    test('issued amount keeps value, currency, and issuer', () {
      const issuer = 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De';
      final a = TradeAmounts.offerAmount('25.5', 'USD', issuer);
      expect(a, isA<IssuedCurrencyAmount>());
      final json = a.toJson() as Map;
      expect(json['value'], '25.5');
      expect(json['currency'], 'USD');
      expect(json['issuer'], issuer);
    });

    test('sub-drop XRP precision is rejected, not silently truncated', () {
      expect(
        () => TradeAmounts.offerAmount('0.0000001', 'XRP', ''),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('describe', () {
    test('renders XRP from drops', () {
      expect(
        TradeAmounts.describe(TradeAmounts.offerAmount('2.5', 'XRP', '')),
        '2.5 XRP',
      );
    });

    test('renders an issued amount with its currency', () {
      const issuer = 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De';
      expect(
        TradeAmounts.describe(TradeAmounts.offerAmount('7', 'USD', issuer)),
        '7 USD',
      );
    });
  });
}
