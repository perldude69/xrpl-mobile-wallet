import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';

/// XRP ⇄ RLUSD rate vectors.
///
/// The invariant every case here defends: **the constructed offer's implied
/// rate is never worse than the rate that was asked for.** A drop of
/// under-fill is acceptable; a cent of over-pay is not.
void main() {
  final mainnet = TradePair.forNetwork(NetworkId.mainnet);
  TradeDecimal d(String v) => TradeDecimal.parse(v);
  TradeRate rate(String v) => TradeRate.parse(v);

  group('TradePair identity', () {
    test('base is XRP, quote is the official RLUSD line per network', () {
      expect(mainnet.base, TradeAsset.xrp);
      expect(mainnet.quote.currency, Rlusd.currencyHex);
      expect(mainnet.quote.issuer, Rlusd.mainnetIssuer);

      final testnet = TradePair.forNetwork(NetworkId.testnet);
      expect(testnet.quote.issuer, Rlusd.testnetIssuer);
      expect(testnet.quote.issuer, isNot(mainnet.quote.issuer));
    });

    test('given / received swap with the side', () {
      expect(mainnet.given(TradeSide.sell), mainnet.base);
      expect(mainnet.received(TradeSide.sell), mainnet.quote);
      expect(mainnet.given(TradeSide.buy), mainnet.quote);
      expect(mainnet.received(TradeSide.buy), mainnet.base);
    });

    test('an issued asset needs both a currency and an issuer', () {
      expect(
        () => TradeAsset.issued(currency: 'RLUSD', issuer: ''),
        throwsArgumentError,
      );
      expect(
        () => TradeAsset.issued(currency: '', issuer: 'rIssuer'),
        throwsArgumentError,
      );
    });

    test('a look-alike issuer is not the official asset', () {
      expect(
        mainnet.quote.matches(Rlusd.currencyHex, Rlusd.testnetIssuer),
        isFalse,
      );
      expect(
        mainnet.quote.matches(Rlusd.currencyHex, Rlusd.mainnetIssuer),
        isTrue,
      );
    });
  });

  group('TradeRate', () {
    test('a rate must be positive', () {
      expect(() => rate('0'), throwsArgumentError);
      expect(() => rate('-1'), throwsArgumentError);
    });

    test('inverse round-trips within its stated precision', () {
      expect(rate('2').basePerQuote.toString(), '0.5');
      expect(rate('0.5').basePerQuote.toString(), '2');
      // 1/3 is not representable; it must floor, never overstate.
      expect(rate('3').basePerQuote < d('0.333333333333333333334'), isTrue);
    });
  });

  group('takerAmounts — selling XRP for RLUSD', () {
    test('exact rate produces exact taker fields', () {
      final amounts = TradeRates.takerAmounts(
        pair: mainnet,
        side: TradeSide.sell,
        baseAmount: d('100'),
        rate: rate('2.5'),
      );
      // Selling: you give XRP, you want RLUSD.
      expect(amounts.getsAsset, mainnet.base);
      expect(amounts.getsValue.toString(), '100');
      expect(amounts.paysAsset, mainnet.quote);
      expect(amounts.paysValue.toString(), '250');
    });

    test(
      'the received side rounds UP, so the demanded rate is never worse',
      () {
        // 3 XRP × 0.333333333333333333 RLUSD/XRP = 0.999999999999999999.
        final amounts = TradeRates.takerAmounts(
          pair: mainnet,
          side: TradeSide.sell,
          baseAmount: d('3'),
          rate: rate('0.3333333333333333333'),
        );
        final effective = amounts.effectiveQuotePerBase(TradeSide.sell);
        expect(
          effective >= d('0.3333333333333333333'),
          isTrue,
          reason: 'a sell must never accept less than its limit rate',
        );
      },
    );

    test('an XRP amount finer than a drop is refused, not rounded', () {
      expect(
        () => TradeRates.takerAmounts(
          pair: mainnet,
          side: TradeSide.sell,
          baseAmount: d('1.0000001'),
          rate: rate('2'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('takerAmounts — buying XRP with RLUSD', () {
    test('sides swap: you give RLUSD and want XRP', () {
      final amounts = TradeRates.takerAmounts(
        pair: mainnet,
        side: TradeSide.buy,
        baseAmount: d('40'),
        rate: rate('2.5'),
      );
      expect(amounts.getsAsset, mainnet.quote);
      expect(amounts.getsValue.toString(), '100');
      expect(amounts.paysAsset, mainnet.base);
      expect(amounts.paysValue.toString(), '40');
    });

    test('the paid side rounds DOWN, so the paid rate is never worse', () {
      final amounts = TradeRates.takerAmounts(
        pair: mainnet,
        side: TradeSide.buy,
        baseAmount: d('3'),
        rate: rate('0.3333333333333333333'),
      );
      final effective = amounts.effectiveQuotePerBase(TradeSide.buy);
      expect(
        effective <= d('0.3333333333333333333'),
        isTrue,
        reason: 'a buy must never pay more than its limit rate',
      );
    });
  });

  group('precision limits', () {
    test('a derived RLUSD amount is capped at 15 significant figures', () {
      final amounts = TradeRates.takerAmounts(
        pair: mainnet,
        side: TradeSide.sell,
        baseAmount: d('1'),
        rate: rate('1.234567890123456789'),
      );
      final digits = amounts.paysValue.normalized.unscaled
          .abs()
          .toString()
          .length;
      expect(digits, lessThanOrEqualTo(TradeAsset.issuedSignificantFigures));
    });

    test('a tiny issued amount stays representable, it does not vanish', () {
      // The derived leg of this pair is always RLUSD, which has no fixed
      // scale, so a very small result keeps its significant figures rather
      // than flooring to zero.
      final amounts = TradeRates.takerAmounts(
        pair: mainnet,
        side: TradeSide.buy,
        baseAmount: d('0.000001'),
        rate: rate('0.0000000000000000000001'),
      );
      expect(amounts.getsValue.isPositive, isTrue);
    });

    test('XRP dust floors to zero drops — why the too-small guard exists', () {
      // The guard in takerAmounts is unreachable for XRP/RLUSD because the
      // derived leg is the issued one. It is pinned here on the XRP path so
      // the behaviour is known if a future pair puts XRP on the derived side.
      expect(
        TradeRates.roundToAsset(
          d('0.0000001'),
          TradeAsset.xrp,
          roundUp: false,
        ).isZero,
        isTrue,
      );
    });

    test('a non-positive amount is refused', () {
      for (final amount in ['0', '-1']) {
        expect(
          () => TradeRates.takerAmounts(
            pair: mainnet,
            side: TradeSide.sell,
            baseAmount: d(amount),
            rate: rate('2'),
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('executedRate', () {
    test('reports quote per base from the amounts that actually moved', () {
      expect(
        TradeRates.executedRate(
          baseAmount: d('100'),
          quoteAmount: d('250'),
        ).toString(),
        '2.5',
      );
    });

    test('signs do not matter — a delta may arrive either way round', () {
      expect(
        TradeRates.executedRate(baseAmount: d('-100'), quoteAmount: d('250')),
        TradeRates.executedRate(baseAmount: d('100'), quoteAmount: d('-250')),
      );
    });

    test('a zero base is not a rate', () {
      expect(
        TradeRates.executedRate(
          baseAmount: TradeDecimal.zero,
          quoteAmount: d('5'),
        ),
        isNull,
      );
    });
  });
}
