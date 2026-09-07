import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_amounts.dart';

/// Golden field construction for the transactions the Trade screen builds.
/// The build closures here are byte-for-byte the ones in
/// `trade_dashboard_screen.dart` (`_createLimitOrder`, `_cancel`).
void main() {
  // Ripple genesis family seed — golden address used across the crypto tests.
  const seed = 'snoPBrXtMeMyMHUVTgbuqAfg1SUTb';
  const account = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';
  const issuer = 'rMxCKbEDwqr76QuheSUMdEGf4B9xJ8m5De';

  final pubHex = PaymentService.privateKeyFromSecret(
    seed,
    expectedAddress: account,
  ).getPublic().toHex();

  test('OfferCreate: sell 10 XRP, buy 25 USD — exact taker fields', () {
    final tx = OfferCreate(
      account: account,
      takerGets: TradeAmounts.offerAmount('10', 'XRP', ''),
      takerPays: TradeAmounts.offerAmount('25', 'USD', issuer),
      signer: XRPLSignature.signer(pubHex),
    );
    final json = tx.toJson();

    expect(json['transaction_type'], 'OfferCreate');
    expect(json['account'], account);
    // takerGets is the asset being given up: 10 XRP as integer drops.
    expect(json['taker_gets'], '10000000');
    // takerPays is the asset wanted, carrying its issuer explicitly.
    expect(json['taker_pays'], {
      'currency': 'USD',
      'issuer': issuer,
      'value': '25',
    });
    // No passive / immediate-or-cancel flag is set by this path.
    expect(json.containsKey('flags'), isFalse);
    expect(json.containsKey('expiration'), isFalse);
  });

  test('OfferCreate: sell issued, buy XRP — sides swap correctly', () {
    final tx = OfferCreate(
      account: account,
      takerGets: TradeAmounts.offerAmount('25.5', 'USD', issuer),
      takerPays: TradeAmounts.offerAmount('40', 'XRP', ''),
      signer: XRPLSignature.signer(pubHex),
    );
    final json = tx.toJson();
    expect(json['taker_gets'], {
      'currency': 'USD',
      'issuer': issuer,
      'value': '25.5',
    });
    expect(json['taker_pays'], '40000000');
  });

  test('OfferCancel: only account + offer_sequence, no flags', () {
    final tx = OfferCancel(
      account: account,
      offerSequence: 42,
      signer: XRPLSignature.signer(pubHex),
    );
    final json = tx.toJson();
    expect(json['transaction_type'], 'OfferCancel');
    expect(json['account'], account);
    expect(json['offer_sequence'], 42);
    expect(json.containsKey('flags'), isFalse);
  });

  test('OfferCreate is a SubmittableTransaction the guarded path accepts', () {
    final tx = OfferCreate(
      account: account,
      takerGets: TradeAmounts.offerAmount('1', 'XRP', ''),
      takerPays: TradeAmounts.offerAmount('1', 'USD', issuer),
      signer: XRPLSignature.signer(pubHex),
    );
    expect(tx, isA<SubmittableTransaction>());
  });
}
