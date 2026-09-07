import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_export.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';

void main() {
  WalletAccount wallet(
    String label,
    String address, {
    NetworkId network = NetworkId.mainnet,
  }) => WalletAccount(
    id: 'id-$label',
    label: label,
    address: address,
    kind: WalletKind.signing,
    preferredNetwork: network,
    importMethod: ImportMethod.familySeed,
    createdAt: DateTime.utc(2026),
  );

  test('suggestedFileName is YYYYMMDD_HHMMSS.json', () {
    final name = WalletExport.suggestedFileName(
      DateTime(2026, 7, 22, 15, 4, 5),
    );
    expect(name, '20260722_150405.json');
    expect(name.toLowerCase(), isNot(contains('xrpl')));
    expect(name.toLowerCase(), isNot(contains('wallet')));
  });

  test('encrypt/decrypt roundtrip recovers name and address only', () async {
    final wallets = [
      wallet('Cold', 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh'),
      wallet('Hot', 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe'),
    ];
    const password = 'secret1';

    final doc = await WalletExport.encryptExport(
      wallets: wallets,
      password: password,
    );

    // Outer document must not contain cleartext addresses or branding.
    final outer = doc.toString();
    expect(outer, isNot(contains('rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh')));
    expect(outer, isNot(contains('Cold')));
    expect(outer.toLowerCase(), isNot(contains('xrpl')));
    expect(doc.containsKey('ct'), isTrue);
    expect(doc.containsKey('salt'), isTrue);

    final entries = await WalletExport.decryptExport(
      document: doc,
      password: password,
    );
    expect(entries.length, 2);
    expect(entries[0].name, 'Cold');
    expect(entries[0].address, 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh');
    expect(entries[1].name, 'Hot');
    expect(entries[1].address, 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe');
    expect(entries[0].network, NetworkId.mainnet);
  });

  test('roundtrip preserves testnet network', () async {
    final doc = await WalletExport.encryptExport(
      wallets: [
        wallet(
          'Test',
          'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
          network: NetworkId.testnet,
        ),
      ],
      password: 'secret1',
    );
    final entries = await WalletExport.decryptExport(
      document: doc,
      password: 'secret1',
    );
    expect(entries.single.network, NetworkId.testnet);
  });

  test('wrong password fails', () async {
    final doc = await WalletExport.encryptExport(
      wallets: [wallet('A', 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh')],
      password: 'correct1',
    );
    expect(
      () => WalletExport.decryptExport(document: doc, password: 'wrong000'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('short password rejected', () async {
    expect(
      () => WalletExport.encryptExport(
        wallets: [wallet('A', 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh')],
        password: '123',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('decrypt rejects attacker-controlled iteration counts', () async {
    final doc = await WalletExport.encryptExport(
      wallets: [wallet('A', 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh')],
      password: 'correct1',
    );

    Future<void> expectRejected(int iter) async {
      final hostile = Map<String, dynamic>.from(doc);
      hostile['iter'] = iter;
      await expectLater(
        WalletExport.decryptExport(document: hostile, password: 'correct1'),
        throwsA(isA<ArgumentError>()),
      );
    }

    await expectRejected(1);
    await expectRejected(WalletExport.maxPbkdf2Iterations + 1);
  });
}
