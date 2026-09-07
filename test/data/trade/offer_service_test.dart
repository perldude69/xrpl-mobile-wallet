import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/data/trade/offer_service.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_draft.dart';
import 'package:xrpl_mobile_wallet/domain/trade/slippage.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';

/// Exact `OfferCreate` / `OfferCancel` field construction.
///
/// The submitted transaction is what actually moves money, so the fields are
/// pinned here rather than trusted to read correctly.
void main() {
  // Ripple genesis family seed — golden address used across the crypto tests.
  const seed = 'snoPBrXtMeMyMHUVTgbuqAfg1SUTb';
  const account = 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh';

  final pubHex = PaymentService.privateKeyFromSecret(
    seed,
    expectedAddress: account,
  ).getPublic().toHex();

  final pair = TradePair.forNetwork(NetworkId.mainnet);
  TradeDecimal d(String v) => TradeDecimal.parse(v);

  group('limit order — selling XRP for RLUSD', () {
    final draft = LimitOrderDraft(
      pair: pair,
      side: TradeSide.sell,
      baseAmount: d('100'),
      rate: TradeRate.parse('2.5'),
    );

    test('taker fields carry drops for XRP and the issuer for RLUSD', () {
      final json = OfferService.buildOfferCreate(
        account: account,
        draft: draft,
        publicKeyHex: pubHex,
      ).toJson();

      expect(json['transaction_type'], 'OfferCreate');
      expect(json['account'], account);
      expect(json['taker_gets'], '100000000');
      expect(json['taker_pays'], {
        'currency': Rlusd.currencyHex,
        'issuer': Rlusd.mainnetIssuer,
        'value': '250',
      });
    });

    test('a resting order sets no time-in-force flag', () {
      expect(OfferService.flagsFor(draft), isEmpty);
      final json = OfferService.buildOfferCreate(
        account: account,
        draft: draft,
        publicKeyHex: pubHex,
      ).toJson();
      expect(json.containsKey('expiration'), isFalse);
    });
  });

  test('buying XRP swaps the taker sides', () {
    final json = OfferService.buildOfferCreate(
      account: account,
      draft: LimitOrderDraft(
        pair: pair,
        side: TradeSide.buy,
        baseAmount: d('40'),
        rate: TradeRate.parse('2.5'),
      ),
      publicKeyHex: pubHex,
    ).toJson();

    // Buying XRP: you give RLUSD and want XRP.
    expect(json['taker_gets'], {
      'currency': Rlusd.currencyHex,
      'issuer': Rlusd.mainnetIssuer,
      'value': '100',
    });
    expect(json['taker_pays'], '40000000');
  });

  group('flags', () {
    MarketOrderDraft market(TimeInForce tif) => MarketOrderDraft(
      pair: pair,
      side: TradeSide.sell,
      baseAmount: d('100'),
      referenceRate: TradeRate.parse('2'),
      slippage: Slippage.percent('1'),
      timeInForce: tif,
    );

    test('immediate-or-cancel', () {
      expect(OfferService.flagsFor(market(TimeInForce.immediateOrCancel)), [
        OfferCreateFlag.tfImmediateOrCancel.value,
      ]);
    });

    test('fill-or-kill', () {
      expect(OfferService.flagsFor(market(TimeInForce.fillOrKill)), [
        OfferCreateFlag.tfFillOrKill.value,
      ]);
    });

    test('tfSell is set only when the draft asks for it', () {
      final plain = LimitOrderDraft(
        pair: pair,
        side: TradeSide.sell,
        baseAmount: d('100'),
        rate: TradeRate.parse('2'),
      );
      final sellAll = LimitOrderDraft(
        pair: pair,
        side: TradeSide.sell,
        baseAmount: d('100'),
        rate: TradeRate.parse('2'),
        sellAll: true,
      );
      expect(OfferService.flagsFor(plain), isEmpty);
      expect(OfferService.flagsFor(sellAll), [OfferCreateFlag.tfSell.value]);
    });

    test('a market order combines its time-in-force with nothing else', () {
      final draft = market(TimeInForce.immediateOrCancel);
      expect(draft.sellAll, isFalse);
      expect(OfferService.flagsFor(draft).length, 1);
    });
  });

  group('expiration', () {
    test('is written in Ripple-epoch seconds, not Unix seconds', () {
      final expiry = DateTime.utc(2026, 1, 1);
      final json = OfferService.buildOfferCreate(
        account: account,
        draft: LimitOrderDraft(
          pair: pair,
          side: TradeSide.sell,
          baseAmount: d('100'),
          rate: TradeRate.parse('2'),
          expiration: expiry,
        ),
        publicKeyHex: pubHex,
      ).toJson();

      final expected = expiry.difference(DateTime.utc(2000, 1, 1)).inSeconds;
      expect(json['expiration'], expected);
      // A Unix timestamp would be ~946_684_800 larger; getting this wrong
      // would set an expiry 30 years out.
      expect(json['expiration'], isNot(expiry.millisecondsSinceEpoch ~/ 1000));
    });

    test('is omitted when the draft has none', () {
      final json = OfferService.buildOfferCreate(
        account: account,
        draft: LimitOrderDraft(
          pair: pair,
          side: TradeSide.sell,
          baseAmount: d('100'),
          rate: TradeRate.parse('2'),
        ),
        publicKeyHex: pubHex,
      ).toJson();
      expect(json.containsKey('expiration'), isFalse);
    });
  });

  group('buildOfferCreateFromAmounts', () {
    test('submits the reviewed amounts unchanged', () {
      final amounts = TakerAmounts(
        getsAsset: TradeAsset.xrp,
        getsValue: d('12.345678'),
        paysAsset: pair.quote,
        paysValue: d('30.123456789012345'),
      );
      final json = OfferService.buildOfferCreateFromAmounts(
        account: account,
        amounts: amounts,
        publicKeyHex: pubHex,
      ).toJson();

      expect(json['taker_gets'], '12345678');
      expect((json['taker_pays'] as Map)['value'], '30.123456789012345');
      expect(json.containsKey('flags'), isFalse);
    });
  });

  test('OfferCancel names the sequence to remove', () {
    final json = OfferService.buildOfferCancel(
      account: account,
      offerSequence: 42,
      publicKeyHex: pubHex,
    ).toJson();

    expect(json['transaction_type'], 'OfferCancel');
    expect(json['account'], account);
    expect(json['offer_sequence'], 42);
  });
}
