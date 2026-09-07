// Raw account_offers response for rippled's canonical ledger field names.
// ignore: implementation_imports
import 'package:xrpl_dart/src/rpc/core/methods_impl.dart';
// ignore: implementation_imports
import 'package:xrpl_dart/src/rpc/methods/methods.dart';
// ignore: implementation_imports
import 'package:xrpl_dart/src/rpc/models/models.dart';

class RichListAccountOffersRequest
    extends XRPLedgerRequest<Map<String, dynamic>, Map<String, dynamic>> {
  RichListAccountOffersRequest({required this.account, this.limit})
    : super(ledgerIndex: XRPLLedgerIndex.validated);
  final String account;
  final int? limit;

  @override
  String get method => XRPRequestMethod.accountOffers;

  @override
  Map<String, dynamic> toJson() => {'account': account, 'limit': limit};

  @override
  Map<String, dynamic> onResonse(Map<String, dynamic> result) => result;
}
