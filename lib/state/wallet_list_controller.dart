import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/data/secure/key_vault.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/data/watcher/account_watcher.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';

/// In-memory view of wallets plus their latest known balances.
class WalletListState {
  const WalletListState({
    this.wallets = const [],
    this.balances = const {},
    this.loading = true,
    this.refreshing = false,
    this.errorMessage,
  });

  final List<WalletAccount> wallets;

  /// walletId → ledger balances (empty if unknown / unfunded).
  final Map<String, List<LedgerBalance>> balances;

  final bool loading;
  final bool refreshing;
  final String? errorMessage;

  WalletListState copyWith({
    List<WalletAccount>? wallets,
    Map<String, List<LedgerBalance>>? balances,
    bool? loading,
    bool? refreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalletListState(
      wallets: wallets ?? this.wallets,
      balances: balances ?? this.balances,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Primary XRP balance display for [walletId], or null if not loaded.
  String? xrpBalance(String walletId) {
    final list = balances[walletId];
    if (list == null) return null;
    for (final b in list) {
      if (b.currency == 'XRP') return b.value;
    }
    return '0';
  }

  /// Sum of XRP across all wallets (missing balances treated as 0).
  ///
  /// Uses drop-level [BigInt] math via [XrpAmount] for precision.
  String get totalXrp {
    var drops = BigInt.zero;
    for (final w in wallets) {
      final xrp = xrpBalance(w.id);
      if (xrp == null) continue;
      try {
        drops += BigInt.parse(XrpAmount.xrpToDrops(xrp));
      } catch (_) {
        // Skip malformed balance strings
      }
    }
    return XrpAmount.dropsToXrp(drops.toString());
  }

  /// True when at least one wallet has no balance row yet.
  bool get hasPartialBalances {
    for (final w in wallets) {
      if (xrpBalance(w.id) == null) return true;
    }
    return false;
  }
}

class WalletListController extends StateNotifier<WalletListState> {
  WalletListController({
    required AppDatabase db,
    required KeyVault keyVault,
    required XrplRpcClient ledger,
    required NetworkController network,
    required AccountWatcher watcher,
  }) : _db = db,
       _keyVault = keyVault,
       _ledger = ledger,
       _network = network,
       _watcher = watcher,
       super(const WalletListState()) {
    reload();
  }

  final AppDatabase _db;
  final KeyVault _keyVault;
  final XrplRpcClient _ledger;
  final NetworkController _network;
  final AccountWatcher _watcher;

  Future<void> reload() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final rows = await _db.getAllWallets();
      final accounts = rows
          .map(_toAccount)
          .where((a) => a.preferredNetwork == _network.state.network)
          .toList();
      final balanceMap = <String, List<LedgerBalance>>{};
      for (final a in accounts) {
        final cached = await _db.getBalancesForWallet(a.id);
        if (cached.isNotEmpty) {
          balanceMap[a.id] = cached
              .map(
                (b) => LedgerBalance(
                  currency: b.currency,
                  value: b.value,
                  issuer: b.issuer.isEmpty ? null : b.issuer,
                ),
              )
              .toList();
        }
      }
      state = state.copyWith(
        wallets: accounts,
        balances: balanceMap,
        loading: false,
      );
      await _syncWatcher(accounts);
    } catch (e) {
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  /// Persist an import: secret (if any) → KeyVault, metadata → SQLite.
  Future<void> addImported(ImportResult result) async {
    final account = result.account;
    ensureUniqueAddress(state.wallets, account.address);
    final secret = result.secret;
    if (secret != null) {
      await _keyVault.saveSecret(account.id, secret);
    }
    await _db.upsertWallet(_toCompanion(account));
    await reload();
    // Best-effort balance refresh; ignore network errors here.
    try {
      await refreshBalances(walletIds: [account.id]);
    } catch (_) {}
  }

  /// Attach signing material to an existing watch-only wallet (same id/address).
  ///
  /// [material] must already be verified to match [walletId]'s classic address
  /// (see [WalletImporter.deriveMnemonicForAddress] /
  /// [WalletImporter.deriveFamilySeedForAddress]).
  Future<void> attachKeys(String walletId, DerivedSecret material) async {
    final row = await _db.getWalletById(walletId);
    if (row == null) {
      throw ArgumentError('Wallet not found');
    }
    final account = _toAccount(row);
    if (account.kind != WalletKind.watchOnly) {
      throw ArgumentError('This wallet already has keys');
    }
    if (material.address != account.address) {
      throw ArgumentError('This secret does not match this wallet\'s address.');
    }

    await _keyVault.saveSecret(walletId, material.secret);
    final upgraded = account.copyWith(
      kind: WalletKind.signing,
      importMethod: material.importMethod,
    );
    await _db.upsertWallet(_toCompanion(upgraded));
    await reload();
  }

  Future<void> deleteWallet(String id) async {
    await _keyVault.deleteSecret(id);
    await _db.deleteWalletCascade(id);
    final nextWallets = state.wallets.where((w) => w.id != id).toList();
    final nextBalances = Map<String, List<LedgerBalance>>.from(state.balances)
      ..remove(id);
    state = state.copyWith(wallets: nextWallets, balances: nextBalances);
    await _syncWatcher(nextWallets);
  }

  /// Rename wallet (short display label).
  Future<void> updateLabel(String walletId, String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    if (trimmed.length > 48) {
      throw ArgumentError('Name is too long');
    }
    await _db.updateWalletLabel(walletId, trimmed);
    final next = state.wallets
        .map((w) => w.id == walletId ? w.copyWith(label: trimmed) : w)
        .toList();
    state = state.copyWith(wallets: next);
    await _syncWatcher(next);
  }

  /// Set accent color ARGB, or null for address-derived auto color.
  Future<void> updateAccentColor(String walletId, int? accentArgb) async {
    await _db.updateWalletAccentColor(walletId, accentArgb);
    final next = state.wallets
        .map(
          (w) => w.id == walletId
              ? w.copyWith(
                  accentColorArgb: accentArgb,
                  clearAccentColor: accentArgb == null,
                )
              : w,
        )
        .toList();
    state = state.copyWith(wallets: next);
  }

  /// Toggle Ledger signing for a wallet (no seed stored). Enables Send.
  Future<void> setUseLedger(
    String walletId, {
    required bool useLedger,
    int ledgerAccountIndex = 0,
  }) async {
    await _db.updateWalletLedger(
      id: walletId,
      useLedger: useLedger,
      ledgerAccountIndex: ledgerAccountIndex,
    );
    final next = state.wallets
        .map(
          (w) => w.id == walletId
              ? w.copyWith(
                  useLedger: useLedger,
                  ledgerAccountIndex: ledgerAccountIndex,
                )
              : w,
        )
        .toList();
    state = state.copyWith(wallets: next);
  }

  Future<void> _syncWatcher(List<WalletAccount> accounts) async {
    try {
      await _watcher.syncAddressBook(accounts, _network.state.network);
    } catch (_) {
      // Watcher is best-effort; never fail wallet operations.
    }
  }

  /// Ensure network is connected, then fetch balances for listed (or all) wallets.
  Future<void> refreshBalances({List<String>? walletIds}) async {
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

      final targets = walletIds == null
          ? state.wallets
          : state.wallets.where((w) => walletIds.contains(w.id)).toList();

      final next = Map<String, List<LedgerBalance>>.from(state.balances);
      for (final w in targets) {
        try {
          final list = await _ledger.fetchBalances(w.address);
          next[w.id] = list;
          await _db.replaceBalances(
            w.id,
            list
                .map(
                  (b) => BalancesCompanion.insert(
                    walletId: w.id,
                    currency: b.currency,
                    issuer: Value(b.issuer ?? ''),
                    value: b.value,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                )
                .toList(),
          );
        } catch (e) {
          // Keep previous balance for this wallet; record last error.
          state = state.copyWith(errorMessage: e.toString());
        }
      }
      state = state.copyWith(balances: next, refreshing: false);
    } catch (e) {
      state = state.copyWith(refreshing: false, errorMessage: e.toString());
    }
  }

  /// Throws if [address] is already saved (create / import / attach-keys).
  static void ensureUniqueAddress(List<WalletAccount> wallets, String address) {
    if (wallets.any((w) => w.address == address)) {
      throw ArgumentError('A wallet with this address is already saved');
    }
  }

  static WalletAccount _toAccount(Wallet row) {
    return WalletAccount(
      id: row.id,
      label: row.label,
      address: row.address,
      kind: WalletKind.values.byName(row.kind),
      preferredNetwork: NetworkId.values.byName(row.preferredNetwork),
      importMethod: ImportMethod.values.byName(row.importMethod),
      createdAt: row.createdAt,
      sortOrder: row.sortOrder,
      accentColorArgb: row.accentColor,
      useLedger: row.useLedger,
      ledgerAccountIndex: row.ledgerAccountIndex,
    );
  }

  static WalletsCompanion _toCompanion(WalletAccount a) {
    return WalletsCompanion.insert(
      id: a.id,
      label: a.label,
      address: a.address,
      kind: a.kind.name,
      preferredNetwork: a.preferredNetwork.name,
      importMethod: a.importMethod.name,
      createdAt: a.createdAt,
      sortOrder: Value(a.sortOrder),
      accentColor: Value(a.accentColorArgb),
      useLedger: Value(a.useLedger),
      ledgerAccountIndex: Value(a.ledgerAccountIndex),
    );
  }
}

final walletListControllerProvider =
    StateNotifierProvider<WalletListController, WalletListState>((ref) {
      return WalletListController(
        db: ref.watch(databaseProvider),
        keyVault: ref.watch(keyVaultProvider),
        ledger: ref.watch(xrplRpcClientProvider),
        network: ref.watch(networkControllerProvider.notifier),
        watcher: ref.watch(accountWatcherProvider),
      );
    });
