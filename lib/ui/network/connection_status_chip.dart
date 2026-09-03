import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/domain/network/connection_health.dart';
import 'package:xrpl_mobile_wallet/state/connection_status_provider.dart';
import 'package:xrpl_mobile_wallet/state/network_controller.dart';
import 'package:xrpl_mobile_wallet/state/shell_tab_provider.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';

/// Compact traffic-light chip: tap for connection details sheet.
class ConnectionStatusChip extends ConsumerWidget {
  const ConnectionStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(connectionStatusProvider);

    return async.when(
      data: (view) => _ChipBody(
        view: view,
        onTap: () => _showDetails(context, ref, view),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => IconButton(
        tooltip: 'Connection status',
        icon: const Icon(Icons.cloud_off, size: 20),
        onPressed: () {},
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    ConnectionStatusView view,
  ) async {
    // Refresh sample for freshest hosts.
    final latest = await ref.read(connectionStatusProvider.future);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return _ConnectionDetailSheet(
          view: latest,
          onReconnect: () async {
            Navigator.of(ctx).pop();
            final net = ref.read(networkControllerProvider.notifier);
            await net.connect();
            await ref
                .read(walletListControllerProvider.notifier)
                .refreshBalances();
          },
          onOpenSettings: () {
            Navigator.of(ctx).pop();
            ref.read(shellTabIndexProvider.notifier).state = 2;
          },
        );
      },
    );
  }
}

class _ChipBody extends StatelessWidget {
  const _ChipBody({required this.view, required this.onTap});

  final ConnectionStatusView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (view.health.light) {
      TrafficLight.green => (const Color(0xFF2E7D32), Icons.circle),
      TrafficLight.yellow => (const Color(0xFFF9A825), Icons.circle),
      TrafficLight.red => (const Color(0xFFC62828), Icons.circle),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 6),
                Text(
                  '${view.networkLabel} · ${view.health.shortLabel}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionDetailSheet extends StatelessWidget {
  const _ConnectionDetailSheet({
    required this.view,
    required this.onReconnect,
    required this.onOpenSettings,
  });

  final ConnectionStatusView view;
  final VoidCallback onReconnect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String pipeLine({
      required bool ok,
      required bool connecting,
      required bool na,
      required String? host,
    }) {
      if (na) return 'Off';
      if (ok) return 'Connected${host == null ? '' : '\n$host'}';
      if (connecting) return 'Connecting…${host == null ? '' : '\n$host'}';
      return 'Disconnected${host == null ? '' : '\n$host'}';
    }

    Color pipeColor({
      required bool ok,
      required bool connecting,
      required bool na,
    }) {
      if (na) return theme.colorScheme.outline;
      if (ok) return const Color(0xFF2E7D32);
      if (connecting) return const Color(0xFFF9A825);
      return const Color(0xFFC62828);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Connection', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${view.networkLabel} · ${view.health.shortLabel}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.circle,
                size: 12,
                color: pipeColor(
                  ok: view.rpcConnected,
                  connecting: view.rpcConnecting,
                  na: false,
                ),
              ),
              title: const Text('RPC (balances / send)'),
              subtitle: Text(
                pipeLine(
                  ok: view.rpcConnected,
                  connecting: view.rpcConnecting,
                  na: false,
                  host: view.rpcHost,
                ),
              ),
              isThreeLine: view.rpcHost != null,
            ),
            if (view.rpcError != null && !view.rpcConnected)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 8),
                child: Text(
                  view.rpcError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.circle,
                size: 12,
                color: pipeColor(
                  ok: view.wssConnected,
                  connecting: view.wssConnecting,
                  na: !view.watcherEnabled,
                ),
              ),
              title: const Text('Watcher (WSS)'),
              subtitle: Text(
                !view.watcherEnabled
                    ? 'Off (disabled in Settings)'
                    : pipeLine(
                        ok: view.wssConnected,
                        connecting: view.wssConnecting,
                        na: false,
                        host: view.wssHost,
                      ),
              ),
              isThreeLine: view.watcherEnabled && view.wssHost != null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenSettings,
                    child: const Text('Endpoint settings'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onReconnect,
                    child: const Text('Reconnect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
