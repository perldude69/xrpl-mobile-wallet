enum NetworkId { mainnet, testnet }

extension NetworkIdX on NetworkId {
  String get label => switch (this) {
        NetworkId.mainnet => 'Mainnet',
        NetworkId.testnet => 'Testnet',
      };

  /// Preferred WebSocket URL (primary for this network).
  ///
  /// See [wssEndpoints] for ordered primary → public fallbacks.
  /// Separate from [defaultHttp] / [httpEndpoints] (JSON-RPC).
  String get defaultWss => wssEndpoints.first;

  /// Ordered WSS endpoints for the account watcher (and any other subscribe path).
  ///
  /// Connect attempts are made in list order; later entries are only used when
  /// earlier ones fail to open.
  ///
  /// Mainnet public catalog:
  /// 1. Public cluster (`xrplcluster.com`)
  /// 2. Ankr free public infra (`mainnet.xrpl-rpc.com`) — see xrpl-rpc.com
  ///
  /// Status UI shows host only (never a URL query string).
  List<String> get wssEndpoints => switch (this) {
        NetworkId.mainnet => const [
            'wss://xrplcluster.com',
            'wss://mainnet.xrpl-rpc.com',
          ],
        NetworkId.testnet => const [
            'wss://s.altnet.rippletest.net:51233',
          ],
      };

  /// Preferred JSON-RPC HTTP URL (primary for this network).
  String get defaultHttp => httpEndpoints.first;

  /// Ordered JSON-RPC HTTP endpoints for [XrplRpcClient] (balances, history, submit).
  ///
  /// Connect probes in list order and keeps the first that answers
  /// `server_info`. Mainnet public catalog:
  /// 1. Public cluster (`xrplcluster.com`)
  /// 2. Ankr free public infra (`mainnet.xrpl-rpc.com`) — https://xrpl-rpc.com
  List<String> get httpEndpoints => switch (this) {
        NetworkId.mainnet => const [
            'https://xrplcluster.com/',
            'https://mainnet.xrpl-rpc.com/',
          ],
        NetworkId.testnet => const [
            'https://s.altnet.rippletest.net:51234/',
          ],
      };
}

/// Parse watcher/address-book network name; unknown values default to mainnet.
NetworkId networkIdFromName(String name) {
  for (final id in NetworkId.values) {
    if (id.name == name) return id;
  }
  return NetworkId.mainnet;
}
