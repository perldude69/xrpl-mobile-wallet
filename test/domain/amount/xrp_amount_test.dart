import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';

void main() {
  test('drops to XRP', () {
    expect(XrpAmount.dropsToXrp('1000000'), '1');
    expect(XrpAmount.dropsToXrp('1'), '0.000001');
  });

  test('xrp to drops', () {
    expect(XrpAmount.xrpToDrops('1'), '1000000');
  });

  test('drops to XRP strips trailing zeros', () {
    expect(XrpAmount.dropsToXrp('1500000'), '1.5');
    expect(XrpAmount.dropsToXrp('1000001'), '1.000001');
    expect(XrpAmount.dropsToXrp('0'), '0');
  });

  test('xrp to drops with fractional', () {
    expect(XrpAmount.xrpToDrops('0.000001'), '1');
    expect(XrpAmount.xrpToDrops('1.5'), '1500000');
    expect(XrpAmount.xrpToDrops('0'), '0');
  });
}
