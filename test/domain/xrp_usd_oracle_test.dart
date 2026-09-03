import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/oracle/xrp_usd_oracle.dart';

void main() {
  test('parses TrustSet LimitAmount as USD per XRP', () {
    final quote = XrpUsdOracle.parseTransaction({
      'TransactionType': 'TrustSet',
      'Account': XrpUsdOracle.oracleAddress,
      'LimitAmount': {
        'currency': 'USD',
        'issuer': 'r9PfV3sQpKLWxccdg3HL2FXKxGW2orAcLE',
        'value': '1.0748',
      },
      'date': 839211080,
      'hash': 'ABC',
    });
    expect(quote, isNotNull);
    expect(quote!.usdPerXrp, closeTo(1.0748, 1e-9));
    expect(quote.hash, 'ABC');
  });

  test('ignores non-oracle accounts', () {
    final quote = XrpUsdOracle.parseTransaction({
      'TransactionType': 'TrustSet',
      'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
      'LimitAmount': {
        'currency': 'USD',
        'issuer': 'r9PfV3sQpKLWxccdg3HL2FXKxGW2orAcLE',
        'value': '1.0',
      },
    });
    expect(quote, isNull);
  });

  test('parses exchange memos last sample', () {
    // rates:Binance → hex of "1.07;1.08"
    const memoType = '72617465733A42696E616E6365'; // rates:Binance
    const memoData = '312E30373B312E3038'; // 1.07;1.08
    final quote = XrpUsdOracle.parseTransaction({
      'TransactionType': 'TrustSet',
      'Account': XrpUsdOracle.oracleAddress,
      'LimitAmount': {
        'currency': 'USD',
        'issuer': 'rIssuer',
        'value': '1.075',
      },
      'Memos': [
        {
          'Memo': {
            'MemoType': memoType,
            'MemoData': memoData,
            'MemoFormat': '746578742F637376',
          },
        },
      ],
    });
    expect(quote!.exchangeRates['Binance'], closeTo(1.08, 1e-9));
  });

  test('stream message wrapper', () {
    final quote = XrpUsdOracle.parseStreamMessage({
      'type': 'transaction',
      'validated': true,
      'transaction': {
        'TransactionType': 'TrustSet',
        'Account': XrpUsdOracle.oracleAddress,
        'LimitAmount': {
          'currency': 'USD',
          'issuer': 'rIssuer',
          'value': '2.5',
        },
        'hash': 'HH',
      },
    });
    expect(quote!.usdPerXrp, 2.5);
  });
}
