import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_draft.dart';
import 'package:xrpl_mobile_wallet/domain/trade/slippage.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';

void main() {
  final pair = TradePair.forNetwork(NetworkId.mainnet);
  TradeDecimal d(String v) => TradeDecimal.parse(v);
  TradeRate rate(String v) => TradeRate.parse(v);

  group('construction', () {
    test('percent, basis points and fraction agree', () {
      expect(Slippage.percent('0.5').fraction, d('0.005'));
      expect(Slippage.basisPoints(50).fraction, d('0.005'));
      expect(Slippage.fraction(d('0.005')).fraction, d('0.005'));
    });

    test('percentLabel renders back for review copy', () {
      expect(Slippage.percent('0.5').percentLabel, '0.5');
      expect(Slippage.basisPoints(100).percentLabel, '1');
      expect(Slippage.percent('0').toString(), '0%');
    });

    test('negative slippage is refused', () {
      expect(() => Slippage.percent('-1'), throwsArgumentError);
    });

    test('an absurd slippage is refused, not merely discouraged', () {
      // A typo turning 0.5% into 5000% must not be signable.
      expect(() => Slippage.percent('5000'), throwsArgumentError);
      expect(() => Slippage.percent('51'), throwsArgumentError);
      expect(Slippage.percent('50').fraction, d('0.5'));
    });
  });

  group('limitRate — selling XRP', () {
    test('the limit is a floor below the reference', () {
      final limit = Slippage.percent(
        '1',
      ).limitRate(reference: rate('2'), side: TradeSide.sell);
      expect(limit.quotePerBase, d('1.98'));
    });

    test('rounding keeps the bound strict, never looser', () {
      // 1/3 × 0.99 does not terminate; the floor must round up.
      final reference = rate('0.3333333333333333333');
      final limit = Slippage.percent(
        '1',
      ).limitRate(reference: reference, side: TradeSide.sell);
      final exact = reference.quotePerBase * d('0.99');
      expect(
        limit.quotePerBase >= exact,
        isTrue,
        reason: 'a sell floor must never drop below the stated bound',
      );
    });

    test('zero slippage is the reference rate itself', () {
      final limit = Slippage.percent(
        '0',
      ).limitRate(reference: rate('2.5'), side: TradeSide.sell);
      expect(limit.quotePerBase, d('2.5'));
    });
  });

  group('limitRate — buying XRP', () {
    test('the limit is a ceiling above the reference', () {
      final limit = Slippage.percent(
        '1',
      ).limitRate(reference: rate('2'), side: TradeSide.buy);
      expect(limit.quotePerBase, d('2.02'));
    });

    test('rounding keeps the ceiling strict, never looser', () {
      final reference = rate('0.3333333333333333333');
      final limit = Slippage.percent(
        '1',
      ).limitRate(reference: reference, side: TradeSide.buy);
      final exact = reference.quotePerBase * d('1.01');
      expect(
        limit.quotePerBase <= exact,
        isTrue,
        reason: 'a buy ceiling must never rise above the stated bound',
      );
    });
  });

  group('MarketOrderDraft', () {
    test('is immediate-or-cancel by default and never rests', () {
      final draft = MarketOrderDraft(
        pair: pair,
        side: TradeSide.sell,
        baseAmount: d('100'),
        referenceRate: rate('2'),
        slippage: Slippage.percent('1'),
      );
      expect(draft.timeInForce, TimeInForce.immediateOrCancel);
      expect(draft.sellAll, isFalse);
      expect(draft.expiration, isNull);
      expect(draft.orderTypeStorageValue, 'market');
    });

    test('applies its slippage bound to the taker amounts', () {
      final draft = MarketOrderDraft(
        pair: pair,
        side: TradeSide.sell,
        baseAmount: d('100'),
        referenceRate: rate('2'),
        slippage: Slippage.percent('1'),
      );
      final amounts = draft.takerAmounts();
      // Selling 100 XRP with a 1% bound: demand at least 198 RLUSD.
      expect(amounts.getsValue, d('100'));
      expect(amounts.paysValue, d('198'));
    });

    test('a worse bound demands less, in the right direction', () {
      TradeDecimal paysFor(String percent) => MarketOrderDraft(
        pair: pair,
        side: TradeSide.sell,
        baseAmount: d('100'),
        referenceRate: rate('2'),
        slippage: Slippage.percent(percent),
      ).takerAmounts().paysValue;

      expect(paysFor('0') > paysFor('1'), isTrue);
      expect(paysFor('1') > paysFor('5'), isTrue);
    });
  });

  group('LimitOrderDraft', () {
    test('rests, and carries its price and flags explicitly', () {
      final expiry = DateTime.utc(2030, 1, 1);
      final draft = LimitOrderDraft(
        pair: pair,
        side: TradeSide.sell,
        baseAmount: d('100'),
        rate: rate('2'),
        sellAll: true,
        expiration: expiry,
      );
      expect(draft.timeInForce, TimeInForce.resting);
      expect(draft.sellAll, isTrue);
      expect(draft.expiration, expiry);
      expect(draft.orderTypeStorageValue, 'limit');
      expect(draft.takerAmounts().paysValue, d('200'));
    });
  });
}
