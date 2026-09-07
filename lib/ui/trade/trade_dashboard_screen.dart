import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blockchain_utils/utils/utils.dart';
import 'package:xrpl_mobile_wallet/data/database/app_database.dart';
import 'package:xrpl_mobile_wallet/data/ledger_device/ledger_xrp_device.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_amounts.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_pair.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_rate.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_status.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_draft.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/slippage.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/trade_controller.dart';
import 'package:xrpl_mobile_wallet/state/order_book_controller.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/confirm_wallet_pin.dart';
import 'package:xrpl_mobile_wallet/ui/trade/trade_errors.dart';
import 'package:xrpl_mobile_wallet/ui/trade/trade_status_labels.dart';
import 'package:xrpl_mobile_wallet/ui/trade/order_book_panel.dart';

/// Trade dashboard: open offers, active orders and history for one wallet.
///
/// Thin by design — it watches [TradeController] and calls into it. Every RPC
/// read, Drift write and reconciliation decision lives in the controller and
/// the data layer, so what an order's status *means* is decided in one tested
/// place rather than inside a widget.
class TradeDashboardScreen extends ConsumerStatefulWidget {
  const TradeDashboardScreen({super.key, required this.account});

  final WalletAccount account;

  @override
  ConsumerState<TradeDashboardScreen> createState() =>
      _TradeDashboardScreenState();
}

class _TradeDashboardScreenState extends ConsumerState<TradeDashboardScreen> {
  BookSnapshot? _lastOrderBook;
  bool get _canSignTrades => widget.account.canSign;

  Future<T> _withLedger<T>(
    Future<T> Function(
      String publicKeyHex,
      Future<String> Function(List<int> txBlob) signTransactionBlob,
    )
    operation,
  ) async {
    final session = await LedgerXrpDevice.connectUsb();
    try {
      final got = await LedgerXrpDevice.getAddress(
        session,
        accountIndex: widget.account.ledgerAccountIndex,
      );
      if (got.address != widget.account.address) {
        throw StateError(
          'Ledger address does not match this wallet. Check the account index.',
        );
      }
      Future<String> signTransactionBlob(List<int> blob) async {
        final der = await LedgerXrpDevice.signTransaction(
          session,
          blob,
          accountIndex: widget.account.ledgerAccountIndex,
        );
        if (!verifyLedgerSignature(
          publicKeyHex: got.publicKeyHex,
          transactionBlob: blob,
          derSignature: der,
        )) {
          throw LedgerDeviceException(
            'Ledger returned an invalid signature.',
            step: 'sign',
          );
        }
        return BytesUtils.toHexString(der, lowerCase: false);
      }

      return await operation(got.publicKeyHex, signTransactionBlob);
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  TradeController get _controller =>
      ref.read(tradeControllerProvider(widget.account.id).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final network = ref.read(networkControllerProvider);
    if (!network.isConnected) {
      try {
        await ref.read(networkControllerProvider.notifier).connect();
      } catch (_) {
        // The controller surfaces the resulting load error itself.
      }
    }
    if (!mounted) return;
    await _controller.load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _offerLoadMessage(Object error) {
    if (error is StateError && error.message.toString().contains('connected')) {
      return 'The selected network is not connected.';
    }
    if (error is FormatException) {
      return 'The ledger returned an invalid open-offer response.';
    }
    return 'The selected network could not return open offers.';
  }

  Future<void> _cancel(OpenOffer entry) async {
    if (!widget.account.canSign) return;
    try {
      final ok = await promptAndVerifyWalletPin(
        context,
        ref,
        title: 'Cancel offer',
        message: 'Enter your wallet PIN to cancel offer ${entry.sequence}.',
        confirmLabel: 'Cancel offer',
      );
      if (!ok || !mounted) return;
      final result = widget.account.hasLocalKeys
          ? await _controller.cancelOffer(
              secret: (await ref
                  .read(keyVaultProvider)
                  .readSecret(widget.account.id))!,
              offerSequence: entry.sequence,
            )
          : await _withLedger(
              (pub, sign) => _controller.cancelOfferWithLedger(
                publicKeyHex: pub,
                signTransactionBlob: sign,
                offerSequence: entry.sequence,
              ),
            );
      _snack(
        result.isSuccess
            ? 'Offer cancellation submitted'
            : 'Cancellation rejected: ${result.engineResult}',
      );
    } catch (e) {
      _snack(tradeFailureMessage(e));
    }
  }

  Future<void> _cancelAll(List<OpenOffer> offers) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel all offers?'),
        content: Text(
          'This will submit ${offers.length} cancellation transactions, '
          'one at a time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Sequentially: each cancellation consumes an account sequence number, and
    // submitting them together would have them race for the same one.
    for (final offer in offers) {
      await _cancel(offer);
      if (!mounted) return;
    }
  }

  Future<void> _createLimitOrder() async {
    final assets = _tradeAssets();
    if (assets.length < 2) {
      _snack('A wallet needs XRP and an issued asset to create an order');
      return;
    }
    final draft = await showDialog<_OfferDraft>(
      context: context,
      builder: (_) => _OfferDraftDialog(
        assets: assets,
        preferred: _controller.pair.quote,
        initialRate: ref
            .read(orderBookProvider(_controller.pair))
            .valueOrNull
            ?.bestAsk
            ?.toString(),
      ),
    );
    if (draft == null || !mounted) return;

    final TakerAmounts amounts;
    try {
      amounts = draft.toTakerAmounts();
    } on FormatException {
      _snack('Enter both amounts as plain decimal numbers');
      return;
    } on ArgumentError catch (e) {
      _snack(e.message?.toString() ?? 'The order did not pass its checks');
      return;
    }

    // Preflight fee + reserve so the review screen can show them (XRW-29).
    final preflight = await _preflight();
    if (!mounted) return;
    if (!preflight.reserveAllowed) {
      _snack('This offer would reduce XRP below the account reserve.');
      return;
    }
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (_) => _OfferReviewDialog(draft: draft, preflight: preflight),
    );
    if (reviewed != true || !mounted) return;

    if (!widget.account.canSign) {
      _snack('Attach local keys or enable Ledger signing for this wallet.');
      return;
    }

    try {
      final ok = await promptAndVerifyWalletPin(
        context,
        ref,
        title: 'Create limit order',
        message: 'Enter your wallet PIN to sign this offer.',
        confirmLabel: 'Sign offer',
      );
      if (!ok || !mounted) return;
      final result = widget.account.hasLocalKeys
          ? await _controller.placeLimitOrder(
              secret: (await ref
                  .read(keyVaultProvider)
                  .readSecret(widget.account.id))!,
              amounts: amounts,
              side: draft.side,
              expectedFeeDrops: preflight.feeDrops?.toString(),
            )
          : await _withLedger(
              (pub, sign) => _controller.placeLimitOrderWithLedger(
                publicKeyHex: pub,
                signTransactionBlob: sign,
                amounts: amounts,
                side: draft.side,
                expectedFeeDrops: preflight.feeDrops?.toString(),
              ),
            );
      _snack(
        result.isSuccess
            ? 'Limit order submitted'
            : 'Order rejected: ${result.engineResult}',
      );
    } catch (e) {
      _snack(tradeFailureMessage(e));
    }
  }

  Future<void> _createMarketOrder() async {
    final pair = _controller.pair;
    final book = ref.read(orderBookProvider(pair));
    final result = await showDialog<_MarketDraftInput>(
      context: context,
      builder: (_) => _MarketOrderDialog(
        initialSellRate: book.valueOrNull == null
            ? null
            : _referenceRate(book.valueOrNull!, TradeSide.sell),
        initialBuyRate: book.valueOrNull == null
            ? null
            : _referenceRate(book.valueOrNull!, TradeSide.buy),
      ),
    );
    if (result == null || !mounted) return;
    final MarketOrderDraft draft;
    try {
      draft = MarketOrderDraft(
        pair: pair,
        side: result.side,
        baseAmount: TradeDecimal.parse(result.amount),
        referenceRate: TradeRate.quotePerBase(TradeDecimal.parse(result.rate)),
        slippage: Slippage.percent(result.slippage),
        timeInForce: result.fok
            ? TimeInForce.fillOrKill
            : TimeInForce.immediateOrCancel,
      );
      draft.takerAmounts();
    } catch (_) {
      _snack('Enter valid positive amounts, rate, and slippage (0-50%).');
      return;
    }
    final review = await showDialog<bool>(
      context: context,
      builder: (_) => _MarketReviewDialog(draft: draft),
    );
    if (review != true || !mounted) return;
    if (!widget.account.canSign) {
      _snack('Attach local keys or enable Ledger signing for this wallet.');
      return;
    }
    try {
      final ok = await promptAndVerifyWalletPin(
        context,
        ref,
        title: 'Submit market order',
        message: 'Enter your wallet PIN to sign this order.',
        confirmLabel: 'Sign order',
      );
      if (!ok || !mounted) return;
      final result = widget.account.hasLocalKeys
          ? await _controller.placeMarketOrder(
              secret: (await ref
                  .read(keyVaultProvider)
                  .readSecret(widget.account.id))!,
              draft: draft,
            )
          : await _withLedger(
              (pub, sign) => _controller.placeMarketOrderWithLedger(
                publicKeyHex: pub,
                signTransactionBlob: sign,
                draft: draft,
              ),
            );
      _snack(
        result.isSuccess
            ? 'Market order submitted'
            : 'Order rejected: ${result.engineResult}',
      );
    } catch (e) {
      _snack(tradeFailureMessage(e));
    }
  }

  String? _referenceRate(BookSnapshot snapshot, TradeSide side) =>
      (side == TradeSide.sell ? snapshot.bestAsk : snapshot.bestBid)
          ?.toString();

  Future<_TradePreflight> _preflight() async {
    try {
      final client = ref.read(xrplRpcClientProvider);
      final fee = await client.fetchMinimumFeeDrops();
      BigInt? reserveInc;
      var reserveAllowed = true;
      try {
        reserveInc = await client.fetchOwnerReserveIncrementDrops();
        final info = await client.fetchAccountReserveInfo(
          widget.account.address,
        );
        if (reserveInc != null) {
          reserveAllowed =
              info.xrpBalanceDrops >=
              info.currentReserveDrops + reserveInc + fee;
        }
      } catch (_) {
        reserveInc = null;
        reserveAllowed = false;
      }
      return _TradePreflight(
        feeDrops: fee,
        reserveIncrementDrops: reserveInc,
        reserveAllowed: reserveAllowed,
      );
    } catch (_) {
      return const _TradePreflight();
    }
  }

  List<_TradeAsset> _tradeAssets() {
    final rows =
        ref.read(walletListControllerProvider).balances[widget.account.id] ??
        const [];
    final assets = <_TradeAsset>[const _TradeAsset(currency: 'XRP')];
    for (final row in rows) {
      if (row.issuer == null || row.currency == 'XRP') continue;
      if (!assets.any(
        (a) => a.currency == row.currency && a.issuer == row.issuer,
      )) {
        assets.add(
          _TradeAsset(
            currency: row.currency,
            issuer: row.issuer,
            displayCurrency: CurrencyDisplay.symbol(
              row.currency,
              issuer: row.issuer,
            ),
          ),
        );
      }
    }
    return assets;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradeControllerProvider(widget.account.id));
    final canSign = _canSignTrades;
    final book = ref.watch(orderBookProvider(_controller.pair));
    final currentSnapshot = book.value;
    if (currentSnapshot != null) _lastOrderBook = currentSnapshot;
    final visibleSnapshot = currentSnapshot ?? _lastOrderBook;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade'),
        actions: [
          IconButton(
            onPressed: state.isWorking ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (visibleSnapshot != null)
              OrderBookPanel(
                snapshot: visibleSnapshot,
                onRefresh: () =>
                    ref.invalidate(orderBookProvider(_controller.pair)),
              )
            else if (book.hasError)
              Card(
                child: ListTile(
                  title: const Text('Order book unavailable'),
                  subtitle: const Text(
                    'This is informational only. You can still review and '
                    'submit a limit order using your chosen rate.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Retry order book',
                    onPressed: () =>
                        ref.invalidate(orderBookProvider(_controller.pair)),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else
              const Card(child: ListTile(title: Text('Loading order book...'))),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Trade execution'),
                subtitle: Text(
                  canSign
                      ? 'Single limit orders require review and PIN approval. '
                            'Open offers can be cancelled below.'
                      : widget.account.canSign
                      ? 'This is a Ledger wallet. You can review orders, but '
                            'on-device signing for trades is not available yet.'
                      : 'Attach local keys to create or cancel offers.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isWorking ? null : _createLimitOrder,
              icon: const Icon(Icons.add_chart),
              label: Text(
                canSign ? 'Create limit order' : 'Review limit order',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.isWorking ? null : _createMarketOrder,
              icon: const Icon(Icons.flash_on),
              label: const Text('Market order'),
            ),
            const SizedBox(height: 20),

            _SectionTitle('Open offers'),
            if (canSign && state.offers.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: state.isWorking
                      ? null
                      : () => _cancelAll(state.offers),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Cancel all'),
                ),
              ),
            if (state.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.loadError != null)
              Card(
                child: ListTile(
                  title: const Text('Could not load offers'),
                  subtitle: Text(_offerLoadMessage(state.loadError!)),
                ),
              )
            else if (state.offers.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No open offers'),
                  subtitle: Text('Offers you create will appear here.'),
                ),
              )
            else
              ...state.offers.map(
                (entry) => _OpenOfferTile(
                  entry: entry,
                  canSign: canSign,
                  busy: state.isWorking,
                  onCancel: () => _cancel(entry),
                ),
              ),

            if (state.active.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionTitle('Active orders'),
              ...state.active.map((row) => _ExecutionTile(row: row)),
            ],

            if (state.history.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionTitle('Recent orders'),
              ...state.history.take(20).map((row) => _ExecutionTile(row: row)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _OpenOfferTile extends StatelessWidget {
  const _OpenOfferTile({
    required this.entry,
    required this.canSign,
    required this.busy,
    required this.onCancel,
  });

  final OpenOffer entry;
  final bool canSign;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          entry.isFunded ? Icons.swap_vert : Icons.error_outline,
          color: entry.isFunded ? null : scheme.error,
        ),
        title: Text(
          '${TradeAmounts.describe(entry.offer.takerPays)} for '
          '${TradeAmounts.describe(entry.offer.takerGets)}',
        ),
        subtitle: Text(
          entry.isFunded
              ? 'Offer sequence ${entry.sequence}'
              : 'Offer sequence ${entry.sequence} · unfunded — this offer '
                    'cannot fill until the balance is restored, or it is '
                    'cancelled to free its reserve',
          style: entry.isFunded ? null : TextStyle(color: scheme.error),
        ),
        isThreeLine: !entry.isFunded,
        trailing: canSign
            ? TextButton(
                onPressed: busy ? null : onCancel,
                child: const Text('Cancel'),
              )
            : const Icon(Icons.visibility_outlined),
      ),
    );
  }
}

/// One stored order, showing the status the ledger actually confirmed.
class _ExecutionTile extends StatelessWidget {
  const _ExecutionTile({required this.row});

  final TradeExecution row;

  @override
  Widget build(BuildContext context) {
    final status = TradeStatus.fromStorage(row.status);
    final filled = TradeDecimal.tryParse(row.filledAmount);
    final target = TradeDecimal.tryParse(row.targetAmount);
    final symbol = CurrencyDisplay.symbol(
      row.baseCurrency,
      issuer: row.baseIssuer ?? '',
    );
    return Card(
      child: ListTile(
        leading: Icon(tradeStatusIcon(status)),
        title: Text(
          '${row.targetAmount} $symbol · ${tradeStatusLabel(status)}',
        ),
        subtitle: Text(
          [
            tradeStatusDetail(status),
            if (filled != null && target != null && filled.isPositive)
              'Filled $filled of $target $symbol',
            if (row.lastError != null) 'Reason: ${row.lastError}',
          ].join('\n'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _TradePreflight {
  const _TradePreflight({
    this.feeDrops,
    this.reserveIncrementDrops,
    this.reserveAllowed = true,
  });

  final BigInt? feeDrops;
  final BigInt? reserveIncrementDrops;
  final bool reserveAllowed;
}

class _MarketDraftInput {
  const _MarketDraftInput(
    this.side,
    this.amount,
    this.rate,
    this.slippage,
    this.fok,
  );
  final TradeSide side;
  final String amount, rate, slippage;
  final bool fok;
}

class _MarketOrderDialog extends StatefulWidget {
  const _MarketOrderDialog({this.initialSellRate, this.initialBuyRate});

  final String? initialSellRate;
  final String? initialBuyRate;
  @override
  State<_MarketOrderDialog> createState() => _MarketOrderDialogState();
}

class _MarketOrderDialogState extends State<_MarketOrderDialog> {
  final amount = TextEditingController(),
      rate = TextEditingController(),
      slippage = TextEditingController(text: '1');
  TradeSide side = TradeSide.sell;
  bool fok = false;

  @override
  void initState() {
    super.initState();
    rate.text = widget.initialSellRate ?? '';
  }

  @override
  void dispose() {
    amount.dispose();
    rate.dispose();
    slippage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Market order'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<TradeSide>(
            initialValue: side,
            decoration: const InputDecoration(labelText: 'Direction'),
            items: const [
              DropdownMenuItem(
                value: TradeSide.sell,
                child: Text('Sell XRP for RLUSD'),
              ),
              DropdownMenuItem(
                value: TradeSide.buy,
                child: Text('Buy XRP with RLUSD'),
              ),
            ],
            onChanged: (v) => setState(() {
              side = v!;
              rate.text =
                  (side == TradeSide.sell
                      ? widget.initialSellRate
                      : widget.initialBuyRate) ??
                  '';
            }),
          ),
          TextField(
            controller: amount,
            decoration: const InputDecoration(labelText: 'XRP amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: rate,
            decoration: const InputDecoration(
              labelText: 'Reference RLUSD/XRP rate',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: slippage,
            decoration: const InputDecoration(
              labelText: 'Maximum slippage (%)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          SwitchListTile(
            value: fok,
            onChanged: (v) => setState(() => fok = v),
            title: const Text('Fill or kill'),
            subtitle: const Text('Otherwise use immediate or cancel'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _MarketDraftInput(
            side,
            amount.text.trim(),
            rate.text.trim(),
            slippage.text.trim(),
            fok,
          ),
        ),
        child: const Text('Review'),
      ),
    ],
  );
}

class _MarketReviewDialog extends StatelessWidget {
  const _MarketReviewDialog({required this.draft});
  final MarketOrderDraft draft;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review market order'),
    content: Text(
      '${draft.side == TradeSide.sell ? 'Sell' : 'Buy'} ${draft.baseAmount} XRP\nMaximum slippage: ${draft.slippage.percentLabel}%\nWorst allowed rate: ${draft.limitRate}\n${draft.timeInForce == TimeInForce.fillOrKill ? 'Fill or kill' : 'Immediate or cancel'}\n\nThe order may match order-book or AMM liquidity. The ledger enforces the worst-rate bound and the order will never rest on the book.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Back'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Continue to sign'),
      ),
    ],
  );
}

class _OfferDraft {
  const _OfferDraft({
    required this.sellAmount,
    required this.sellCurrency,
    required this.sellIssuer,
    required this.buyAmount,
    required this.buyCurrency,
    required this.buyIssuer,
    this.rate,
  });

  final String sellAmount;
  final String sellCurrency;
  final String sellIssuer;
  final String buyAmount;
  final String buyCurrency;
  final String buyIssuer;
  final String? rate;

  /// Selling XRP is a `sell` of the base asset; anything else is a `buy`.
  TradeSide get side =>
      sellCurrency.toUpperCase() == 'XRP' ? TradeSide.sell : TradeSide.buy;

  TradeAsset get sellAsset => sellIssuer.isEmpty
      ? TradeAsset.xrp
      : TradeAsset.issued(currency: sellCurrency, issuer: sellIssuer);

  TradeAsset get buyAsset => buyIssuer.isEmpty
      ? TradeAsset.xrp
      : TradeAsset.issued(currency: buyCurrency, issuer: buyIssuer);

  /// Convert to the taker fields, checking each amount against the precision
  /// its asset can actually hold.
  ///
  /// Throws [FormatException] on a non-numeric amount and [ArgumentError] when
  /// an amount is finer than the asset stores — a sub-drop XRP figure is
  /// rejected rather than quietly rounded.
  TakerAmounts toTakerAmounts() {
    final gets = TradeDecimal.parse(sellAmount);
    var pays = TradeDecimal.parse(buyAmount);
    final enteredRate = rate == null ? null : TradeDecimal.tryParse(rate!);
    if (enteredRate != null && enteredRate.isPositive) {
      pays = sellAsset.isXrp
          ? gets * enteredRate
          : gets.divide(enteredRate, scale: 15, roundUp: false);
    }
    if (!gets.isPositive || !pays.isPositive) {
      throw ArgumentError('Both amounts must be greater than zero');
    }
    TradeRates.assertRepresentable(gets, sellAsset, field: 'sell amount');
    TradeRates.assertRepresentable(pays, buyAsset, field: 'buy amount');
    return TakerAmounts(
      getsAsset: sellAsset,
      getsValue: gets,
      paysAsset: buyAsset,
      paysValue: pays,
    );
  }
}

class _TradeAsset {
  const _TradeAsset({
    required this.currency,
    this.issuer,
    this.displayCurrency,
  });

  final String currency;
  final String? issuer;
  final String? displayCurrency;

  String get displayLabel =>
      issuer == null ? currency : '${displayCurrency ?? currency} (issued)';
}

class _OfferDraftDialog extends StatefulWidget {
  const _OfferDraftDialog({
    required this.assets,
    required this.preferred,
    this.initialRate,
  });

  final List<_TradeAsset> assets;

  /// Official pair asset to preselect when the wallet holds it.
  final TradeAsset preferred;
  final String? initialRate;

  @override
  State<_OfferDraftDialog> createState() => _OfferDraftDialogState();
}

class _OfferReviewDialog extends StatelessWidget {
  const _OfferReviewDialog({required this.draft, required this.preflight});

  final _OfferDraft draft;
  final _TradePreflight preflight;

  String _asset(String currency, String issuer) {
    if (currency == 'XRP') return 'XRP';
    final symbol = CurrencyDisplay.symbol(currency, issuer: issuer);
    return '$symbol\n$currency\n$issuer';
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final fee = preflight.feeDrops;
    final reserveInc = preflight.reserveIncrementDrops;
    return AlertDialog(
      title: const Text('Review limit order'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sell', style: labelStyle),
            Text(
              '${draft.sellAmount} ${_asset(draft.sellCurrency, draft.sellIssuer)}',
            ),
            const SizedBox(height: 12),
            Text('Buy', style: labelStyle),
            Text(
              '${draft.buyAmount} ${_asset(draft.buyCurrency, draft.buyIssuer)}',
            ),
            const SizedBox(height: 12),
            Text('Estimated network fee', style: labelStyle),
            Text(
              fee == null
                  ? 'Unavailable — will be confirmed at signing and capped for safety'
                  : '${XrpAmount.dropsToXrp(fee.toString())} XRP',
            ),
            const SizedBox(height: 12),
            Text('Reserve while the offer rests', style: labelStyle),
            Text(
              reserveInc == null
                  ? 'A resting offer raises this account’s XRP reserve until it is filled or cancelled.'
                  : 'About ${XrpAmount.dropsToXrp(reserveInc.toString())} XRP of this account’s balance is held in reserve until the offer is filled or cancelled.',
            ),
            const SizedBox(height: 12),
            const Text(
              'This creates an open offer. It may remain active until filled, '
              'cancelled, or expired, and the offered funds stay locked until then.',
            ),
            const SizedBox(height: 12),
            const Text(
              'The XRPL trading engine may match this order against order-book '
              'or AMM liquidity. The ledger still enforces the limit rate.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue to sign'),
        ),
      ],
    );
  }
}

class _OfferDraftDialogState extends State<_OfferDraftDialog> {
  final _sellAmount = TextEditingController();
  final _buyAmount = TextEditingController();
  late final _rate = TextEditingController(text: widget.initialRate ?? '');
  late _TradeAsset _sellAsset = widget.assets.first;
  late _TradeAsset _buyAsset = _defaultBuyAsset();
  String? _error;

  /// Prefer the official RLUSD line when the wallet holds one; otherwise the
  /// first issued asset available.
  _TradeAsset _defaultBuyAsset() {
    for (final asset in widget.assets) {
      if (widget.preferred.matches(asset.currency, asset.issuer)) return asset;
    }
    return widget.assets.length > 1 ? widget.assets[1] : widget.assets.first;
  }

  @override
  void dispose() {
    _sellAmount.dispose();
    _buyAmount.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _submit() {
    final sellCurrency = _sellAsset.currency;
    final buyCurrency = _buyAsset.currency;
    final sellAmount = _sellAmount.text.trim();
    final buyAmount = _buyAmount.text.trim();
    if (sellAmount.isEmpty || buyAmount.isEmpty || buyCurrency.isEmpty) {
      setState(() => _error = 'Enter both amounts and the buy currency');
      return;
    }
    if (sellCurrency == buyCurrency) {
      setState(() => _error = 'Sell and buy currencies must differ');
      return;
    }
    Navigator.of(context).pop(
      _OfferDraft(
        sellAmount: sellAmount,
        sellCurrency: sellCurrency,
        sellIssuer: _sellAsset.issuer ?? '',
        buyAmount: buyAmount,
        buyCurrency: buyCurrency,
        buyIssuer: _buyAsset.issuer ?? '',
        rate: _rate.text.trim().isEmpty ? null : _rate.text.trim(),
      ),
    );
  }

  void _syncOppositeAmount() {
    final rate = TradeDecimal.tryParse(_rate.text.trim());
    final sell = TradeDecimal.tryParse(_sellAmount.text.trim());
    if (rate == null || !rate.isPositive || sell == null || !sell.isPositive) {
      return;
    }
    try {
      final value = _sellAsset.currency.toUpperCase() == 'XRP'
          ? sell * rate
          : sell.divide(rate, scale: 15, roundUp: false);
      _buyAmount.text = value.toString();
    } catch (_) {
      // Validation remains in _OfferDraft.toTakerAmounts.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New limit order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _sellAmount,
              decoration: const InputDecoration(labelText: 'Sell amount'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _syncOppositeAmount(),
            ),
            DropdownButtonFormField<_TradeAsset>(
              initialValue: _sellAsset,
              decoration: const InputDecoration(labelText: 'Sell asset'),
              items: widget.assets
                  .map(
                    (asset) => DropdownMenuItem(
                      value: asset,
                      child: Text(asset.displayLabel),
                    ),
                  )
                  .toList(),
              onChanged: (asset) {
                if (asset != null) setState(() => _sellAsset = asset);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _buyAmount,
              decoration: const InputDecoration(labelText: 'Buy amount'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _syncOppositeAmount(),
            ),
            TextField(
              controller: _rate,
              decoration: const InputDecoration(
                labelText: 'Rate (RLUSD per XRP)',
                helperText: 'Entering a rate calculates the opposite amount',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _syncOppositeAmount(),
            ),
            DropdownButtonFormField<_TradeAsset>(
              initialValue: _buyAsset,
              decoration: const InputDecoration(labelText: 'Buy asset'),
              items: widget.assets
                  .map(
                    (asset) => DropdownMenuItem(
                      value: asset,
                      child: Text(asset.displayLabel),
                    ),
                  )
                  .toList(),
              onChanged: (asset) {
                if (asset != null) setState(() => _buyAsset = asset);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Review')),
      ],
    );
  }
}
