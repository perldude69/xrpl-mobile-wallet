import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xrpl_mobile_wallet/config/network_id.dart';
import 'package:xrpl_mobile_wallet/config/storage_keys.dart';

/// Transport for a custom mainnet node.
enum EndpointKind { http, wss }

/// A selectable JSON-RPC or WSS server option for mainnet (or fixed testnet).
class EndpointOption {
  const EndpointOption({
    required this.id,
    required this.label,
    required this.host,
    required this.url,
  });

  final String id;
  final String label;
  final String host;
  final String url;
}

/// User-defined mainnet node (HTTPS JSON-RPC or WSS).
class CustomEndpoint {
  const CustomEndpoint({
    required this.id,
    required this.label,
    required this.kind,
    required this.url,
  });

  final String id;
  final String label;
  final EndpointKind kind;
  final String url;

  /// Host only — never a query string (tokens stay off the status chip).
  String get host => EndpointUrl.hostOf(url);

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'url': url,
  };

  factory CustomEndpoint.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString() ?? EndpointKind.http.name;
    final kind = EndpointKind.values.firstWhere(
      (k) => k.name == kindName,
      orElse: () => EndpointKind.http,
    );
    return CustomEndpoint(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: kind,
      url: json['url']?.toString() ?? '',
    );
  }
}

/// URL rules and host-only display for public / custom nodes.
class EndpointUrl {
  EndpointUrl._();

  /// `null` when [url] is valid for [kind]; otherwise a short error string.
  static String? validate({required EndpointKind kind, required String url}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'Enter a URL';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return 'Enter a valid URL';
    switch (kind) {
      case EndpointKind.http:
        if (uri.scheme == 'http') {
          return 'HTTP endpoints must use https://';
        }
        if (uri.scheme != 'https') {
          return 'HTTP endpoints must use https://';
        }
      case EndpointKind.wss:
        if (uri.scheme == 'ws') {
          return 'WSS endpoints must use wss://';
        }
        if (uri.scheme != 'wss') {
          return 'WSS endpoints must use wss://';
        }
    }
    return null;
  }

  /// Hostname for status UI. Query parameters (including tokens) are dropped.
  static String hostOf(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return url;
  }
}

/// Catalog of known endpoints and user multi-select preferences.
///
/// Selected IDs are stored as ordered comma-separated lists. Empty built-in
/// selection falls back to the full catalog (not custom-only). Testnet is
/// fixed and not stored. Custom URLs persist as JSON in SharedPreferences.
class EndpointPreferences {
  EndpointPreferences({SharedPreferences? prefs, Uuid? uuid})
    : _prefs = prefs,
      _uuid = uuid ?? const Uuid();

  SharedPreferences? _prefs;
  final Uuid _uuid;

  /// Injected only during a trusted local build. Never commit the bearer
  /// token or show the query string in status UI.
  static const _wssToken = String.fromEnvironment('WSS_TOKEN');
  static const _defaultsMigrationKey = 'endpoint_defaults_migrated_v2';
  static String get _richListWssUrl => _wssToken.isEmpty
      ? 'wss://wss.rich-list.info'
      : 'wss://wss.rich-list.info/?token=$_wssToken';

  /// Mainnet HTTP JSON-RPC catalog (order = default preference).
  ///
  /// A neutral public cluster leads. `rpc.rich-list.info` is maintainer-operated
  /// and kept as an opt-in choice only — never the default primary, so a stock
  /// install does not route every address query and signed-transaction submit
  /// through a single first-party host (XRW-27).
  static const mainnetHttpCatalog = <EndpointOption>[
    EndpointOption(
      id: 'cluster',
      label: 'xrplcluster.com',
      host: 'xrplcluster.com',
      url: 'https://xrplcluster.com/',
    ),
    EndpointOption(
      id: 'ankr',
      label: 'xrpl-rpc.com (Ankr)',
      host: 'mainnet.xrpl-rpc.com',
      url: 'https://mainnet.xrpl-rpc.com/',
    ),
    EndpointOption(
      id: 'rich-list',
      label: 'rpc.rich-list.info (maintainer)',
      host: 'rpc.rich-list.info',
      url: 'https://rpc.rich-list.info/',
    ),
  ];

  /// Mainnet WSS catalog (public servers only).
  static final mainnetWssCatalog = <EndpointOption>[
    EndpointOption(
      id: 'cluster',
      label: 'xrplcluster.com',
      host: 'xrplcluster.com',
      url: 'wss://xrplcluster.com',
    ),
    EndpointOption(
      id: 'ankr',
      label: 'xrpl-rpc.com (Ankr)',
      host: 'mainnet.xrpl-rpc.com',
      url: 'wss://mainnet.xrpl-rpc.com',
    ),
    EndpointOption(
      id: 'rich-list',
      label: 'wss.rich-list.info (maintainer)',
      host: 'wss.rich-list.info',
      url: _richListWssUrl,
    ),
  ];

  /// Ids enabled on a stock install. Excludes `rich-list` (maintainer-operated):
  /// it is in the catalog for users who opt in, not in the default selection.
  static List<String> get defaultHttpIds => const ['rich-list'];

  static List<String> get defaultWssIds => const ['rich-list'];

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<String>> selectedHttpIds() async {
    final p = await _ensure();
    final raw = p.getString(StorageKeys.mainnetHttpEndpointIds);
    if (p.getBool(_defaultsMigrationKey) != true &&
        (raw == 'cluster,ankr' || raw == 'ankr,cluster')) {
      await p.setString(
        StorageKeys.mainnetHttpEndpointIds,
        defaultHttpIds.join(','),
      );
      await p.setBool(_defaultsMigrationKey, true);
      return defaultHttpIds;
    }
    return _parseIds(raw, defaultHttpIds, mainnetHttpCatalog.map((e) => e.id));
  }

  Future<List<String>> selectedWssIds() async {
    final p = await _ensure();
    final raw = p.getString(StorageKeys.mainnetWssEndpointIds);
    if (p.getBool(_defaultsMigrationKey) != true &&
        (raw == 'cluster,ankr' || raw == 'ankr,cluster')) {
      await p.setString(
        StorageKeys.mainnetWssEndpointIds,
        defaultWssIds.join(','),
      );
      await p.setBool(_defaultsMigrationKey, true);
      return defaultWssIds;
    }
    return _parseIds(raw, defaultWssIds, mainnetWssCatalog.map((e) => e.id));
  }

  /// Persist HTTP selection. [ids] must be non-empty; unknown ids dropped.
  /// An empty result falls back to the stock default set, not the raw catalog,
  /// so deselecting everything never silently re-enables the maintainer host.
  Future<List<String>> setHttpIds(List<String> ids) async {
    final cleaned = _clean(
      ids,
      mainnetHttpCatalog.map((e) => e.id),
      fallback: defaultHttpIds,
    );
    final p = await _ensure();
    await p.setString(StorageKeys.mainnetHttpEndpointIds, cleaned.join(','));
    await p.setBool(_defaultsMigrationKey, true);
    return cleaned;
  }

  /// Persist WSS selection. [ids] must be non-empty; unknown ids dropped.
  Future<List<String>> setWssIds(List<String> ids) async {
    final cleaned = _clean(
      ids,
      mainnetWssCatalog.map((e) => e.id),
      fallback: defaultWssIds,
    );
    final p = await _ensure();
    await p.setString(StorageKeys.mainnetWssEndpointIds, cleaned.join(','));
    await p.setBool(_defaultsMigrationKey, true);
    return cleaned;
  }

  Future<List<CustomEndpoint>> customEndpoints() async {
    final p = await _ensure();
    final raw = p.getString(StorageKeys.customEndpointsJson);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <CustomEndpoint>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final endpoint = CustomEndpoint.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (endpoint.id.isEmpty || endpoint.url.isEmpty) continue;
        if (EndpointUrl.validate(kind: endpoint.kind, url: endpoint.url) !=
            null) {
          continue;
        }
        out.add(endpoint);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<List<CustomEndpoint>> customOfKind(EndpointKind kind) async {
    return (await customEndpoints()).where((e) => e.kind == kind).toList();
  }

  /// Add a custom node. Throws [FormatException] on invalid URL.
  Future<CustomEndpoint> addCustom({
    required String label,
    required EndpointKind kind,
    required String url,
    String? id,
  }) async {
    final trimmed = url.trim();
    final error = EndpointUrl.validate(kind: kind, url: trimmed);
    if (error != null) throw FormatException(error);
    final host = EndpointUrl.hostOf(trimmed);
    final endpoint = CustomEndpoint(
      id: id ?? _uuid.v4(),
      label: label.trim().isEmpty ? host : label.trim(),
      kind: kind,
      url: trimmed,
    );
    final list = await customEndpoints();
    list.add(endpoint);
    await _saveCustom(list);
    return endpoint;
  }

  /// Replace a custom node by id. Throws [FormatException] on invalid URL.
  Future<CustomEndpoint> updateCustom(CustomEndpoint endpoint) async {
    final trimmed = endpoint.url.trim();
    final error = EndpointUrl.validate(kind: endpoint.kind, url: trimmed);
    if (error != null) throw FormatException(error);
    final host = EndpointUrl.hostOf(trimmed);
    final next = CustomEndpoint(
      id: endpoint.id,
      label: endpoint.label.trim().isEmpty ? host : endpoint.label.trim(),
      kind: endpoint.kind,
      url: trimmed,
    );
    final list = await customEndpoints();
    final index = list.indexWhere((e) => e.id == endpoint.id);
    if (index < 0) {
      list.add(next);
    } else {
      list[index] = next;
    }
    await _saveCustom(list);
    return next;
  }

  Future<void> removeCustom(String id) async {
    final list = await customEndpoints();
    list.removeWhere((e) => e.id == id);
    await _saveCustom(list);
  }

  /// Move a custom endpoint of [kind] by [delta] slots (−1 up, +1 down).
  Future<List<CustomEndpoint>> moveCustom({
    required String id,
    required EndpointKind kind,
    required int delta,
  }) async {
    final all = await customEndpoints();
    final kindIds = [
      for (final e in all)
        if (e.kind == kind) e.id,
    ];
    final from = kindIds.indexOf(id);
    if (from < 0) return all;
    final to = from + delta;
    if (to < 0 || to >= kindIds.length) return all;
    final moved = kindIds.removeAt(from);
    kindIds.insert(to, moved);

    final byId = {for (final e in all) e.id: e};
    final others = [
      for (final e in all)
        if (e.kind != kind) e,
    ];
    final reorderedKind = [for (final kid in kindIds) byId[kid]!];
    // Keep relative order of the other kind; rebuild with this kind in new order
    // at the positions they originally occupied among their own kind.
    final out = <CustomEndpoint>[];
    var k = 0;
    var o = 0;
    for (final e in all) {
      if (e.kind == kind) {
        out.add(reorderedKind[k++]);
      } else {
        out.add(others[o++]);
      }
    }
    await _saveCustom(out);
    return out;
  }

  /// Ordered HTTP URLs for [network] from prefs (mainnet) or fixed (testnet).
  ///
  /// Mainnet = enabled built-in (full catalog if empty) ∪ custom HTTPS, in
  /// user order. Custom URLs still participate when built-in falls back.
  Future<List<String>> httpUrls(NetworkId network) async {
    if (network == NetworkId.testnet) {
      return network.httpEndpoints;
    }
    final builtIn = await _builtInUrls(
      ids: await selectedHttpIds(),
      catalog: mainnetHttpCatalog,
      fallbackIds: defaultHttpIds,
    );
    final custom = (await customOfKind(EndpointKind.http)).map((e) => e.url);
    return [...builtIn, ...custom];
  }

  /// Ordered WSS URLs for [network] from prefs (mainnet) or fixed (testnet).
  Future<List<String>> wssUrls(NetworkId network) async {
    if (network == NetworkId.testnet) {
      return network.wssEndpoints;
    }
    final builtIn = await _builtInUrls(
      ids: await selectedWssIds(),
      catalog: mainnetWssCatalog,
      fallbackIds: defaultWssIds,
    );
    final custom = (await customOfKind(EndpointKind.wss)).map((e) => e.url);
    return [...builtIn, ...custom];
  }

  /// Preferred WSS URL (first selected) for address-book metadata.
  Future<String> preferredWss(NetworkId network) async {
    final urls = await wssUrls(network);
    return urls.isNotEmpty ? urls.first : network.defaultWss;
  }

  Future<List<String>> _builtInUrls({
    required List<String> ids,
    required List<EndpointOption> catalog,
    required List<String> fallbackIds,
  }) async {
    final byId = {for (final e in catalog) e.id: e};
    final urls = [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!.url,
    ];
    if (urls.isEmpty) {
      return [
        for (final id in fallbackIds)
          if (byId.containsKey(id)) byId[id]!.url,
      ];
    }
    return urls;
  }

  Future<void> _saveCustom(List<CustomEndpoint> list) async {
    final p = await _ensure();
    await p.setString(
      StorageKeys.customEndpointsJson,
      jsonEncode([for (final e in list) e.toJson()]),
    );
  }

  static List<String> _parseIds(
    String? raw,
    List<String> defaults,
    Iterable<String> allowed,
  ) {
    if (raw == null || raw.trim().isEmpty) return List.of(defaults);
    final allowedSet = allowed.toSet();
    final parsed = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && allowedSet.contains(s))
        .toList();
    if (parsed.isEmpty) return List.of(defaults);
    return parsed;
  }

  static List<String> _clean(
    List<String> ids,
    Iterable<String> allowed, {
    List<String>? fallback,
  }) {
    final allowedSet = allowed.toSet();
    final seen = <String>{};
    final out = <String>[];
    for (final id in ids) {
      if (!allowedSet.contains(id) || seen.contains(id)) continue;
      seen.add(id);
      out.add(id);
    }
    if (out.isEmpty) {
      return fallback ?? allowed.toList();
    }
    return out;
  }
}
