import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/rlusd.dart';
import 'package:xrpl_mobile_wallet/domain/trade/amm_pool.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';

/// Reads the official XRP/RLUSD AMM. Missing or frozen-unavailable pools
/// return null — Trade still shows the CLOB.
class AmmInfoService {
  AmmInfoService(this._client);

  final XrplRpcClient _client;

  Future<AmmPoolSnapshot?> fetch(TradePair pair) async {
    final quote = pair.quote;
    if (quote.issuer == null) return null;
    try {
      final rpc = _client.requireProvider();
      final result = await rpc.request(
        XRPRequestAMMInfo(
          asset: XRPCurrency(),
          asset2: IssuedCurrency(
            currency: quote.currency,
            issuer: quote.issuer!,
          ),
        ),
      );
      if (result.validated == false) return null;
      final parsed = _fromResult(result, pair);
      return parsed;
    } catch (_) {
      return null;
    }
  }

  AmmPoolSnapshot? _fromResult(AMMInfoResult result, TradePair pair) {
    final amm = result.amm;
    final xrp = _asXrp(amm.amount) ?? _asXrp(amm.amount2);
    final rlusd = _asRlusd(amm.amount, pair) ?? _asRlusd(amm.amount2, pair);
    if (xrp == null || rlusd == null || xrp.isZero || rlusd.isZero) {
      return null;
    }
    final quoteIsSecond = _asRlusd(amm.amount2, pair) != null;
    final quoteFrozen = quoteIsSecond
        ? (amm.asset2Frozen == true)
        : (amm.assetFrozen == true);
    return AmmPoolSnapshot(
      account: amm.account,
      xrpReserve: xrp,
      rlusdReserve: rlusd,
      tradingFee: amm.tradingFee,
      ledgerIndex: result.ledgerIndex ?? 0,
      quoteFrozen: quoteFrozen,
    );
  }

  TradeDecimal? _asXrp(BaseAmount amount) {
    if (amount is! XRPAmount) return null;
    return TradeDecimal.parse(XrpAmount.dropsToXrp(amount.value.toString()));
  }

  TradeDecimal? _asRlusd(BaseAmount amount, TradePair pair) {
    if (amount is! IssuedCurrencyAmount) return null;
    if (!Rlusd.isCurrency(amount.currency)) return null;
    if (amount.issuer != pair.quote.issuer) return null;
    return TradeDecimal.tryParse(amount.value);
  }
}
