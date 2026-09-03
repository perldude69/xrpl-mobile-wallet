import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/endpoints/endpoint_preferences.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_dialogs.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_styles.dart';

/// Built-in catalog + custom HTTPS/WSS nodes.
class NetworkSettings extends ConsumerStatefulWidget {
  const NetworkSettings({super.key, this.onNetworkChanged});

  final VoidCallback? onNetworkChanged;

  @override
  ConsumerState<NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends ConsumerState<NetworkSettings> {
  bool _busy = false;
  List<String> _httpIds = EndpointPreferences.defaultHttpIds;
  List<String> _wssIds = EndpointPreferences.defaultWssIds;
  List<CustomEndpoint> _custom = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEndpointPrefs());
  }

  Future<void> _loadEndpointPrefs() async {
    final prefs = ref.read(endpointPreferencesProvider);
    final http = await prefs.selectedHttpIds();
    final wss = await prefs.selectedWssIds();
    final custom = await prefs.customEndpoints();
    if (!mounted) return;
    setState(() {
      _httpIds = http;
      _wssIds = wss;
      _custom = custom;
    });
  }

  Future<void> _setNetwork(NetworkId network) async {
    setState(() => _busy = true);
    try {
      await ref.read(networkControllerProvider.notifier).setNetwork(network);
      final watcher = ref.read(accountWatcherProvider);
      final wallets = ref.read(walletListControllerProvider).wallets;
      await watcher.syncAddressBook(wallets, network);
      widget.onNetworkChanged?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleHttpEndpoint(String id, bool enabled) async {
    if (_busy) return;
    final next = List<String>.from(_httpIds);
    if (enabled) {
      if (!next.contains(id)) {
        next.clear();
        for (final opt in EndpointPreferences.mainnetHttpCatalog) {
          if (_httpIds.contains(opt.id) || opt.id == id) next.add(opt.id);
        }
      }
    } else {
      if (next.length <= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keep at least one RPC server selected')),
        );
        return;
      }
      next.remove(id);
    }
    setState(() {
      _busy = true;
      _httpIds = next;
    });
    try {
      await ref.read(networkControllerProvider.notifier).setHttpEndpointIds(next);
      if (!mounted) return;
      final host = ref.read(networkControllerProvider).activeNodeHost;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            host == null
                ? 'RPC servers updated'
                : 'RPC servers updated · using $host',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update RPC: $e')),
        );
        await _loadEndpointPrefs();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWssEndpoint(String id, bool enabled) async {
    if (_busy) return;
    final next = List<String>.from(_wssIds);
    if (enabled) {
      if (!next.contains(id)) {
        next.clear();
        for (final opt in EndpointPreferences.mainnetWssCatalog) {
          if (_wssIds.contains(opt.id) || opt.id == id) next.add(opt.id);
        }
      }
    } else {
      if (next.length <= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keep at least one WSS server selected')),
        );
        return;
      }
      next.remove(id);
    }
    setState(() {
      _busy = true;
      _wssIds = next;
    });
    try {
      await ref.read(networkControllerProvider.notifier).setWssEndpointIds(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watcher WSS servers updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update WSS: $e')),
        );
        await _loadEndpointPrefs();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCustomEndpoint(EndpointKind kind) async {
    if (_busy) return;
    final draft = await showDialog<CustomEndpointDraft>(
      context: context,
      builder: (ctx) => CustomEndpointDialog(kind: kind),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(networkControllerProvider.notifier).addCustomEndpoint(
            label: draft.label,
            kind: kind,
            url: draft.url,
          );
      await _loadEndpointPrefs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCustomEndpoint(CustomEndpoint endpoint) async {
    if (_busy) return;
    final draft = await showDialog<CustomEndpointDraft>(
      context: context,
      builder: (ctx) => CustomEndpointDialog(
        kind: endpoint.kind,
        initialLabel: endpoint.label,
        initialUrl: endpoint.url,
      ),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(networkControllerProvider.notifier).updateCustomEndpoint(
            CustomEndpoint(
              id: endpoint.id,
              label: draft.label,
              kind: endpoint.kind,
              url: draft.url,
            ),
          );
      await _loadEndpointPrefs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeCustomEndpoint(CustomEndpoint endpoint) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(networkControllerProvider.notifier)
          .removeCustomEndpoint(endpoint);
      await _loadEndpointPrefs();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveCustomEndpoint(CustomEndpoint endpoint, int delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(networkControllerProvider.notifier).moveCustomEndpoint(
            endpoint: endpoint,
            delta: delta,
          );
      await _loadEndpointPrefs();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _customEndpointTiles({
    required EndpointKind kind,
    required TextTheme textTheme,
    required ColorScheme colors,
  }) {
    final items = _custom.where((e) => e.kind == kind).toList();
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'None yet. Add a private HTTPS/WSS node; it stays on this device.',
            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < items.length; i++)
        ListTile(
          title: Text(items[i].label),
          subtitle: Text(items[i].host),
          enabled: !_busy,
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'up':
                  _moveCustomEndpoint(items[i], -1);
                case 'down':
                  _moveCustomEndpoint(items[i], 1);
                case 'edit':
                  _editCustomEndpoint(items[i]);
                case 'remove':
                  _removeCustomEndpoint(items[i]);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'up',
                enabled: i > 0,
                child: const Text('Move up'),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: i < items.length - 1,
                child: const Text('Move down'),
              ),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(networkControllerProvider);
    final theme = Theme.of(context);
    final hintStyle = settingsHintStyle(context);
    final sectionStyle = settingsSectionStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Network', style: sectionStyle),
        ),
        const ListTile(
          title: Text('Ledger network'),
          subtitle: Text('Active network for balances, send, and watcher'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<NetworkId>(
            segments: const [
              ButtonSegment(
                value: NetworkId.mainnet,
                label: Text('Mainnet'),
              ),
              ButtonSegment(
                value: NetworkId.testnet,
                label: Text('Testnet'),
              ),
            ],
            selected: {networkState.network},
            onSelectionChanged: _busy
                ? null
                : (sel) {
                    if (sel.isNotEmpty) _setNetwork(sel.first);
                  },
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text('Status: ${networkState.connection.name}'),
          subtitle: Text(
            networkState.activeNodeHost != null
                ? 'RPC: ${networkState.activeNodeHost}'
                : 'RPC not connected',
          ),
        ),
        if (networkState.network == NetworkId.mainnet) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('RPC servers (HTTP)', style: sectionStyle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Tried in order while connecting. Keep at least one selected.',
              style: hintStyle,
            ),
          ),
          ...EndpointPreferences.mainnetHttpCatalog.map((opt) {
            final selected = _httpIds.contains(opt.id);
            return CheckboxListTile(
              value: selected,
              title: Text(opt.label),
              subtitle: Text(opt.host),
              secondary: selected
                  ? Text(
                      '#${_httpIds.indexOf(opt.id) + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : null,
              enabled: !_busy,
              onChanged: _busy
                  ? null
                  : (v) => _toggleHttpEndpoint(opt.id, v ?? false),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Custom RPC servers', style: sectionStyle),
          ),
          ..._customEndpointTiles(
            kind: EndpointKind.http,
            textTheme: theme.textTheme,
            colors: theme.colorScheme,
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add HTTPS node'),
            enabled: !_busy,
            onTap: _busy ? null : () => _addCustomEndpoint(EndpointKind.http),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Watcher servers (WSS)', style: sectionStyle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Background watcher tries selected hosts in order.',
              style: hintStyle,
            ),
          ),
          ...EndpointPreferences.mainnetWssCatalog.map((opt) {
            final selected = _wssIds.contains(opt.id);
            return CheckboxListTile(
              value: selected,
              title: Text(opt.label),
              subtitle: Text(opt.host),
              secondary: selected
                  ? Text(
                      '#${_wssIds.indexOf(opt.id) + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : null,
              enabled: !_busy,
              onChanged: _busy
                  ? null
                  : (v) => _toggleWssEndpoint(opt.id, v ?? false),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Custom watcher servers', style: sectionStyle),
          ),
          ..._customEndpointTiles(
            kind: EndpointKind.wss,
            textTheme: theme.textTheme,
            colors: theme.colorScheme,
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add WSS node'),
            enabled: !_busy,
            onTap: _busy ? null : () => _addCustomEndpoint(EndpointKind.wss),
          ),
        ] else
          ListTile(
            title: const Text('Testnet endpoints'),
            subtitle: Text(
              'HTTP ${networkState.network.defaultHttp}\n'
              'WSS ${networkState.network.defaultWss}',
            ),
            isThreeLine: true,
          ),
      ],
    );
  }
}
