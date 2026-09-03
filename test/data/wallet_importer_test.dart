import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';

void main() {
  final importer = WalletImporter();

  group('importFamilySeed', () {
    test('genesis seed maps to master address', () {
      // XRPL docs classic genesis master seed → master account.
      final result = importer.importFamilySeed(
        'snoPBrXtMeMyMHUVTgbuqAfg1SUTb',
        label: 'Genesis',
        network: NetworkId.testnet,
      );
      expect(result.account.address, 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh');
      expect(result.account.kind, WalletKind.signing);
      expect(result.account.importMethod, ImportMethod.familySeed);
      expect(result.secret, 'snoPBrXtMeMyMHUVTgbuqAfg1SUTb');
      expect(result.account.canSign, isTrue);
    });

    test('rejects garbage seed', () {
      expect(
        () => importer.importFamilySeed(
          'not-a-seed',
          label: 'X',
          network: NetworkId.mainnet,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty label', () {
      expect(
        () => importer.importFamilySeed(
          'snoPBrXtMeMyMHUVTgbuqAfg1SUTb',
          label: '  ',
          network: NetworkId.mainnet,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('importMnemonic', () {
    test('matches xrpl.js Wallet.fromMnemonic (secp256k1 BIP44)', () {
      // BIP39 English test vector; must match desktop xrpl.js fromMnemonic.
      const phrase =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const expectedAddress = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3';
      final result = importer.importMnemonic(
        phrase,
        label: 'Mnemonic wallet',
        network: NetworkId.mainnet,
      );
      expect(result.account.address, expectedAddress);
      expect(AddressValidator.isValidClassic(result.account.address), isTrue);
      expect(result.account.kind, WalletKind.signing);
      expect(result.account.importMethod, ImportMethod.mnemonic);
      expect(result.secret, isNotNull);
      expect(result.account.canSign, isTrue);
    });

    test('rejects wrong word count', () {
      expect(
        () => importer.importMnemonic(
          'only three words',
          label: 'X',
          network: NetworkId.mainnet,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('importWatchOnly', () {
    test('accepts known classic address', () {
      final result = importer.importWatchOnly(
        'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        label: 'Watch me',
        network: NetworkId.mainnet,
      );
      expect(result.account.address, 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh');
      expect(result.account.kind, WalletKind.watchOnly);
      expect(result.account.importMethod, ImportMethod.addressOnly);
      expect(result.secret, isNull);
      expect(result.account.canSign, isFalse);
    });

    test('rejects garbage', () {
      expect(
        () => importer.importWatchOnly(
          'not-an-address',
          label: 'X',
          network: NetworkId.mainnet,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
