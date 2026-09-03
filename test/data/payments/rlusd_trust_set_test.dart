import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';

void main() {
  // Ripple genesis family seed — golden address in wallet_importer_test.
  const seed = 'snoPBrXtMeMyMHUVTgbuqAfg1SUTb';
  const address = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';

  test('RLUSD TrustSet JSON is official issuer, hex, limit, NoRipple', () {
    final pk = PaymentService.privateKeyFromSecret(seed, expectedAddress: address);
    final pubHex = pk.getPublic().toHex();
    final tx = PaymentService().buildRlusdTrustSet(
      fromAddress: address,
      network: NetworkId.mainnet,
      publicKeyHex: pubHex,
    );
    final json = tx.toJson();

    expect(json['transaction_type'], 'TrustSet');
    expect(json['account'], address);
    expect(json['limit_amount'], {
      'currency': Rlusd.currencyHex,
      'issuer': Rlusd.mainnetIssuer,
      'value': Rlusd.limit,
    });
    expect(json['flags'], TrustSetFlag.tfSetNoRipple.id);
  });

  test('testnet TrustSet uses the testnet issuer', () {
    final pk = PaymentService.privateKeyFromSecret(seed, expectedAddress: address);
    final tx = PaymentService().buildRlusdTrustSet(
      fromAddress: address,
      network: NetworkId.testnet,
      publicKeyHex: pk.getPublic().toHex(),
    );
    expect(tx.toJson()['limit_amount']['issuer'], Rlusd.testnetIssuer);
  });
}
