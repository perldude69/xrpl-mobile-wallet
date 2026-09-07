// The rich-list rippled proxy returns canonical ledger field names for
// book_offers (TakerGets/TakerPays), while xrpl_dart's model expects the
// lowercase account-offers shape. Keep this response raw and normalize it in
// the trade layer instead of weakening validation or depending on node quirks.
// ignore: implementation_imports
import 'package:xrpl_dart/src/rpc/core/methods_impl.dart';
// ignore: implementation_imports
import 'package:xrpl_dart/src/rpc/methods/methods.dart';
// ignore: implementation_imports
import 'package:xrpl_dart/src/rpc/models/models.dart';

class RichListBookOffersRequest
    extends XRPLedgerRequest<Map<String, dynamic>, Map<String, dynamic>> {
  RichListBookOffersRequest({
    required this.takerGets,
    required this.takerPays,
    this.limit,
  }) : super(ledgerIndex: XRPLLedgerIndex.validated);

  final Map<String, dynamic> takerGets;
  final Map<String, dynamic> takerPays;
  final int? limit;

  @override
  String get method => XRPRequestMethod.bookOffers;

  @override
  Map<String, dynamic> toJson() => {
    'taker_gets': takerGets,
    'taker_pays': takerPays,
    'limit': limit,
  };

  @override
  Map<String, dynamic> onResonse(Map<String, dynamic> result) => result;
}
