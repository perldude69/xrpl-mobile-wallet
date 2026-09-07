import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/trade/fill_parser.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';

/// Metadata parsing, in XRPL's own `AffectedNodes` shape.
///
/// These fixtures are hand-built to the real field layout rather than mocked
/// through a package model, because this is where a misread turns into a wrong
/// number in the user's fill history.
void main() {
  const account = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
  const counterparty = 'rN7n7otQDd6FczFgLdSqtcsAUxDkw6fzRH';
  const issuer = Rlusd.mainnetIssuer;
  final xrp = TradeAsset.xrp;
  final rlusd = TradeAsset.issued(currency: Rlusd.currencyHex, issuer: issuer);

  TradeDecimal d(String v) => TradeDecimal.parse(v);

  Map<String, dynamic> accountRoot({
    required String owner,
    required String finalDrops,
    String? previousDrops,
  }) => {
    'ModifiedNode': {
      'LedgerEntryType': 'AccountRoot',
      'LedgerIndex': 'A' * 64,
      'FinalFields': {'Account': owner, 'Balance': finalDrops},
      if (previousDrops != null) 'PreviousFields': {'Balance': previousDrops},
    },
  };

  /// A RippleState node. [lowAccount] holds the low side of the trust line, so
  /// `Balance` is written from its point of view.
  Map<String, dynamic> rippleState({
    required String lowAccount,
    required String highAccount,
    required String finalValue,
    String? previousValue,
    String currency = Rlusd.currencyHex,
  }) => {
    'ModifiedNode': {
      'LedgerEntryType': 'RippleState',
      'LedgerIndex': 'B' * 64,
      'FinalFields': {
        'Balance': {
          'currency': currency,
          'issuer': 'rrrrrrrrrrrrrrrrrrrrBZbvji',
          'value': finalValue,
        },
        'LowLimit': {
          'currency': currency,
          'issuer': lowAccount,
          'value': '1000000000',
        },
        'HighLimit': {
          'currency': currency,
          'issuer': highAccount,
          'value': '0',
        },
      },
      if (previousValue != null)
        'PreviousFields': {
          'Balance': {
            'currency': currency,
            'issuer': 'rrrrrrrrrrrrrrrrrrrrBZbvji',
            'value': previousValue,
          },
        },
    },
  };

  Map<String, dynamic> offerNode(
    String change, {
    required String owner,
    required int sequence,
    required Object finalGets,
    required Object finalPays,
    Object? previousGets,
    Object? previousPays,
  }) => {
    change: {
      'LedgerEntryType': 'Offer',
      'LedgerIndex': 'C' * 64,
      if (change == 'CreatedNode')
        'NewFields': {
          'Account': owner,
          'Sequence': sequence,
          'TakerGets': finalGets,
          'TakerPays': finalPays,
        }
      else
        'FinalFields': {
          'Account': owner,
          'Sequence': sequence,
          'TakerGets': finalGets,
          'TakerPays': finalPays,
        },
      if (previousGets != null || previousPays != null)
        'PreviousFields': {
          'TakerGets': ?previousGets,
          'TakerPays': ?previousPays,
        },
    },
  };

  group('parseAmount', () {
    test('a drops string becomes XRP', () {
      expect(FillParser.parseAmount('1000000')!.toString(), '1');
      expect(FillParser.parseAmount('1')!.toString(), '0.000001');
    });

    test('an issued object uses its value', () {
      expect(
        FillParser.parseAmount({
          'currency': Rlusd.currencyHex,
          'issuer': issuer,
          'value': '25.5',
        })!.toString(),
        '25.5',
      );
    });

    test('missing or malformed fields are null, not zero', () {
      expect(FillParser.parseAmount(null), isNull);
      expect(FillParser.parseAmount('not a number'), isNull);
      expect(FillParser.parseAmount(<String, dynamic>{}), isNull);
    });
  });

  group('balanceDeltas — XRP side', () {
    test(
      'the transaction fee is added back so it is not counted as a fill',
      () {
        // Sold 100 XRP, paid a 12-drop fee: the balance fell by 100.000012 but
        // only 100 was traded.
        final nodes = [
          accountRoot(
            owner: account,
            previousDrops: '1000000000',
            finalDrops: '899999988',
          ),
        ];
        final withFee = FillParser.balanceDeltas(
          affectedNodes: nodes,
          account: account,
          base: xrp,
          quote: rlusd,
          feeDropsPaidByAccount: '12',
        );
        expect(withFee.base.toString(), '-100');

        final withoutFee = FillParser.balanceDeltas(
          affectedNodes: nodes,
          account: account,
          base: xrp,
          quote: rlusd,
        );
        expect(withoutFee.base.toString(), '-100.000012');
      },
    );

    test('another account’s balance change is ignored', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [
          accountRoot(
            owner: counterparty,
            previousDrops: '1000000000',
            finalDrops: '900000000',
          ),
        ],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.isEmpty, isTrue);
    });

    test('a node with no previous balance moved nothing', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [accountRoot(owner: account, finalDrops: '900000000')],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.base.isZero, isTrue);
    });
  });

  group('balanceDeltas — trust line sign convention', () {
    test('as the LOW account, the balance is read as written', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [
          rippleState(
            lowAccount: account,
            highAccount: issuer,
            previousValue: '10',
            finalValue: '35',
          ),
        ],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.quote.toString(), '25', reason: 'received 25 RLUSD');
    });

    test('as the HIGH account, the balance is negated', () {
      // Same ledger movement, our account on the other side of the line. Read
      // without negating, this would record a 25 RLUSD gain as a 25 loss.
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [
          rippleState(
            lowAccount: issuer,
            highAccount: account,
            previousValue: '-10',
            finalValue: '-35',
          ),
        ],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.quote.toString(), '25');
    });

    test('a line we are not party to is ignored', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [
          rippleState(
            lowAccount: counterparty,
            highAccount: issuer,
            previousValue: '0',
            finalValue: '100',
          ),
        ],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.quote.isZero, isTrue);
    });

    test('a different currency on our own line is ignored', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [
          rippleState(
            lowAccount: account,
            highAccount: issuer,
            previousValue: '0',
            finalValue: '100',
            currency: 'USD',
          ),
        ],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.quote.isZero, isTrue);
    });

    test('issued precision survives to 15 figures', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: [
          rippleState(
            lowAccount: account,
            highAccount: issuer,
            previousValue: '0',
            finalValue: '0.000000000000001',
          ),
        ],
        account: account,
        base: xrp,
        quote: rlusd,
      );
      expect(deltas.quote, d('0.000000000000001'));
    });
  });

  group('a complete OfferCreate: sell 100 XRP for 250 RLUSD', () {
    final nodes = [
      accountRoot(
        owner: account,
        previousDrops: '1000000000',
        finalDrops: '899999988',
      ),
      rippleState(
        lowAccount: account,
        highAccount: issuer,
        previousValue: '0',
        finalValue: '250',
      ),
    ];

    test('both legs are read from one transaction', () {
      final deltas = FillParser.balanceDeltas(
        affectedNodes: nodes,
        account: account,
        base: xrp,
        quote: rlusd,
        feeDropsPaidByAccount: '12',
      );
      expect(deltas.base.toString(), '-100');
      expect(deltas.quote.toString(), '250');
    });

    test('nothing rested, so no offer was created', () {
      expect(
        FillParser.createdOfferSequence(affectedNodes: nodes, account: account),
        isNull,
      );
    });
  });

  group('createdOfferSequence', () {
    test('finds our own newly rested offer', () {
      final sequence = FillParser.createdOfferSequence(
        affectedNodes: [
          offerNode(
            'CreatedNode',
            owner: account,
            sequence: 42,
            finalGets: '50000000',
            finalPays: {
              'currency': Rlusd.currencyHex,
              'issuer': issuer,
              'value': '125',
            },
          ),
        ],
        account: account,
      );
      expect(sequence, 42);
    });

    test('a stranger’s new offer in the same metadata is not ours', () {
      expect(
        FillParser.createdOfferSequence(
          affectedNodes: [
            offerNode(
              'CreatedNode',
              owner: counterparty,
              sequence: 42,
              finalGets: '50000000',
              finalPays: '1',
            ),
          ],
          account: account,
        ),
        isNull,
      );
    });
  });

  group('offerOutcome', () {
    test('a partial fill reports what was consumed and what remains', () {
      final outcome = FillParser.offerOutcome(
        affectedNodes: [
          offerNode(
            'ModifiedNode',
            owner: account,
            sequence: 42,
            previousGets: '100000000',
            finalGets: '60000000',
            previousPays: {
              'currency': Rlusd.currencyHex,
              'issuer': issuer,
              'value': '250',
            },
            finalPays: {
              'currency': Rlusd.currencyHex,
              'issuer': issuer,
              'value': '150',
            },
          ),
        ],
        account: account,
        sequence: 42,
      )!;
      expect(outcome.change, LedgerNodeChange.modified);
      expect(outcome.isResting, isTrue);
      expect(outcome.consumedGets, d('40'));
      expect(outcome.consumedPays, d('100'));
      expect(outcome.remainingGets, d('60'));
    });

    test('a deleted offer is gone from the book', () {
      final outcome = FillParser.offerOutcome(
        affectedNodes: [
          offerNode(
            'DeletedNode',
            owner: account,
            sequence: 42,
            previousGets: '40000000',
            finalGets: '0',
            finalPays: '0',
          ),
        ],
        account: account,
        sequence: 42,
      )!;
      expect(outcome.isGone, isTrue);
      expect(outcome.consumedGets, d('40'));
    });

    test('matches on account AND sequence, never sequence alone', () {
      final nodes = [
        offerNode(
          'ModifiedNode',
          owner: counterparty,
          sequence: 42,
          previousGets: '100000000',
          finalGets: '0',
          finalPays: '0',
        ),
      ];
      expect(
        FillParser.offerOutcome(
          affectedNodes: nodes,
          account: account,
          sequence: 42,
        ),
        isNull,
        reason: 'a stranger’s offer 42 is not our offer 42',
      );
    });

    test('an untouched offer returns null', () {
      expect(
        FillParser.offerOutcome(
          affectedNodes: const [],
          account: account,
          sequence: 42,
        ),
        isNull,
      );
    });
  });

  test('an unrecognised node shape is skipped, not fatal', () {
    final deltas = FillParser.balanceDeltas(
      affectedNodes: [
        {'SomethingElse': <String, dynamic>{}},
        <String, dynamic>{},
        accountRoot(
          owner: account,
          previousDrops: '1000000000',
          finalDrops: '999000000',
        ),
      ],
      account: account,
      base: xrp,
      quote: rlusd,
    );
    expect(deltas.base.toString(), '-1');
  });
}
