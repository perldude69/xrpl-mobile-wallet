import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_reconciler.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_repository.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';

/// Reconciliation: every status the app shows must be backed by something the
/// ledger actually said.
///
/// No live network and no real funds — the RPC client is replaced with a fake
/// that returns captured-shape responses.
void main() {
  const wallet = 'w1';
  const address = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
  const issuer = Rlusd.mainnetIssuer;
  const txHash = 'TX_OFFER_CREATE';

  late AppDatabase db;
  late TradeRepository repository;
  late _FakeRpcClient client;
  late TradeReconciler reconciler;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TradeRepository(db);
    client = _FakeRpcClient();
    reconciler = TradeReconciler(
      database: db,
      repository: repository,
      client: client,
    );
    await db.upsertWallet(
      WalletsCompanion.insert(
        id: wallet,
        label: 'Test',
        address: address,
        kind: 'signing',
        preferredNetwork: 'mainnet',
        importMethod: 'familySeed',
        createdAt: DateTime.now(),
      ),
    );
  });

  tearDown(() => db.close());

  /// A submitted sell of 100 XRP for 250 RLUSD.
  Future<void> seedSubmitted({
    String id = 'e1',
    int? lastLedgerSequence = 500,
    String? hash = txHash,
    TradeStatus status = TradeStatus.submitted,
    int? offerSequence,
    String network = 'mainnet',
  }) async {
    final now = DateTime.now();
    await db.upsertTradeExecution(
      TradeExecutionsCompanion.insert(
        id: id,
        walletId: wallet,
        network: network,
        side: 'sell',
        baseCurrency: 'XRP',
        quoteCurrency: Rlusd.currencyHex,
        quoteIssuer: const Value(issuer),
        targetAmount: '100',
        orderType: 'limit',
        status: status.storageValue,
        txHash: Value(hash),
        lastLedgerSequence: Value(lastLedgerSequence),
        offerSequence: Value(offerSequence),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<TradeStatus> statusOf(String id) async =>
      TradeStatus.fromStorage((await db.getTradeExecution(id))!.status);

  Map<String, dynamic> accountRootNode(String previous, String finalDrops) => {
    'ModifiedNode': {
      'LedgerEntryType': 'AccountRoot',
      'LedgerIndex': 'A' * 64,
      'FinalFields': {'Account': address, 'Balance': finalDrops},
      'PreviousFields': {'Balance': previous},
    },
  };

  Map<String, dynamic> rlusdNode(String previous, String finalValue) => {
    'ModifiedNode': {
      'LedgerEntryType': 'RippleState',
      'LedgerIndex': 'B' * 64,
      'FinalFields': {
        'Balance': {
          'currency': Rlusd.currencyHex,
          'issuer': 'rrrrrrrrrrrrrrrrrrrrBZbvji',
          'value': finalValue,
        },
        'LowLimit': {
          'currency': Rlusd.currencyHex,
          'issuer': address,
          'value': '1000000000',
        },
        'HighLimit': {
          'currency': Rlusd.currencyHex,
          'issuer': issuer,
          'value': '0',
        },
      },
      'PreviousFields': {
        'Balance': {
          'currency': Rlusd.currencyHex,
          'issuer': 'rrrrrrrrrrrrrrrrrrrrBZbvji',
          'value': previous,
        },
      },
    },
  };

  Map<String, dynamic> createdOfferNode(int sequence, String remainingDrops) =>
      {
        'CreatedNode': {
          'LedgerEntryType': 'Offer',
          'LedgerIndex': 'C' * 64,
          'NewFields': {
            'Account': address,
            'Sequence': sequence,
            'TakerGets': remainingDrops,
            'TakerPays': {
              'currency': Rlusd.currencyHex,
              'issuer': issuer,
              'value': '150',
            },
          },
        },
      };

  LedgerTxDetail validatedOffer({
    required List<Map<String, dynamic>> nodes,
    String hash = txHash,
    int ledgerIndex = 450,
    String result = 'tesSUCCESS',
  }) => LedgerTxDetail(
    hash: hash,
    transactionType: 'OfferCreate',
    account: address,
    affectedNodes: nodes,
    ledgerIndex: ledgerIndex,
    validated: true,
    transactionResult: result,
    sequence: 10,
    lastLedgerSequence: 500,
    feeDrops: '12',
    date: 700000000,
  );

  group('rule 1 — never guess, never blind-retry', () {
    test('an unknown transaction below its LLS stays submitted', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 400; // still within LastLedgerSequence 500
      client.transactions[txHash] = null; // txnNotFound

      final outcomes = await reconciler.reconcileAll();

      expect(outcomes, isEmpty);
      expect(await statusOf('e1'), TradeStatus.submitted);
    });

    test('a found but unvalidated transaction stays submitted', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 400;
      client.transactions[txHash] = LedgerTxDetail(
        hash: txHash,
        transactionType: 'OfferCreate',
        account: address,
        affectedNodes: const [],
        validated: false,
      );

      await reconciler.reconcileAll();
      expect(await statusOf('e1'), TradeStatus.submitted);
    });

    test('a row with no tx hash is parked for the user, not retried', () async {
      await seedSubmitted(
        hash: null,
        status: TradeStatus.signing,
        lastLedgerSequence: null,
      );
      client.currentLedgerIndex = 400;

      await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.interrupted);
      expect((await db.getTradeExecution('e1'))!.lastError, 'no-tx-hash');
      expect(client.transactionLookups, isEmpty);
    });
  });

  group('rule 2 — LastLedgerSequence is the only proof of death', () {
    test('past LLS with nothing validated is definitively expired', () async {
      await seedSubmitted(lastLedgerSequence: 500);
      client.currentLedgerIndex = 501;
      client.transactions[txHash] = null;

      final outcomes = await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.expired);
      expect((await db.getTradeExecution('e1'))!.lastError, 'lls-expired');
      expect(outcomes.single.to, TradeStatus.expired);
    });

    test(
      'without a recorded LLS, an unknown tx is never called dead',
      () async {
        await seedSubmitted(lastLedgerSequence: null);
        client.currentLedgerIndex = 99999999;
        client.transactions[txHash] = null;

        await reconciler.reconcileAll();
        expect(await statusOf('e1'), TradeStatus.submitted);
      },
    );

    test('an engine failure is recorded with its result code', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 460;
      client.transactions[txHash] = validatedOffer(
        nodes: const [],
        result: 'tecUNFUNDED_OFFER',
      );

      await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.failed);
      expect(
        (await db.getTradeExecution('e1'))!.lastError,
        'engine:tecUNFUNDED_OFFER',
      );
    });
  });

  group('rule 3 — fills come from validated metadata', () {
    test('a complete fill is read from the balance deltas', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 460;
      client.transactions[txHash] = validatedOffer(
        nodes: [
          accountRootNode('1000000000', '899999988'),
          rlusdNode('0', '250'),
        ],
      );

      await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.filled);
      final fills = await db.getTradeFills('e1');
      expect(fills.single.filledBase, '100');
      expect(fills.single.filledQuote, '250');
      expect(fills.single.rate, '2.5');
      expect((await db.getTradeExecution('e1'))!.filledAmount, '100');
    });

    test('the fee is not counted as part of the fill', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 460;
      client.transactions[txHash] = validatedOffer(
        nodes: [
          // Balance fell by 100.000012 XRP; 12 drops of that was the fee.
          accountRootNode('1000000000', '899999988'),
          rlusdNode('0', '250'),
        ],
      );

      await reconciler.reconcileAll();
      expect((await db.getTradeFills('e1')).single.filledBase, '100');
    });

    test('replaying a pass does not double-count a fill', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 460;
      client.transactions[txHash] = validatedOffer(
        nodes: [
          accountRootNode('1000000000', '899999988'),
          rlusdNode('0', '250'),
        ],
      );

      await reconciler.reconcileAll();
      // Force the row back to a non-terminal state and run again.
      await repository.markStatus('e1', TradeStatus.submitted);
      await reconciler.reconcileAll();

      expect((await db.getTradeFills('e1')).length, 1);
      expect((await db.getTradeExecution('e1'))!.filledAmount, '100');
    });

    test('an order that rested unfilled is resting, not submitted', () async {
      await seedSubmitted();
      client.currentLedgerIndex = 460;
      client.transactions[txHash] = validatedOffer(
        nodes: [
          // Fee only: nothing crossed.
          accountRootNode('1000000000', '999999988'),
          createdOfferNode(11, '100000000'),
        ],
      );
      client.offers = [_offer(11, '100000000', '250')];

      await reconciler.reconcileAll();

      final row = (await db.getTradeExecution('e1'))!;
      expect(TradeStatus.fromStorage(row.status), TradeStatus.resting);
      expect(row.offerSequence, 11);
      expect(await db.getTradeFills('e1'), isEmpty);
    });

    test(
      'a partial fill that left a remainder resting is reported so',
      () async {
        await seedSubmitted();
        client.currentLedgerIndex = 460;
        client.transactions[txHash] = validatedOffer(
          nodes: [
            accountRootNode('1000000000', '959999988'),
            rlusdNode('0', '100'),
            createdOfferNode(11, '60000000'),
          ],
        );
        client.offers = [_offer(11, '60000000', '150')];

        await reconciler.reconcileAll();

        final row = (await db.getTradeExecution('e1'))!;
        expect(
          TradeStatus.fromStorage(row.status),
          TradeStatus.partiallyFilled,
        );
        expect(row.filledAmount, '40');
      },
    );
  });

  group('a resting offer resolved later, from someone else’s transaction', () {
    setUp(() async {
      await seedSubmitted(status: TradeStatus.resting, offerSequence: 11);
      client.currentLedgerIndex = 700;
      client.transactions[txHash] = validatedOffer(
        nodes: [
          accountRootNode('1000000000', '999999988'),
          createdOfferNode(11, '100000000'),
        ],
      );
    });

    test('a stranger crossing our offer completes it', () async {
      client.offers = const []; // gone from the book
      client.history = [
        LedgerTxDetail(
          hash: 'TX_TAKER',
          transactionType: 'Payment',
          // Not our transaction: we paid no fee in it.
          account: 'rN7n7otQDd6FczFgLdSqtcsAUxDkw6fzRH',
          affectedNodes: [
            accountRootNode('999999988', '899999988'),
            rlusdNode('0', '250'),
            {
              'DeletedNode': {
                'LedgerEntryType': 'Offer',
                'LedgerIndex': 'C' * 64,
                'FinalFields': {
                  'Account': address,
                  'Sequence': 11,
                  'TakerGets': '0',
                  'TakerPays': '0',
                },
                'PreviousFields': {'TakerGets': '100000000'},
              },
            },
          ],
          ledgerIndex: 650,
          validated: true,
          transactionResult: 'tesSUCCESS',
          feeDrops: '12',
          date: 700000100,
        ),
      ];

      await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.filled);
      final fill = (await db.getTradeFills('e1')).single;
      expect(fill.txHash, 'TX_TAKER');
      expect(fill.filledBase, '100');
      expect(
        fill.feeDrops,
        isNull,
        reason: 'we did not pay the fee on a stranger’s transaction',
      );
    });

    test('our own OfferCancel closes the row as cancelled', () async {
      client.offers = const [];
      client.history = [
        LedgerTxDetail(
          hash: 'TX_CANCEL',
          transactionType: 'OfferCancel',
          account: address,
          affectedNodes: [
            {
              'DeletedNode': {
                'LedgerEntryType': 'Offer',
                'LedgerIndex': 'C' * 64,
                'FinalFields': {
                  'Account': address,
                  'Sequence': 11,
                  'TakerGets': '100000000',
                  'TakerPays': '250',
                },
              },
            },
          ],
          ledgerIndex: 660,
          validated: true,
          transactionResult: 'tesSUCCESS',
          feeDrops: '12',
          date: 700000200,
        ),
      ];

      await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.cancelled);
      expect((await db.getTradeExecution('e1'))!.lastError, isNull);
      expect(await db.getTradeFills('e1'), isEmpty);
    });

    test('still on the book means still resting', () async {
      client.offers = [_offer(11, '100000000', '250')];

      await reconciler.reconcileAll();
      expect(await statusOf('e1'), TradeStatus.resting);
    });

    test('gone with no explanation is closed and marked as inferred', () async {
      client.offers = const [];
      client.history = const [];

      await reconciler.reconcileAll();

      expect(await statusOf('e1'), TradeStatus.cancelled);
      expect(
        (await db.getTradeExecution('e1'))!.lastError,
        'left-book',
        reason: 'the ending was inferred, and the row must say so',
      );
    });
  });

  group('pass safety', () {
    test('terminal rows are never revisited', () async {
      await seedSubmitted(id: 'done', status: TradeStatus.filled);
      client.currentLedgerIndex = 900;

      await reconciler.reconcileAll();
      expect(client.transactionLookups, isEmpty);
    });

    test('a row on another network is left alone', () async {
      await seedSubmitted(network: 'testnet');
      client.currentLedgerIndex = 900;
      client.transactions[txHash] = null;

      await reconciler.reconcileAll();

      expect(
        await statusOf('e1'),
        TradeStatus.submitted,
        reason: 'a testnet row must not be resolved by mainnet answers',
      );
      expect(client.transactionLookups, isEmpty);
    });

    test('a disconnected client does nothing at all', () async {
      await seedSubmitted();
      client.connected = false;

      expect(await reconciler.reconcileAll(), isEmpty);
      expect(await statusOf('e1'), TradeStatus.submitted);
    });

    test('one broken row does not abandon the others', () async {
      await seedSubmitted(id: 'bad', hash: 'TX_BOOM');
      await seedSubmitted(id: 'good', hash: 'TX_GOOD');
      client.currentLedgerIndex = 460;
      client.throwOn.add('TX_BOOM');
      client.transactions['TX_GOOD'] = validatedOffer(
        hash: 'TX_GOOD',
        nodes: [
          accountRootNode('1000000000', '899999988'),
          rlusdNode('0', '250'),
        ],
      );

      await reconciler.reconcileAll();

      expect(await statusOf('bad'), TradeStatus.submitted);
      expect(await statusOf('good'), TradeStatus.filled);
    });

    test('a failure to read the ledger index changes nothing', () async {
      await seedSubmitted();
      client.ledgerIndexThrows = true;

      expect(await reconciler.reconcileAll(), isEmpty);
      expect(await statusOf('e1'), TradeStatus.submitted);
    });
  });

  test('deleting a wallet removes its trade rows and fills', () async {
    await seedSubmitted();
    await repository.recordFill(
      executionId: 'e1',
      txHash: 'TX_A',
      ledgerIndex: 1,
      filledBase: TradeDecimal.parse('10'),
      filledQuote: TradeDecimal.parse('10'),
      rate: TradeDecimal.parse('1'),
      date: DateTime.now(),
    );

    await db.deleteWalletCascade(wallet);

    expect(await db.getTradeExecutionsForWallet(wallet), isEmpty);
    expect(await db.getTradeFills('e1'), isEmpty);
  });
}

AccountOffer _offer(int seq, String getsDrops, String paysValue) =>
    AccountOffer(
      flags: 0,
      seq: seq,
      takerGets: XRPAmount(BigInt.parse(getsDrops)),
      takerPays: IssuedCurrencyAmount(
        value: paysValue,
        currency: Rlusd.currencyHex,
        issuer: Rlusd.mainnetIssuer,
      ),
      quality: '1',
    );

/// Stand-in for the ledger. Returns captured-shape responses; no sockets.
class _FakeRpcClient extends XrplRpcClient {
  bool connected = true;
  bool ledgerIndexThrows = false;
  int currentLedgerIndex = 0;
  List<AccountOffer> offers = const [];
  List<LedgerTxDetail> history = const [];

  /// hash → detail, or null to answer `txnNotFound`.
  final Map<String, LedgerTxDetail?> transactions = {};
  final Set<String> throwOn = {};
  final List<String> transactionLookups = [];

  @override
  bool get isConnected => connected;

  @override
  NetworkId? get network => connected ? NetworkId.mainnet : null;

  @override
  Future<int> fetchCurrentLedgerIndex() async {
    if (ledgerIndexThrows) throw StateError('no ledger');
    return currentLedgerIndex;
  }

  @override
  Future<LedgerTxDetail?> fetchTransaction(String hash) async {
    transactionLookups.add(hash);
    if (throwOn.contains(hash)) throw StateError('lookup failed');
    return transactions[hash];
  }

  @override
  Future<List<AccountOffer>> fetchAccountOffers(String address) async => offers;

  @override
  Future<List<LedgerTxDetail>> fetchAccountTxDetails(
    String address, {
    int limit = 50,
  }) async => history;
}
