import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/trade/offer_service.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_error_slug.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_reconciler.dart';
import 'package:xrpl_mobile_wallet/data/trade/trade_repository.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_draft.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:uuid/uuid.dart';

/// The only place that touches the trade tables, wrapped for Riverpod.
final tradeRepositoryProvider = Provider<TradeRepository>(
  (ref) => TradeRepository(ref.watch(databaseProvider)),
);

/// App-scoped on purpose.
///
/// A plain [Provider], not `autoDispose` and not owned by the Trade screen: an
/// order placed and then backgrounded still has to resolve. Kicked from
/// `LockLifecycle` at unlock and on resume — never from the watcher isolate,
/// where a second [AppDatabase] on the same file would corrupt it.
final tradeReconcilerProvider = Provider<TradeReconciler>(
  (ref) => TradeReconciler(
    database: ref.watch(databaseProvider),
    repository: ref.watch(tradeRepositoryProvider),
    client: ref.watch(xrplRpcClientProvider),
  ),
);

/// An open offer plus what this wallet knows about it.
class OpenOffer {
  const OpenOffer({
    required this.offer,
    required this.isFunded,
    this.executionId,
  });

  final AccountOffer offer;

  /// False when the account no longer holds enough of the offered asset.
  ///
  /// A funded offer can quietly become unfunded — the balance moved elsewhere
  /// — and then it lingers on the book being skipped by every taker. It looks
  /// live and will never fill, so it is called out rather than listed as if it
  /// were working.
  final bool isFunded;

  /// The `trade_executions` row that created it, when this app placed it.
  final String? executionId;

  int get sequence => offer.seq;
}

class TradeState {
  const TradeState({
    this.offers = const [],
    this.active = const [],
    this.history = const [],
    this.loading = true,
    this.busy = false,
    this.loadError,
  });

  final List<OpenOffer> offers;

  /// Non-terminal rows: submitted, resting, partially filled, interrupted.
  final List<TradeExecution> active;

  /// Terminal rows, newest first.
  final List<TradeExecution> history;

  final bool loading;

  /// A signing or cancelling action is in flight.
  final bool busy;

  final Object? loadError;

  bool get isWorking => loading || busy;

  TradeState copyWith({
    List<OpenOffer>? offers,
    List<TradeExecution>? active,
    List<TradeExecution>? history,
    bool? loading,
    bool? busy,
    Object? loadError,
    bool clearLoadError = false,
  }) => TradeState(
    offers: offers ?? this.offers,
    active: active ?? this.active,
    history: history ?? this.history,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}

/// Orchestration for one wallet's trade screen.
///
/// Owns the RPC reads, the Drift writes and the submit sequencing that used to
/// live inside the dashboard widget. It deliberately does **not** hold a
/// secret: the UI verifies the PIN, reads the key from `KeyVault`, and passes
/// it into a single call, which keeps key material in one short-lived local
/// exactly as the send path does.
class TradeController extends StateNotifier<TradeState> {
  TradeController({
    required WalletAccount account,
    required XrplRpcClient client,
    required TradeRepository repository,
    required TradeReconciler reconciler,
    required NetworkId network,
    List<LedgerBalance>? balances,
    OfferService? offers,
  }) : _account = account,
       _balances = balances,
       _client = client,
       _repository = repository,
       _reconciler = reconciler,
       _network = network,
       _offers = offers ?? OfferService(),
       super(const TradeState());

  final WalletAccount _account;
  final XrplRpcClient _client;
  final TradeRepository _repository;
  final TradeReconciler _reconciler;
  final NetworkId _network;
  final OfferService _offers;

  /// Balances this wallet last loaded, used only to spot an unfunded offer.
  /// Null means "not loaded yet", which is treated as funded rather than
  /// flagging a healthy offer during a slow refresh.
  final List<LedgerBalance>? _balances;

  /// The official pair for this network, XRP ⇄ RLUSD.
  TradePair get pair => TradePair.forNetwork(_network);

  /// Issued asset the order form should preselect: RLUSD when the wallet
  /// already holds a line for it, otherwise nothing. Trading is heading for
  /// this one pair (Part II §A), so it is the sensible default rather than
  /// whichever token happens to sort first.
  TradeAsset? get preferredQuote {
    final rlusd = pair.quote;
    for (final balance in _balances ?? const <LedgerBalance>[]) {
      if (rlusd.matches(balance.currency, balance.issuer)) return rlusd;
    }
    return null;
  }

  /// Refresh open offers and stored executions, reconciling first.
  ///
  /// Reconciliation runs before the read so the screen never renders a status
  /// the ledger has already moved past.
  Future<void> load({bool reconcile = true}) async {
    state = state.copyWith(loading: true, clearLoadError: true);
    try {
      if (reconcile) {
        // Reconciliation is safety-critical, but an unavailable node must not
        // leave the read-only offers list spinning forever. Ambiguous rows stay
        // non-terminal and are reconciled again on the next resume/load.
        await _reconciler.reconcileAll().timeout(
          const Duration(seconds: 12),
          onTimeout: () => const [],
        );
      }
      final offers = await _client
          .fetchAccountOffers(_account.address)
          .timeout(const Duration(seconds: 12));
      final rows = await _repository.executionsForWallet(_account.id);
      if (!mounted) return;
      state = state.copyWith(
        offers: _decorate(offers, rows),
        active: [
          for (final row in rows)
            if (!TradeStatus.fromStorage(row.status).isTerminal) row,
        ],
        history: [
          for (final row in rows)
            if (TradeStatus.fromStorage(row.status).isTerminal) row,
        ],
        loading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, loadError: e);
    }
  }

  /// Place a limit order for already-computed taker [amounts].
  ///
  /// [secret] is used for this call only and never stored. Returns the engine
  /// result on submission, or throws — the caller maps the error to fixed user
  /// copy; nothing here formats an exception for display.
  Future<PaymentSubmitResultSummary> placeLimitOrder({
    required String secret,
    required TakerAmounts amounts,
    required TradeSide side,
    String? expectedFeeDrops,
  }) async {
    final executionId = const Uuid().v4();
    // The row is written only now, after the PIN has been verified (XRW-31):
    // an abandoned draft must not leave a row claiming an order exists.
    await _repository.createSigningExecution(
      id: executionId,
      walletId: _account.id,
      network: _network.name,
      given: amounts.getsAsset,
      received: amounts.paysAsset,
      side: side,
      // `target_amount` is measured in the asset being given up, matching
      // `base_currency` on the same row.
      targetAmount: amounts.getsValue.toString(),
      orderType: 'limit',
    );

    state = state.copyWith(busy: true);
    try {
      final result = await _offers.submitOfferCreateFromAmounts(
        secret: secret,
        account: _account.address,
        rpc: _client.requireProvider(),
        amounts: amounts,
        expectedFeeDrops: expectedFeeDrops,
      );

      if (result.isSuccess) {
        await _repository.markSubmitted(
          executionId,
          txHash: result.hash,
          lastLedgerSequence: result.lastLedgerSequence,
        );
      } else {
        await _repository.markStatus(
          executionId,
          TradeStatus.failed,
          errorSlug: 'engine:${result.engineResult}',
        );
      }
      await load(reconcile: false);
      return PaymentSubmitResultSummary(
        isSuccess: result.isSuccess,
        engineResult: result.engineResult,
      );
    } catch (e) {
      await _repository.markStatus(
        executionId,
        TradeStatus.failed,
        errorSlug: tradeErrorCategory(e),
      );
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<PaymentSubmitResultSummary> placeMarketOrder({
    required String secret,
    required MarketOrderDraft draft,
    String? expectedFeeDrops,
  }) async {
    final amounts = draft.takerAmounts();
    final executionId = const Uuid().v4();
    await _repository.createSigningExecution(
      id: executionId,
      walletId: _account.id,
      network: _network.name,
      given: amounts.getsAsset,
      received: amounts.paysAsset,
      side: draft.side,
      targetAmount: draft.baseAmount.toString(),
      orderType: draft.orderTypeStorageValue,
    );
    state = state.copyWith(busy: true);
    try {
      final result = await _offers.submitOfferCreateFromAmounts(
        secret: secret,
        account: _account.address,
        rpc: _client.requireProvider(),
        amounts: amounts,
        flags: OfferService.flagsFor(draft),
        expectedFeeDrops: expectedFeeDrops,
      );
      if (result.isSuccess) {
        await _repository.markSubmitted(
          executionId,
          txHash: result.hash,
          lastLedgerSequence: result.lastLedgerSequence,
        );
      } else {
        await _repository.markStatus(
          executionId,
          TradeStatus.failed,
          errorSlug: 'engine:${result.engineResult}',
        );
      }
      await load(reconcile: false);
      return PaymentSubmitResultSummary(
        isSuccess: result.isSuccess,
        engineResult: result.engineResult,
      );
    } catch (e) {
      await _repository.markStatus(
        executionId,
        TradeStatus.failed,
        errorSlug: tradeErrorCategory(e),
      );
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<PaymentSubmitResultSummary> placeMarketOrderWithLedger({
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    required MarketOrderDraft draft,
    String? expectedFeeDrops,
  }) async {
    final amounts = draft.takerAmounts();
    final executionId = const Uuid().v4();
    await _repository.createSigningExecution(
      id: executionId,
      walletId: _account.id,
      network: _network.name,
      given: amounts.getsAsset,
      received: amounts.paysAsset,
      side: draft.side,
      targetAmount: draft.baseAmount.toString(),
      orderType: draft.orderTypeStorageValue,
    );
    state = state.copyWith(busy: true);
    try {
      final result = await _offers.submitOfferCreateWithLedger(
        account: _account.address,
        rpc: _client.requireProvider(),
        publicKeyHex: publicKeyHex,
        signTransactionBlob: signTransactionBlob,
        amounts: amounts,
        flags: OfferService.flagsFor(draft),
        expectedFeeDrops: expectedFeeDrops,
      );
      if (result.isSuccess) {
        await _repository.markSubmitted(
          executionId,
          txHash: result.hash,
          lastLedgerSequence: result.lastLedgerSequence,
        );
      } else {
        await _repository.markStatus(
          executionId,
          TradeStatus.failed,
          errorSlug: 'engine:${result.engineResult}',
        );
      }
      await load(reconcile: false);
      return PaymentSubmitResultSummary(
        isSuccess: result.isSuccess,
        engineResult: result.engineResult,
      );
    } catch (e) {
      await _repository.markStatus(
        executionId,
        TradeStatus.failed,
        errorSlug: tradeErrorCategory(e),
      );
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  /// Cancel one open offer, freeing its owner reserve.
  Future<PaymentSubmitResultSummary> cancelOffer({
    required String secret,
    required int offerSequence,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final result = await _offers.submitOfferCancel(
        secret: secret,
        account: _account.address,
        rpc: _client.requireProvider(),
        offerSequence: offerSequence,
      );
      await load(reconcile: false);
      return PaymentSubmitResultSummary(
        isSuccess: result.isSuccess,
        engineResult: result.engineResult,
      );
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  /// Submit one trade through a caller-owned Ledger session. The callback is
  /// intentionally passed in rather than storing a device/session here.
  Future<PaymentSubmitResultSummary> placeLimitOrderWithLedger({
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    required TakerAmounts amounts,
    required TradeSide side,
    String? expectedFeeDrops,
  }) async {
    final executionId = const Uuid().v4();
    await _repository.createSigningExecution(
      id: executionId,
      walletId: _account.id,
      network: _network.name,
      given: amounts.getsAsset,
      received: amounts.paysAsset,
      side: side,
      targetAmount: amounts.getsValue.toString(),
      orderType: 'limit',
    );
    state = state.copyWith(busy: true);
    try {
      final result = await _offers.submitOfferCreateWithLedger(
        account: _account.address,
        rpc: _client.requireProvider(),
        publicKeyHex: publicKeyHex,
        signTransactionBlob: signTransactionBlob,
        amounts: amounts,
        expectedFeeDrops: expectedFeeDrops,
      );
      if (result.isSuccess) {
        await _repository.markSubmitted(
          executionId,
          txHash: result.hash,
          lastLedgerSequence: result.lastLedgerSequence,
        );
      } else {
        await _repository.markStatus(
          executionId,
          TradeStatus.failed,
          errorSlug: 'engine:${result.engineResult}',
        );
      }
      await load(reconcile: false);
      return PaymentSubmitResultSummary(
        isSuccess: result.isSuccess,
        engineResult: result.engineResult,
      );
    } catch (e) {
      await _repository.markStatus(
        executionId,
        TradeStatus.failed,
        errorSlug: tradeErrorCategory(e),
      );
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<PaymentSubmitResultSummary> cancelOfferWithLedger({
    required String publicKeyHex,
    required Future<String> Function(List<int> txBlob) signTransactionBlob,
    required int offerSequence,
    String? expectedFeeDrops,
  }) async {
    state = state.copyWith(busy: true);
    try {
      final result = await _offers.submitOfferCancelWithLedger(
        account: _account.address,
        rpc: _client.requireProvider(),
        offerSequence: offerSequence,
        publicKeyHex: publicKeyHex,
        signTransactionBlob: signTransactionBlob,
        expectedFeeDrops: expectedFeeDrops,
      );
      await load(reconcile: false);
      return PaymentSubmitResultSummary(
        isSuccess: result.isSuccess,
        engineResult: result.engineResult,
      );
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  /// Pair each open offer with the execution row that created it, and work out
  /// whether the account can still honour it.
  List<OpenOffer> _decorate(
    List<AccountOffer> offers,
    List<TradeExecution> rows,
  ) {
    final bySequence = {
      for (final row in rows)
        if (row.offerSequence != null) row.offerSequence!: row.id,
    };
    return [
      for (final offer in offers)
        OpenOffer(
          offer: offer,
          isFunded: _isFunded(offer),
          executionId: bySequence[offer.seq],
        ),
    ];
  }

  /// True when the account still holds at least the offer's `TakerGets`.
  ///
  /// Uses the balances the wallet list already loaded rather than a fresh
  /// request; an unknown balance is reported as funded so a slow refresh never
  /// shows a healthy offer as broken.
  bool _isFunded(AccountOffer offer) {
    final json = offer.takerGets.toJson();
    final String currency;
    final String? issuer;
    final TradeDecimal required;
    if (json is Map) {
      currency = json['currency']?.toString() ?? '';
      issuer = json['issuer']?.toString();
      final value = TradeDecimal.tryParse(json['value']?.toString());
      if (value == null) return true;
      required = value;
    } else {
      currency = 'XRP';
      issuer = null;
      final drops = TradeDecimal.tryParse(json.toString());
      if (drops == null) return true;
      required = TradeDecimal.fromUnscaled(drops.unscaled, TradeAsset.xrpScale);
    }

    final balances = _balances;
    if (balances == null) return true;
    for (final balance in balances) {
      final sameIssuer = (balance.issuer ?? '') == (issuer ?? '');
      if (balance.currency != currency || !sameIssuer) continue;
      final held = TradeDecimal.tryParse(balance.value);
      if (held == null) return true;
      return held >= required;
    }
    return true;
  }
}

/// The parts of a submission result the UI is allowed to see.
///
/// `engineResult` is an XRPL constant such as `tecUNFUNDED_OFFER`, not
/// exception text, so it is safe to show.
class PaymentSubmitResultSummary {
  const PaymentSubmitResultSummary({
    required this.isSuccess,
    required this.engineResult,
  });

  final bool isSuccess;
  final String engineResult;
}

/// Screen-scoped, one per wallet.
///
/// `autoDispose` so leaving the Trade screen stops its polling; the family key
/// is the wallet id because `trade_executions` is already keyed that way.
final tradeControllerProvider = StateNotifierProvider.autoDispose
    .family<TradeController, TradeState, String>((ref, walletId) {
      final wallets = ref.watch(walletListControllerProvider);
      final account = wallets.wallets.firstWhere(
        (w) => w.id == walletId,
        orElse: () => throw StateError('Unknown wallet $walletId'),
      );
      return TradeController(
        account: account,
        client: ref.watch(xrplRpcClientProvider),
        repository: ref.watch(tradeRepositoryProvider),
        reconciler: ref.watch(tradeReconcilerProvider),
        network: ref.watch(networkControllerProvider).network,
        balances: wallets.balances[walletId],
      );
    });
