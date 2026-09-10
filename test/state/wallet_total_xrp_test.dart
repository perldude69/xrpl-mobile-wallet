import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';

void main() {
  WalletAccount wallet(String id) => WalletAccount(
    id: id,
    label: id,
    address: 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
    kind: WalletKind.watchOnly,
    preferredNetwork: NetworkId.testnet,
    importMethod: ImportMethod.addressOnly,
    createdAt: DateTime.utc(2026),
  );

  test('totalXrp sums known balances in drops', () {
    final state = WalletListState(
      wallets: [wallet('a'), wallet('b'), wallet('c')],
      balances: {
        'a': const [LedgerBalance(currency: 'XRP', value: '1.5')],
        'b': const [LedgerBalance(currency: 'XRP', value: '2.25')],
        // c missing → 0
      },
    );
    expect(state.totalXrp, '3.75');
    expect(state.hasPartialBalances, isTrue);
  });

  test('ensureUniqueAddress rejects a duplicate classic address', () {
    expect(
      () => WalletListController.ensureUniqueAddress([
        wallet('a'),
      ], 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh'),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => WalletListController.ensureUniqueAddress([
        wallet('a'),
      ], 'rPT1Sjq2YGrBMTttX4GZHjKu9dyfzbpAYe'),
      returnsNormally,
    );
  });

  test('same address may exist once per network', () {
    const address = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
    final mainnet = WalletAccount(
      id: 'main',
      label: 'Main',
      address: address,
      kind: WalletKind.watchOnly,
      preferredNetwork: NetworkId.mainnet,
      importMethod: ImportMethod.addressOnly,
      createdAt: DateTime.utc(2026),
    );
    final testnet = WalletAccount(
      id: 'test',
      label: 'Test',
      address: address,
      kind: WalletKind.watchOnly,
      preferredNetwork: NetworkId.testnet,
      importMethod: ImportMethod.addressOnly,
      createdAt: DateTime.utc(2026),
    );
    // Unfiltered list would reject the address even across networks.
    expect(
      () =>
          WalletListController.ensureUniqueAddress([mainnet, testnet], address),
      throwsA(isA<ArgumentError>()),
    );
    // reload() only passes the active network, so a mainnet row does not
    // block importing the same address on testnet.
    final visibleOnTestnet = [
      mainnet,
      testnet,
    ].where((w) => w.preferredNetwork == NetworkId.testnet).toList();
    expect(visibleOnTestnet, [testnet]);
    expect(
      () => WalletListController.ensureUniqueAddress(
        [
          mainnet,
        ].where((w) => w.preferredNetwork == NetworkId.testnet).toList(),
        address,
      ),
      returnsNormally,
    );
  });

  test('totalXrp is 0 with empty wallets', () {
    const state = WalletListState();
    expect(state.totalXrp, '0');
    expect(state.hasPartialBalances, isFalse);
  });

  test('totalXrp ignores IOU-only rows and uses XRP', () {
    final state = WalletListState(
      wallets: [wallet('a')],
      balances: {
        'a': const [
          LedgerBalance(currency: 'USD', value: '100', issuer: 'rIssuer'),
          LedgerBalance(currency: 'XRP', value: '10'),
        ],
      },
    );
    expect(state.totalXrp, '10');
    expect(state.hasPartialBalances, isFalse);
  });
}
