import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';

void main() {
  final importer = WalletImporter();

  const abandon12 =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const abandonAddress = 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3';
  const genesisSeed = 'snoPBrXtMeMyMHUVTgbuqAfg1SUTb';
  const genesisAddress = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';

  group('deriveMnemonicForAddress', () {
    test('matches when address is correct', () {
      final d = importer.deriveMnemonicForAddress(
        abandon12,
        expectedAddress: abandonAddress,
      );
      expect(d.address, abandonAddress);
      expect(d.importMethod, ImportMethod.mnemonic);
      expect(d.secret.split(' ').length, 12);
    });

    test('rejects wrong address', () {
      expect(
        () => importer.deriveMnemonicForAddress(
          abandon12,
          expectedAddress: genesisAddress,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('does not match'),
          ),
        ),
      );
    });
  });

  group('deriveFamilySeedForAddress', () {
    test('matches genesis', () {
      final d = importer.deriveFamilySeedForAddress(
        genesisSeed,
        expectedAddress: genesisAddress,
      );
      expect(d.address, genesisAddress);
      expect(d.importMethod, ImportMethod.familySeed);
    });

    test('rejects wrong address', () {
      expect(
        () => importer.deriveFamilySeedForAddress(
          genesisSeed,
          expectedAddress: abandonAddress,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('import still works via derive', () {
    test('importMnemonic same address as derive', () {
      final derived = importer.deriveMnemonic(abandon12);
      final imported = importer.importMnemonic(
        abandon12,
        label: 'T',
        network: NetworkId.testnet,
      );
      expect(imported.account.address, derived.address);
      expect(imported.secret, derived.secret);
    });
  });
}
