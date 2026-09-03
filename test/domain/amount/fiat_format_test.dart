import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/amount/fiat_format.dart';

void main() {
  test('formatUsd groups thousands', () {
    expect(FiatFormat.formatUsd(1234.5), r'$1,234.50');
    expect(FiatFormat.formatUsd(0.5), r'$0.50');
  });

  test('xrpToUsd multiplies', () {
    expect(FiatFormat.xrpToUsd('10', 1.5), closeTo(15.0, 1e-9));
    expect(FiatFormat.xrpToUsd(null, 1.5), isNull);
  });

  test('formatRate', () {
    expect(FiatFormat.formatRate(1.0748), contains(r'$'));
    expect(FiatFormat.formatRate(1.0748), contains('XRP'));
  });
}
