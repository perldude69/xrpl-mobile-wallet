import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';

/// XRPL ledger "date" field is seconds since 2000-01-01 00:00:00 UTC.
DateTime rippleEpochToDateTime(int? rippleSeconds) {
  if (rippleSeconds == null) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.utc(2000, 1, 1).add(Duration(seconds: rippleSeconds));
}

/// UI-facing row combining a cached tx with its wallet label.
class ActivityTxItem {
  const ActivityTxItem({
    required this.tx,
    required this.walletLabel,
    required this.walletAddress,
  });

  final CachedTx tx;
  final String walletLabel;
  final String walletAddress;

  String get hash => tx.hash;
  String get walletId => tx.walletId;
  String get txType => tx.txType;
  String get direction => tx.direction;
  String get amountSummary => tx.amountSummary;
  String? get counterpart => tx.counterpart;
  DateTime get date => tx.date;
  int? get ledgerIndex => tx.ledgerIndex;
}

class ActivityState {
  const ActivityState({
    this.items = const [],
    this.loading = true,
    this.refreshing = false,
    this.errorMessage,
    this.filterWalletId,
  });

  final List<ActivityTxItem> items;
  final bool loading;
  final bool refreshing;
  final String? errorMessage;

  /// null = all wallets.
  final String? filterWalletId;

  /// Items after applying [filterWalletId].
  List<ActivityTxItem> get visibleItems {
    final id = filterWalletId;
    if (id == null) return items;
    return items.where((i) => i.walletId == id).toList();
  }

  ActivityState copyWith({
    List<ActivityTxItem>? items,
    bool? loading,
    bool? refreshing,
    String? errorMessage,
    String? filterWalletId,
    bool clearError = false,
    bool clearFilter = false,
  }) {
    return ActivityState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      filterWalletId:
          clearFilter ? null : (filterWalletId ?? this.filterWalletId),
    );
  }
}

class ActivityController extends StateNotifier<ActivityState> {
  ActivityController({
    required AppDatabase db,
    required XrplRpcClient ledger,
    required NetworkController network,
    required Ref ref,
  })  : _db = db,
        _ledger = ledger,
        _network = network,
        _ref = ref,
        super(const ActivityState()) {
    loadFromCache();
  }

  final AppDatabase _db;
  final XrplRpcClient _ledger;
  final NetworkController _network;
  final Ref _ref;

  List<WalletAccount> get _wallets =>
      _ref.read(walletListControllerProvider).wallets;

  Future<void> loadFromCache() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final rows = await _db.getAllCachedTxs();
      state = state.copyWith(
        items: _mapRows(rows),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Fetch account_tx for every wallet, upsert, then reload cache.
  Future<void> refreshFromNetwork() async {
    if (state.refreshing) return;
    state = state.copyWith(refreshing: true, clearError: true);

    try {
      if (!_network.state.isConnected) {
        await _network.connect();
      }
      if (!_network.state.isConnected) {
        state = state.copyWith(
          refreshing: false,
          errorMessage:
              _network.state.errorMessage ?? 'Not connected to network',
        );
        return;
      }

      final wallets = _wallets;
      if (wallets.isEmpty) {
        state = state.copyWith(
          items: const [],
          refreshing: false,
          loading: false,
        );
        return;
      }

      for (final w in wallets) {
        try {
          final summaries = await _ledger.fetchAccountTx(w.address);
          final companions = summaries
              .map((s) => _toCompanion(wallet: w, summary: s))
              .toList();
          await _db.upsertCachedTxs(companions);
        } catch (e) {
          state = state.copyWith(errorMessage: e.toString());
        }
      }

      final rows = await _db.getAllCachedTxs();
      state = state.copyWith(
        items: _mapRows(rows),
        refreshing: false,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(refreshing: false, errorMessage: e.toString());
    }
  }

  void setFilterWalletId(String? walletId) {
    if (walletId == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterWalletId: walletId);
    }
  }

  /// Recent txs for a single wallet (from in-memory cache, date desc).
  List<ActivityTxItem> itemsForWallet(String walletId, {int limit = 5}) {
    return state.items
        .where((i) => i.walletId == walletId)
        .take(limit)
        .toList();
  }

  List<ActivityTxItem> _mapRows(List<CachedTx> rows) {
    final wallets = _wallets;
    final byId = {for (final w in wallets) w.id: w};
    return rows.map((tx) {
      final w = byId[tx.walletId];
      return ActivityTxItem(
        tx: tx,
        walletLabel: w?.label ?? 'Unknown wallet',
        walletAddress: w?.address ?? '',
      );
    }).toList();
  }

  static CachedTxsCompanion _toCompanion({
    required WalletAccount wallet,
    required LedgerTxSummary summary,
  }) {
    final direction = _direction(wallet.address, summary);
    final counterpart = _counterpart(wallet.address, summary);
    return CachedTxsCompanion.insert(
      hash: summary.hash,
      walletId: wallet.id,
      ledgerIndex: Value(summary.ledgerIndex),
      txType: summary.transactionType,
      direction: direction,
      amountSummary: summary.amountSummary ?? summary.transactionType,
      counterpart: Value(counterpart),
      date: rippleEpochToDateTime(summary.date),
    );
  }

  static String _direction(String walletAddress, LedgerTxSummary tx) {
    final isSender = tx.account == walletAddress;
    final isDest = tx.destination == walletAddress;
    if (isSender && isDest) return 'self';
    if (isSender) return 'out';
    if (isDest) return 'in';
    return 'other';
  }

  static String? _counterpart(String walletAddress, LedgerTxSummary tx) {
    if (tx.account == walletAddress) {
      return tx.destination;
    }
    if (tx.account.isEmpty) return tx.destination;
    return tx.account;
  }
}

final activityControllerProvider =
    StateNotifierProvider<ActivityController, ActivityState>((ref) {
  return ActivityController(
    db: ref.watch(databaseProvider),
    ledger: ref.watch(xrplRpcClientProvider),
    network: ref.watch(networkControllerProvider.notifier),
    ref: ref,
  );
});
