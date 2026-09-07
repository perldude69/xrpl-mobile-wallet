import 'dart:convert';

import 'package:http/http.dart' as http;

class TestnetFaucetService {
  const TestnetFaucetService();

  static final _uri = Uri.parse(
    'https://faucet.altnet.rippletest.net/accounts',
  );

  static Uri get rlusdFaucetUri => Uri.parse('https://tryrlusd.com/');

  static Uri get rlusdBithompFaucetUri =>
      Uri.parse('https://test.bithomp.com/faucet?currency=RLUSD');

  Future<void> fund(String address) async {
    final response = await http.post(
      _uri,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'destination': address}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Testnet faucet request failed');
    }
  }
}
