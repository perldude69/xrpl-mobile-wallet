import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/trade/amm_pool.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';

AmmPoolSnapshot _pool({
  String xrp = '1000',
  String rlusd = '1000',
  int fee = 0,
}) {
  return AmmPoolSnapshot(
    account: 'rPn7kHwycXzS5XNj167CnKwC2t82yAAdNW',
    xrpReserve: TradeDecimal.parse(xrp),
    rlusdReserve: TradeDecimal.parse(rlusd),
    tradingFee: fee,
    ledgerIndex: 1,
  );
}

void main() {
  test('spot is RLUSD per XRP', () {
    expect(_pool(xrp: '2', rlusd: '1').spot.toString(), '0.5');
  });

  test('fee 501 is 0.501%', () {
    expect(_pool(fee: 501).feePercentLabel, '0.501%');
  });

  test('spotInsideSpread is strict', () {
    final pool = _pool(xrp: '1', rlusd: '1');
    expect(
      pool.spotInsideSpread(
        bestBid: TradeDecimal.parse('0.9'),
        bestAsk: TradeDecimal.parse('1.1'),
      ),
      isTrue,
    );
    expect(
      pool.spotInsideSpread(
        bestBid: TradeDecimal.parse('1.1'),
        bestAsk: TradeDecimal.parse('1.2'),
      ),
      isFalse,
    );
  });

  test('zero-fee AMM-only swap matches constant product', () {
    final out = _pool().quoteOutForXrpIn(TradeDecimal.parse('10'));
    // 1000 * 10 / 1010
    expect(out.toString(), startsWith('9.90099'));
  });
}
