import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/state/trade_controller.dart';

void main() {
  const xrp = [LedgerBalance(currency: 'XRP', value: '10')];
  const rlusd = [
    LedgerBalance(
      currency: '524C555344000000000000000000000000000000',
      value: '5',
      issuer: 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De',
    ),
  ];

  test('unknown balances are treated as funded', () {
    expect(takerGetsIsFunded('1000000', balances: null), isTrue);
  });

  test('XRP offer is unfunded when the held balance is too small', () {
    expect(takerGetsIsFunded('20000000', balances: xrp), isFalse);
    expect(takerGetsIsFunded('1000000', balances: xrp), isTrue);
  });

  test('issued offer is unfunded when the line is too small', () {
    const gets = {
      'currency': '524C555344000000000000000000000000000000',
      'issuer': 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De',
      'value': '6',
    };
    expect(takerGetsIsFunded(gets, balances: rlusd), isFalse);
    expect(takerGetsIsFunded({...gets, 'value': '5'}, balances: rlusd), isTrue);
  });
}
