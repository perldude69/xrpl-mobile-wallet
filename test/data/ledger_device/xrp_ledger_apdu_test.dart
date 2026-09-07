import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/data/ledger_device/ledger_xrp_device.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';

void main() {
  group('xrpBip32Path / pathBytes', () {
    test('default account 0 is m/44\'/144\'/0\'/0/0 hardened prefix', () {
      final path = xrpBip32Path();
      expect(path.length, 5);
      expect(path[0], 44 | 0x80000000);
      expect(path[1], 144 | 0x80000000);
      expect(path[2], 0 | 0x80000000);
      expect(path[3], 0);
      expect(path[4], 0);
    });

    test('account index is hardened at path[2]', () {
      final path = xrpBip32Path(accountIndex: 3);
      expect(path[2], 3 | 0x80000000);
    });

    test('pathBytes starts with depth then 5×4-byte BE indices', () {
      final bytes = pathBytes(accountIndex: 0);
      // 1 depth + 5 * 4 path components
      expect(bytes.length, 1 + 5 * 4);
      expect(bytes[0], 5);
      // 44' = 0x8000002c
      expect(bytes[1], 0x80);
      expect(bytes[2], 0x00);
      expect(bytes[3], 0x00);
      expect(bytes[4], 0x2c);
      // 144' = 0x80000090
      expect(bytes[5], 0x80);
      expect(bytes[6], 0x00);
      expect(bytes[7], 0x00);
      expect(bytes[8], 0x90);
    });
  });

  group('checkApduStatus', () {
    test('accepts 0x9000', () {
      expect(
        () => checkApduStatus(Uint8List.fromList([0x01, 0x90, 0x00])),
        returnsNormally,
      );
    });

    test('maps wrong-app SW', () {
      expect(
        () => checkApduStatus(Uint8List.fromList([0x6e, 0x00])),
        throwsA(
          isA<LedgerDeviceException>().having(
            (e) => e.message,
            'message',
            contains('XRP app'),
          ),
        ),
      );
    });

    test('maps user reject SW', () {
      expect(
        () => checkApduStatus(Uint8List.fromList([0x69, 0x85])),
        throwsA(
          isA<LedgerDeviceException>().having(
            (e) => e.message,
            'message',
            contains('Rejected'),
          ),
        ),
      );
    });

    test('apduPayload strips SW', () {
      final payload = apduPayload(Uint8List.fromList([0xaa, 0xbb, 0x90, 0x00]));
      expect(payload, [0xaa, 0xbb]);
    });
  });

  group('Ledger signature encoding', () {
    test('accepts canonical DER ECDSA signature', () {
      expect(
        isCanonicalLedgerSignature([
          0x30,
          0x06,
          0x02,
          0x01,
          0x01,
          0x02,
          0x01,
          0x01,
        ]),
        isTrue,
      );
    });

    test('rejects malformed and non-canonical signatures', () {
      expect(isCanonicalLedgerSignature([0x30, 0x01, 0x02]), isFalse);
      expect(
        isCanonicalLedgerSignature([
          0x30,
          0x08,
          0x02,
          0x02,
          0x00,
          0x01,
          0x02,
          0x01,
          0x01,
        ]),
        isFalse,
      );
    });
  });

  group('WalletAccount.canSign with Ledger checkbox', () {
    WalletAccount base({required WalletKind kind, bool useLedger = false}) {
      return WalletAccount(
        id: 'w1',
        label: 'Test',
        address: 'rHsMGQEkVNJmpGWs8XUBoTBiAAbwxZN5v3',
        kind: kind,
        preferredNetwork: NetworkId.mainnet,
        importMethod: kind == WalletKind.watchOnly
            ? ImportMethod.addressOnly
            : ImportMethod.mnemonic,
        createdAt: DateTime.utc(2026, 1, 1),
        useLedger: useLedger,
      );
    }

    test('watch-only without Ledger cannot send', () {
      expect(base(kind: WalletKind.watchOnly).canSign, isFalse);
    });

    test('watch-only with Ledger checkbox can send', () {
      expect(base(kind: WalletKind.watchOnly, useLedger: true).canSign, isTrue);
    });

    test('signing wallet can always send', () {
      expect(base(kind: WalletKind.signing).canSign, isTrue);
      expect(base(kind: WalletKind.signing, useLedger: true).canSign, isTrue);
    });
  });

  group('LedgerXrpDevice.userFacingError', () {
    test('StateError message is passed through cleanly', () {
      final msg = LedgerXrpDevice.userFacingError(
        StateError('Ledger path mismatch'),
      );
      expect(msg, 'Ledger path mismatch');
    });

    test('LedgerDeviceException surfaces message only', () {
      final msg = LedgerXrpDevice.userFacingError(
        LedgerDeviceException('USB permission denied', step: 'open'),
      );
      expect(msg, 'USB permission denied');
    });
  });
}
