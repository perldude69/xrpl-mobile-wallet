import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';

/// Real-shaped `account_tx` success payload (hash nested under `tx`).
Map<String, dynamic> _sampleAccountTxResult() {
  return {
    'account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
    'ledger_index_min': 100,
    'ledger_index_max': 200,
    'limit': 20,
    'status': 'success',
    'validated': true,
    'transactions': [
      {
        'meta': {
          'AffectedNodes': [
            {
              'ModifiedNode': {
                'FinalFields': {
                  'Account': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
                  'Balance': '21014615310',
                  'Flags': 0,
                  'OwnerCount': 0,
                  'Sequence': 17027004,
                },
                'LedgerEntryType': 'AccountRoot',
                'LedgerIndex':
                    '31CCE9D28412FF973E9AB6D0FA219BACF19687D9A2456A0C2ABC3280E9D47E37',
                'PreviousFields': {'Balance': '21013615310'},
                'PreviousTxnID':
                    '589611EC0761F4D3AF7CB790B0793E6F2060200D79C06CC2980309400894EED7',
                'PreviousTxnLgrSeq': 19470506,
              },
            },
          ],
          'TransactionIndex': 5,
          'TransactionResult': 'tesSUCCESS',
          'delivered_amount': '1000000',
        },
        'tx': {
          'Account': 'rBqcrYBJcv5mT8icy5xr7REFDcTW9goNVK',
          'Amount': '1000000',
          'Destination': 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
          'Fee': '12',
          'Flags': 2147483648,
          'Sequence': 19472152,
          'SigningPubKey':
              '02F4BA4151E4DBB17C5DBE404FEC3B7A3EBDFA696B1D4A1EB48D981036341973D4',
          'TransactionType': 'Payment',
          'TxnSignature':
              '3045022100B1CD7C0F1111D9C6C5DDA2CC0D7669EA17F52FA4D3C085E410C086EC27522FA9022017FB96EBCFBB629A4BAF736B60BF2A9E530D777DBCCE737F653E5A60FBBB6A57',
          'date': 838672591,
          'hash':
              '98318C886B6BEBAA4DAA1822C7CBABA4721DC1B5D7EE6736DDBCA796EFB378A7',
          'inLedger': 19472155,
          'ledger_index': 19472155,
        },
        'validated': true,
      },
    ],
  };
}

void main() {
  group('XrplRpcClient.fetchAccountTx', () {
    test('requests full ledger range (not ledger_index=validated)', () async {
      Map<String, dynamic>? sentParams;

      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], 'account_tx');
        sentParams = (body['params'] as List).first as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'result': _sampleAccountTxResult()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = XrplRpcClient();
      await client.connect(NetworkId.testnet, httpClient: mock);
      try {
        final summaries = await client.fetchAccountTx(
          'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
          limit: 20,
        );

        expect(sentParams, isNotNull);
        // Root cause of empty history: library default ledger_index=validated
        // pins min=max to the latest ledger only.
        expect(
          sentParams!.containsKey('ledger_index'),
          isFalse,
          reason: 'ledger_index must be omitted for account history',
        );
        expect(sentParams!['ledger_index_min'], -1);
        expect(sentParams!['ledger_index_max'], -1);

        expect(summaries, hasLength(1));
        expect(
          summaries.first.hash,
          '98318C886B6BEBAA4DAA1822C7CBABA4721DC1B5D7EE6736DDBCA796EFB378A7',
        );
        expect(
          summaries.first.transactionType.toLowerCase(),
          contains('payment'),
        );
        expect(
          summaries.first.destination,
          'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe',
        );
        expect(summaries.first.amountSummary, contains('XRP'));
      } finally {
        await client.disconnect();
      }
    });

    test('returns empty list for actNotFound', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': {
              'error': 'actNotFound',
              'error_message': 'Account not found.',
              'status': 'error',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = XrplRpcClient();
      await client.connect(NetworkId.testnet, httpClient: mock);
      try {
        final summaries = await client.fetchAccountTx(
          'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        );
        expect(summaries, isEmpty);
      } finally {
        await client.disconnect();
      }
    });
  });
}
