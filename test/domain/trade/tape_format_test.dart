import 'package:flutter_test/flutter_test.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/tape_format.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';

void main() {
  test('five significant digits at different magnitudes', () {
    expect(formatTapeDecimal(TradeDecimal.parse('0.901234567')), '0.90123');
    expect(formatTapeDecimal(TradeDecimal.parse('1.07420000')), '1.0742');
    expect(formatTapeDecimal(TradeDecimal.parse('12.345678')), '12.345');
    expect(formatTapeDecimal(TradeDecimal.parse('127.99111')), '127.99');
  });

  test('tiny spread uses scientific notation', () {
    expect(formatTapeDecimal(TradeDecimal.parse('0.00004123')), '4.123e-5');
  });

  test('volume share is all bid or all ask when one side is empty', () {
    final bidOnly = BookSnapshot(
      ledgerIndex: 1,
      bids: [
        BookLevel(
          rate: TradeDecimal.parse('1'),
          baseAmount: TradeDecimal.parse('10'),
          quoteAmount: TradeDecimal.parse('10'),
        ),
      ],
      asks: const [],
    );
    expect(tapeBidVolumeShareThousandths(bidOnly), 1000);

    final empty = const BookSnapshot(ledgerIndex: 1, bids: [], asks: []);
    expect(tapeBidVolumeShareThousandths(empty), 500);
  });
}
