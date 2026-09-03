import 'package:http/http.dart' as http;
import 'package:xrpl_dart/xrpl_dart.dart';

/// JSON-RPC HTTP transport for [XRPProvider], adapted from xrpl_dart examples.
class RpcHttpClient with XRPServiceProvider {
  RpcHttpClient(
    this.url,
    this.client, {
    this.defaultTimeout = const Duration(seconds: 30),
  });

  @override
  final String url;
  final http.Client client;
  final Duration defaultTimeout;

  @override
  Future<XRPServiceResponse> doRequest(
    XRPRequestDetails params, {
    Duration? timeout,
  }) async {
    if (params.requestMethod.isPost) {
      final response = await client
          .post(
            params.encodeUrl(url),
            headers: params.headers,
            body: params.encodeBody(),
          )
          .timeout(timeout ?? defaultTimeout);
      return params.toResponse(
        response.bodyBytes,
        statusCode: response.statusCode,
      );
    }
    final response = await client
        .get(params.encodeUrl(url), headers: params.headers)
        .timeout(timeout ?? defaultTimeout);
    return params.toResponse(
      response.bodyBytes,
      statusCode: response.statusCode,
    );
  }
}
