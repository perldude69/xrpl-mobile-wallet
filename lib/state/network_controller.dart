import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/data/endpoints/endpoint_preferences.dart';
import 'package:xrpl_mobile_wallet/data/watcher/account_watcher.dart';

export 'package:xrpl_mobile_wallet/config/network_id.dart';

/// Connection lifecycle for the ledger RPC client.
///
/// Named to avoid clashing with Flutter's [ConnectionState].
enum NetworkConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class NetworkState {
  const NetworkState({
    required this.network,
    required this.connection,
    this.errorMessage,
    this.activeNodeHost,
    this.activeNodeUrl,
  });

  final NetworkId network;
  final NetworkConnectionState connection;
  final String? errorMessage;

  /// Hostname of the active JSON-RPC HTTP node (balances / send), if known.
  final String? activeNodeHost;

  /// Full URL of the active JSON-RPC HTTP node, if known.
  final String? activeNodeUrl;

  bool get isConnected => connection == NetworkConnectionState.connected;

  NetworkState copyWith({
    NetworkId? network,
    NetworkConnectionState? connection,
    String? errorMessage,
    bool clearError = false,
    String? activeNodeHost,
    String? activeNodeUrl,
    bool clearActiveNode = false,
  }) {
    return NetworkState(
      network: network ?? this.network,
      connection: connection ?? this.connection,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeNodeHost:
          clearActiveNode ? null : (activeNodeHost ?? this.activeNodeHost),
      activeNodeUrl:
          clearActiveNode ? null : (activeNodeUrl ?? this.activeNodeUrl),
    );
  }
}

class NetworkController extends StateNotifier<NetworkState> {
  NetworkController(
    this._client, {
    AccountWatcher? watcher,
    EndpointPreferences? endpoints,
  })  : _watcher = watcher ?? AccountWatcher(),
        _endpoints = endpoints ?? EndpointPreferences(),
        super(
          const NetworkState(
            network: NetworkId.mainnet,
            connection: NetworkConnectionState.disconnected,
          ),
        );

  final XrplRpcClient _client;
  final AccountWatcher _watcher;
  final EndpointPreferences _endpoints;

  XrplRpcClient get client => _client;
  EndpointPreferences get endpointPreferences => _endpoints;

  /// Switch active network. Disconnects first; does not auto-connect.
  Future<void> setNetwork(NetworkId network) async {
    if (state.network == network &&
        state.connection == NetworkConnectionState.disconnected) {
      return;
    }
    await disconnect();
    state = NetworkState(
      network: network,
      connection: NetworkConnectionState.disconnected,
    );
    try {
      await _watcher.updateNetwork(network);
    } catch (_) {}
  }

  Future<void> connect({NetworkId? network}) async {
    final target = network ?? state.network;
    state = NetworkState(
      network: target,
      connection: NetworkConnectionState.connecting,
    );
    try {
      final urls = await _endpoints.httpUrls(target);
      await _client.connect(target, httpUrls: urls);
      state = NetworkState(
        network: target,
        connection: NetworkConnectionState.connected,
        activeNodeHost: _client.activeHttpHost,
        activeNodeUrl: _client.activeHttpUrl,
      );
    } catch (e) {
      await _client.disconnect();
      state = NetworkState(
        network: target,
        connection: NetworkConnectionState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    state = state.copyWith(
      connection: NetworkConnectionState.disconnected,
      clearError: true,
      clearActiveNode: true,
    );
  }

  /// Apply new mainnet HTTP endpoint selection, then reconnect if needed.
  Future<void> setHttpEndpointIds(List<String> ids) async {
    await _endpoints.setHttpIds(ids);
    if (state.network == NetworkId.mainnet &&
        state.connection == NetworkConnectionState.connected) {
      await connect(network: NetworkId.mainnet);
    }
  }

  /// Apply new mainnet WSS endpoint selection and refresh watcher book.
  Future<void> setWssEndpointIds(List<String> ids) async {
    await _endpoints.setWssIds(ids);
    try {
      await _watcher.updateNetwork(state.network);
    } catch (_) {}
  }

  Future<void> _refreshAfterCustomChange(EndpointKind kind) async {
    if (kind == EndpointKind.http) {
      if (state.network == NetworkId.mainnet &&
          state.connection == NetworkConnectionState.connected) {
        await connect(network: NetworkId.mainnet);
      }
      return;
    }
    try {
      await _watcher.updateNetwork(state.network);
    } catch (_) {}
  }

  Future<CustomEndpoint> addCustomEndpoint({
    required String label,
    required EndpointKind kind,
    required String url,
  }) async {
    final created = await _endpoints.addCustom(
      label: label,
      kind: kind,
      url: url,
    );
    await _refreshAfterCustomChange(kind);
    return created;
  }

  Future<CustomEndpoint> updateCustomEndpoint(CustomEndpoint endpoint) async {
    final updated = await _endpoints.updateCustom(endpoint);
    await _refreshAfterCustomChange(endpoint.kind);
    return updated;
  }

  Future<void> removeCustomEndpoint(CustomEndpoint endpoint) async {
    await _endpoints.removeCustom(endpoint.id);
    await _refreshAfterCustomChange(endpoint.kind);
  }

  Future<void> moveCustomEndpoint({
    required CustomEndpoint endpoint,
    required int delta,
  }) async {
    await _endpoints.moveCustom(
      id: endpoint.id,
      kind: endpoint.kind,
      delta: delta,
    );
    await _refreshAfterCustomChange(endpoint.kind);
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }
}

final xrplRpcClientProvider = Provider<XrplRpcClient>((ref) {
  final client = XrplRpcClient();
  ref.onDispose(() {
    client.disconnect();
  });
  return client;
});

final endpointPreferencesProvider = Provider<EndpointPreferences>((ref) {
  return EndpointPreferences();
});

final networkControllerProvider =
    StateNotifierProvider<NetworkController, NetworkState>((ref) {
  return NetworkController(
    ref.watch(xrplRpcClientProvider),
    endpoints: ref.watch(endpointPreferencesProvider),
  );
});
