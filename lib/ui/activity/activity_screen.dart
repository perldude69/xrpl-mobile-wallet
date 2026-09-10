import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/activity/tx_detail_screen.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activity = ref.read(activityControllerProvider.notifier);
      final state = ref.read(activityControllerProvider);
      if (state.items.isEmpty && !state.refreshing) {
        activity.refreshFromNetwork();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityControllerProvider);
    final wallets = ref.watch(walletListControllerProvider).wallets;
    final items = activity.visibleItems;

    if (activity.loading && activity.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wallets.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: activity.filterWalletId == null,
                    onSelected: (_) => ref
                        .read(activityControllerProvider.notifier)
                        .setFilterWalletId(null),
                  ),
                ),
                ...wallets.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(w.label),
                      selected: activity.filterWalletId == w.id,
                      onSelected: (_) => ref
                          .read(activityControllerProvider.notifier)
                          .setFilterWalletId(w.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (activity.errorMessage != null)
          MaterialBanner(
            content: Text(activity.errorMessage!),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(activityControllerProvider.notifier)
                    .refreshFromNetwork(),
                child: const Text('Retry'),
              ),
            ],
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref
                .read(activityControllerProvider.notifier)
                .refreshFromNetwork(),
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: _EmptyActivity(
                          hasWallets: wallets.isNotEmpty,
                          refreshing: activity.refreshing,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return _TxTile(
                        item: item,
                        showWalletLabel:
                            wallets.length > 1 &&
                            activity.filterWalletId == null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TxDetailScreen(item: item),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.hasWallets, required this.refreshing});

  final bool hasWallets;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    if (refreshing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PirateIcon(
              glyph: PirateGlyph.scroll,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              hasWallets ? 'No transactions yet' : 'No wallets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasWallets
                  ? 'Pull down to refresh history from the network.'
                  : 'Import a wallet to see activity here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.item,
    required this.onTap,
    this.showWalletLabel = true,
  });

  final ActivityTxItem item;
  final VoidCallback onTap;
  final bool showWalletLabel;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd().add_Hm();
    final (icon, color) = switch (item.direction) {
      'in' => (Icons.call_received, Colors.greenAccent),
      'out' => (Icons.call_made, Colors.orangeAccent),
      'self' => (Icons.sync_alt, Theme.of(context).colorScheme.primary),
      _ => (Icons.swap_horiz, Theme.of(context).colorScheme.outline),
    };

    final subtitleParts = <String>[
      dateFmt.format(item.date.toLocal()),
      if (showWalletLabel) item.walletLabel,
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(item.amountSummary),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Text(
        item.txType,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      onTap: onTap,
    );
  }
}
