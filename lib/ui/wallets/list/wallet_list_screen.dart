import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/domain/amount/fiat_format.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/price_feed_controller.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/detail/wallet_detail_screen.dart';

class WalletListScreen extends ConsumerStatefulWidget {
  const WalletListScreen({super.key});

  @override
  ConsumerState<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends ConsumerState<WalletListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConnected());
  }

  Future<void> _ensureConnected() async {
    final network = ref.read(networkControllerProvider.notifier);
    if (!ref.read(networkControllerProvider).isConnected) {
      await network.connect();
    }
    if (!mounted) return;
    await ref.read(walletListControllerProvider.notifier).refreshBalances();
    await ref.read(priceFeedControllerProvider.notifier).bootstrapFromRpc();
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(walletListControllerProvider);
    final price = ref.watch(priceFeedControllerProvider);
    final pendingPayments = ref.watch(pendingPaymentsProvider);

    if (listState.loading && listState.wallets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          if (listState.errorMessage != null)
            MaterialBanner(
              content: Text(listState.errorMessage!),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => ref
                      .read(walletListControllerProvider.notifier)
                      .refreshBalances(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          if (pendingPayments.hasValue && pendingPayments.value!.isNotEmpty)
            MaterialBanner(
              leading: const Icon(Icons.hourglass_top),
              content: Text(
                '${pendingPayments.value!.length} payment${pendingPayments.value!.length == 1 ? '' : 's'} '
                'is awaiting validated ledger confirmation. Do not retry.',
              ),
              actions: [
                TextButton(
                  onPressed: () => ref.invalidate(pendingPaymentsProvider),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          Expanded(
            child: listState.wallets.isEmpty
                ? const _EmptyWallets()
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(walletListControllerProvider.notifier)
                          .refreshBalances();
                      await ref
                          .read(priceFeedControllerProvider.notifier)
                          .bootstrapFromRpc();
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: listState.wallets.length + 1,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _PortfolioSummary(
                            totalXrp: listState.totalXrp,
                            walletCount: listState.wallets.length,
                            refreshing: listState.refreshing,
                            partial: listState.hasPartialBalances,
                            price: price,
                            onToggleFiat: () => ref
                                .read(priceFeedControllerProvider.notifier)
                                .toggleDisplayFiat(),
                          );
                        }
                        final w = listState.wallets[i - 1];
                        final xrp = listState.xrpBalance(w.id);
                        return _WalletTile(
                          account: w,
                          xrpBalance: xrp,
                          displayFiat: price.displayFiat,
                          usdPerXrp: price.usdPerXrp,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    WalletDetailScreen(walletId: w.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioSummary extends StatelessWidget {
  const _PortfolioSummary({
    required this.totalXrp,
    required this.walletCount,
    required this.refreshing,
    required this.partial,
    required this.price,
    required this.onToggleFiat,
  });

  final String totalXrp;
  final int walletCount;
  final bool refreshing;
  final bool partial;
  final PriceFeedState price;
  final VoidCallback onToggleFiat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onC = theme.colorScheme.onPrimaryContainer;
    final rate = price.usdPerXrp;
    final usdTotal = FiatFormat.xrpToUsd(totalXrp, rate);
    final showUsd = price.displayFiat && usdTotal != null;

    final subtitle = partial && !refreshing
        ? '$walletCount wallets · some balances pending'
        : '$walletCount wallet${walletCount == 1 ? '' : 's'}';

    String rateLine;
    if (rate != null && rate > 0) {
      final age = price.updatedAt == null ? '' : ' · ${_age(price.updatedAt!)}';
      rateLine = '${FiatFormat.formatRate(rate)}$age · tap total to toggle';
    } else {
      rateLine = 'XRP/USD rate unavailable';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: rate != null && rate > 0 ? onToggleFiat : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showUsd ? 'Total (USD)' : 'Total XRP',
                        style: theme.textTheme.labelLarge?.copyWith(color: onC),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showUsd ? FiatFormat.formatUsd(usdTotal) : totalXrp,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onC,
                        ),
                      ),
                      if (!showUsd && usdTotal != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '≈ ${FiatFormat.formatUsd(usdTotal)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: onC.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      if (showUsd) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$totalXrp XRP',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: onC.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        rateLine,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onC.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onC.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (refreshing)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.account_balance_wallet, color: onC),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _age(DateTime at) {
    final d = DateTime.now().toUtc().difference(at.toUtc());
    if (d.inSeconds < 90) return '${d.inSeconds}s ago';
    if (d.inMinutes < 90) return '${d.inMinutes}m ago';
    if (d.inHours < 48) return '${d.inHours}h ago';
    return DateFormat.MMMd().add_jm().format(at.toLocal());
  }
}

class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No wallets yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create or import a wallet from Settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Settings → Create wallet or Import wallet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.account,
    required this.xrpBalance,
    required this.displayFiat,
    required this.usdPerXrp,
    required this.onTap,
  });

  final WalletAccount account;
  final String? xrpBalance;
  final bool displayFiat;
  final double? usdPerXrp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = account.displayColor;
    final usd = FiatFormat.xrpToUsd(xrpBalance, usdPerXrp);
    final primary = displayFiat && usd != null
        ? FiatFormat.formatUsd(usd)
        : (xrpBalance == null ? '—' : '$xrpBalance XRP');
    final secondary = displayFiat && usd != null && xrpBalance != null
        ? '$xrpBalance XRP'
        : (usd != null && !displayFiat
              ? '≈ ${FiatFormat.formatUsd(usd)}'
              : null);

    return ListTile(
      isThreeLine: true,
      minVerticalPadding: 8,
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          account.label.isNotEmpty ? account.label[0].toUpperCase() : '?',
          style: TextStyle(
            color:
                ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(account.label),
      subtitle: Text(_shorten(account.address)),
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(primary, style: Theme.of(context).textTheme.titleSmall),
            if (secondary != null) ...[
              const SizedBox(height: 2),
              Text(
                secondary,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 2),
            _KindBadge(account: account),
          ],
        ),
      ),
      onTap: onTap,
    );
  }

  static String _shorten(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.account});

  final WalletAccount account;

  @override
  Widget build(BuildContext context) {
    final label = account.useLedger
        ? 'Ledger'
        : account.hasLocalKeys
        ? 'Signing'
        : 'Watch';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
