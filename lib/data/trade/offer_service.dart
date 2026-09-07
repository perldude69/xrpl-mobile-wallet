import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_draft.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_amounts.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';

/// Builds and submits `OfferCreate` / `OfferCancel`.
///
/// Signing and submission go through [PaymentService.signAndSubmitTransaction]
/// rather than being reimplemented here, deliberately: the fee cap and the
/// `expectedAddress` check in that method are the single chokepoint every
/// signed transaction in this app passes through, and a second signing path
/// would be a second place to forget them.
///
/// Holds no secrets. The caller reads the secret from `KeyVault` at the call
/// site and passes it in; nothing is cached on this object.
class OfferService {
  OfferService({PaymentService? payments})
    : _payments = payments ?? PaymentService();

  final PaymentService _payments;

  /// Transaction flags for a draft's [TimeInForce] and `tfSell` choice.
  ///
  /// Exposed for the review screen and for tests: the flags are the difference
  /// between "fill what you can now and kill the rest" and "leave this resting
  /// on the book holding a reserve", which is not a detail a user should have
  /// to infer.
  static List<int> flagsFor(OrderDraft draft) => [
    switch (draft.timeInForce) {
      TimeInForce.immediateOrCancel =>
        OfferCreateFlag.tfImmediateOrCancel.value,
      TimeInForce.fillOrKill => OfferCreateFlag.tfFillOrKill.value,
      TimeInForce.resting => 0,
    },
    if (draft.sellAll) OfferCreateFlag.tfSell.value,
  ]..removeWhere((flag) => flag == 0);

  /// Build the `OfferCreate` for [draft]. Pure apart from the signer field, so
  /// tests can pin the exact submitted fields without a network.
  static OfferCreate buildOfferCreate({
    required String account,
    required OrderDraft draft,
    required String publicKeyHex,
  }) {
    final amounts = draft.takerAmounts();
    return OfferCreate(
      account: account,
      takerGets: TradeAmounts.offerAmount(
        amounts.getsValue.toString(),
        amounts.getsAsset.currency,
        amounts.getsAsset.issuer ?? '',
      ),
      takerPays: TradeAmounts.offerAmount(
        amounts.paysValue.toString(),
        amounts.paysAsset.currency,
        amounts.paysAsset.issuer ?? '',
      ),
      expiration: _rippleExpiration(draft.expiration),
      flags: flagsFor(draft),
      signer: XRPLSignature.signer(publicKeyHex),
    );
  }

  /// Build an `OfferCreate` from already-computed taker amounts.
  ///
  /// The path the current dashboard uses, where the amounts came straight from
  /// the user rather than from a rate. Kept separate so no code has to invent
  /// a rate just to place an order it already has both sides of.
  static OfferCreate buildOfferCreateFromAmounts({
    required String account,
    required TakerAmounts amounts,
    required String publicKeyHex,
    List<int> flags = const [],
    DateTime? expiration,
  }) => OfferCreate(
    account: account,
    takerGets: TradeAmounts.offerAmount(
      amounts.getsValue.toString(),
      amounts.getsAsset.currency,
      amounts.getsAsset.issuer ?? '',
    ),
    takerPays: TradeAmounts.offerAmount(
      amounts.paysValue.toString(),
      amounts.paysAsset.currency,
      amounts.paysAsset.issuer ?? '',
    ),
    expiration: _rippleExpiration(expiration),
    flags: flags.isEmpty ? null : flags,
    signer: XRPLSignature.signer(publicKeyHex),
  );

  static OfferCancel buildOfferCancel({
    required String account,
    required int offerSequence,
    required String publicKeyHex,
  }) => OfferCancel(
    account: account,
    offerSequence: offerSequence,
    signer: XRPLSignature.signer(publicKeyHex),
  );

  /// Sign and submit an `OfferCreate`.
  Future<PaymentSubmitResult> submitOfferCreate({
    required String secret,
    required String account,
    required XRPProvider rpc,
    required OrderDraft draft,
    String? expectedFeeDrops,
  }) => _payments.signAndSubmitTransaction(
    secret: secret,
    fromAddress: account,
    rpc: rpc,
    expectedFeeDrops: expectedFeeDrops,
    build: (pubHex) =>
        buildOfferCreate(account: account, draft: draft, publicKeyHex: pubHex),
  );

  /// Sign and submit an `OfferCreate` for amounts the user supplied directly.
  ///
  /// The path the current dashboard takes. It still goes through
  /// [PaymentService.signAndSubmitTransaction], so the fee cap and address
  /// check apply exactly as they do to a rate-derived order.
  Future<PaymentSubmitResult> submitOfferCreateFromAmounts({
    required String secret,
    required String account,
    required XRPProvider rpc,
    required TakerAmounts amounts,
    List<int> flags = const [],
    DateTime? expiration,
    String? expectedFeeDrops,
  }) => _payments.signAndSubmitTransaction(
    secret: secret,
    fromAddress: account,
    rpc: rpc,
    expectedFeeDrops: expectedFeeDrops,
    build: (pubHex) => buildOfferCreateFromAmounts(
      account: account,
      amounts: amounts,
      publicKeyHex: pubHex,
      flags: flags,
      expiration: expiration,
    ),
  );

  /// Sign and submit an `OfferCancel`, freeing the offer's owner reserve.
  Future<PaymentSubmitResult> submitOfferCancel({
    required String secret,
    required String account,
    required XRPProvider rpc,
    required int offerSequence,
    String? expectedFeeDrops,
  }) => _payments.signAndSubmitTransaction(
    secret: secret,
    fromAddress: account,
    rpc: rpc,
    expectedFeeDrops: expectedFeeDrops,
    build: (pubHex) => buildOfferCancel(
      account: account,
      offerSequence: offerSequence,
      publicKeyHex: pubHex,
    ),
  );

  /// Sign and submit an offer using a Ledger. The caller owns the USB session
  /// and supplies a callback for exactly one device signature.
  Future<PaymentSubmitResult> submitOfferCreateWithLedger({
    required String account,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    required TakerAmounts amounts,
    List<int> flags = const [],
    DateTime? expiration,
    String? expectedFeeDrops,
  }) => _payments.signAndSubmitWithLedgerKeys(
    fromAddress: account,
    rpc: rpc,
    publicKeyHex: publicKeyHex,
    signTransactionBlob: signTransactionBlob,
    expectedFeeDrops: expectedFeeDrops,
    build: (pubHex) => buildOfferCreateFromAmounts(
      account: account,
      amounts: amounts,
      publicKeyHex: pubHex,
      flags: flags,
      expiration: expiration,
    ),
  );

  Future<PaymentSubmitResult> submitOfferCreateDraftWithLedger({
    required String account,
    required XRPProvider rpc,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    required OrderDraft draft,
    String? expectedFeeDrops,
  }) => _payments.signAndSubmitWithLedgerKeys(
    fromAddress: account,
    rpc: rpc,
    publicKeyHex: publicKeyHex,
    signTransactionBlob: signTransactionBlob,
    expectedFeeDrops: expectedFeeDrops,
    build: (pubHex) =>
        buildOfferCreate(account: account, draft: draft, publicKeyHex: pubHex),
  );

  /// Ledger equivalent of [submitOfferCancel].
  Future<PaymentSubmitResult> submitOfferCancelWithLedger({
    required String account,
    required XRPProvider rpc,
    required int offerSequence,
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    String? expectedFeeDrops,
  }) => _payments.signAndSubmitWithLedgerKeys(
    fromAddress: account,
    rpc: rpc,
    publicKeyHex: publicKeyHex,
    signTransactionBlob: signTransactionBlob,
    expectedFeeDrops: expectedFeeDrops,
    build: (pubHex) => buildOfferCancel(
      account: account,
      offerSequence: offerSequence,
      publicKeyHex: pubHex,
    ),
  );

  /// XRPL `Expiration` is seconds since 2000-01-01 UTC, not the Unix epoch.
  static int? _rippleExpiration(DateTime? at) {
    if (at == null) return null;
    final seconds = at.toUtc().difference(DateTime.utc(2000, 1, 1)).inSeconds;
    return seconds > 0 ? seconds : null;
  }
}
