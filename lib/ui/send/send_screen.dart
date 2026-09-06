import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_dart/xrpl_dart.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/data/ledger_device/ledger_xrp_device.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/domain/tokens/currency_display.dart';
import 'package:xrpl_mobile_wallet/data/secure/screen_security.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/confirm_wallet_pin.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';

enum _SendStep { asset, destination, amount, review, result }

/// Multi-step flow to send XRP or held IOUs from a signing wallet.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key, required this.account, this.presetDestination});

  final WalletAccount account;

  /// When set, XRP is selected, the destination is locked, and the flow
  /// starts at the amount step (used for the Settings coffee mug).
  final String? presetDestination;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  _SendStep _step = _SendStep.asset;

  LedgerBalance? _selected;
  final _destinationController = TextEditingController();
  final _tagController = TextEditingController();
  final _amountController = TextEditingController();

  String? _error;
  bool _busy = false;
  PaymentSubmitResult? _result;
  String? _feeDrops;
  String? _feeError;
  bool _feeBusy = false;
  DestinationAccountPolicy? _destPolicy;

  final _paymentService = PaymentService();

  bool get _hasPresetDestination {
    final dest = widget.presetDestination;
    return dest != null && dest.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    assert(
      widget.account.canSign,
      'SendScreen requires a signing or Ledger-enabled wallet',
    );
    if (_hasPresetDestination) {
      _destinationController.text = widget.presetDestination!.trim();
      _selected = const LedgerBalance(currency: 'XRP', value: '0');
      _step = _SendStep.amount;
    }
    ScreenSecurity.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureBalances();
      if (_hasPresetDestination) {
        await _ensureDestinationPolicy();
      }
    });
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    _destinationController.dispose();
    _tagController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<LedgerBalance> get _balances {
    final list = ref
        .read(walletListControllerProvider)
        .balances[widget.account.id];
    return list ?? const <LedgerBalance>[];
  }

  Future<void> _ensureBalances() async {
    final existing = _balances;
    if (existing.isEmpty) {
      await ref
          .read(walletListControllerProvider.notifier)
          .refreshBalances(walletIds: [widget.account.id]);
    }
    if (!mounted) return;
    final balances = _balances;
    if (_hasPresetDestination) {
      final xrp = balances.where((b) => b.currency == 'XRP');
      setState(() {
        _selected = xrp.isEmpty
            ? const LedgerBalance(currency: 'XRP', value: '0')
            : xrp.first;
      });
      return;
    }
    if (_selected == null && balances.isNotEmpty) {
      setState(() {
        _selected = balances.firstWhere(
          (b) => b.currency == 'XRP',
          orElse: () => balances.first,
        );
      });
    } else if (_selected == null) {
      setState(() {
        _selected = const LedgerBalance(currency: 'XRP', value: '0');
      });
    }
  }

  Future<void> _ensureConnected() async {
    final net = ref.read(networkControllerProvider);
    if (!net.isConnected) {
      await ref.read(networkControllerProvider.notifier).connect();
    }
    final after = ref.read(networkControllerProvider);
    if (!after.isConnected) {
      throw StateError(after.errorMessage ?? 'Not connected to network');
    }
  }

  String get _stepTitle => switch (_step) {
    _SendStep.asset => 'Select asset',
    _SendStep.destination => 'Destination',
    _SendStep.amount => 'Amount',
    _SendStep.review => 'Review',
    _SendStep.result => 'Result',
  };

  int get _stepIndex => _SendStep.values.indexOf(_step);

  void _goTo(_SendStep step) {
    setState(() {
      _error = null;
      _step = step;
    });
  }

  void _back() {
    if (_busy) return;
    switch (_step) {
      case _SendStep.asset:
        Navigator.of(context).pop();
      case _SendStep.destination:
        _goTo(_SendStep.asset);
      case _SendStep.amount:
        if (_hasPresetDestination) {
          Navigator.of(context).pop();
        } else {
          _goTo(_SendStep.destination);
        }
      case _SendStep.review:
        _goTo(_SendStep.amount);
      case _SendStep.result:
        Navigator.of(context).pop(_result?.isSuccess == true);
    }
  }

  void _continueFromAsset() {
    if (_selected == null) {
      setState(() => _error = 'Select an asset to send');
      return;
    }
    _goTo(_SendStep.destination);
  }

  Future<void> _continueFromDestination() async {
    final dest = _destinationController.text.trim();
    if (!AddressValidator.isValidClassic(dest)) {
      setState(() => _error = 'Enter a valid XRPL classic address');
      return;
    }
    if (dest == widget.account.address) {
      setState(() => _error = 'Destination cannot be the same as this wallet');
      return;
    }
    final int? tag;
    try {
      tag = PaymentValidators.parseDestinationTag(_tagController.text);
    } on FormatException {
      setState(() => _error = 'Destination tag is invalid.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await _ensureConnected();
      final policy = await _loadDestinationPolicy(dest);
      final isXrp = _selected == null || _selected!.currency == 'XRP';
      final policyError = policy.sendError(isXrp: isXrp, destinationTag: tag);
      if (policyError != null) {
        if (!mounted) return;
        setState(() {
          _error = policyError;
          _busy = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _busy = false);
      _goTo(_SendStep.amount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _busy = false;
      });
    }
  }

  Future<DestinationAccountPolicy> _loadDestinationPolicy(String dest) async {
    final policy = await ref
        .read(xrplRpcClientProvider)
        .fetchDestinationPolicy(dest);
    if (mounted) setState(() => _destPolicy = policy);
    return policy;
  }

  Future<void> _ensureDestinationPolicy() async {
    final dest = _destinationController.text.trim();
    if (!AddressValidator.isValidClassic(dest)) return;
    try {
      await _ensureConnected();
      final policy = await _loadDestinationPolicy(dest);
      if (!mounted) return;
      int? tag;
      try {
        tag = PaymentValidators.parseDestinationTag(_tagController.text);
      } on FormatException {
        tag = null;
      }
      final isXrp = _selected == null || _selected!.currency == 'XRP';
      final policyError = policy.sendError(isXrp: isXrp, destinationTag: tag);
      if (policyError != null) {
        setState(() => _error = policyError);
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingError(e));
    }
  }

  Future<void> _continueFromAmount() async {
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'No asset selected');
      return;
    }
    final amount = _amountController.text;
    final err = selected.currency == 'XRP'
        ? PaymentValidators.validateXrpAmount(amount)
        : PaymentValidators.validateIouAmount(amount);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await _ensureConnected();
      final dest = _destinationController.text.trim();
      final policy = _destPolicy ?? await _loadDestinationPolicy(dest);
      int? tag;
      try {
        tag = PaymentValidators.parseDestinationTag(_tagController.text);
      } on FormatException {
        if (!mounted) return;
        setState(() {
          _error = 'Destination tag is invalid.';
          _busy = false;
        });
        return;
      }
      final isXrp = selected.currency == 'XRP';
      final policyError = policy.sendError(isXrp: isXrp, destinationTag: tag);
      if (policyError != null) {
        if (!mounted) return;
        setState(() {
          _error = policyError;
          _busy = false;
        });
        return;
      }

      final feeDrops =
          (await ref.read(xrplRpcClientProvider).fetchMinimumFeeDrops())
              .toString();
      final feeErr = PaymentValidators.validateFeeDrops(feeDrops);
      if (feeErr != null) {
        if (!mounted) return;
        setState(() {
          _error = feeErr;
          _busy = false;
        });
        return;
      }

      if (isXrp) {
        final spendErr = PaymentValidators.validateXrpSpendable(
          amountXrp: amount,
          availableXrp: selected.value,
          feeDrops: feeDrops,
          destUnfunded: !policy.exists,
        );
        if (spendErr != null) {
          if (!mounted) return;
          setState(() {
            _error = spendErr;
            _busy = false;
          });
          return;
        }
      } else if (PaymentValidators.compareDecimal(amount, selected.value) > 0) {
        if (!mounted) return;
        setState(() {
          _error = 'Amount exceeds available balance';
          _busy = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _feeDrops = feeDrops;
        _feeError = null;
        _feeBusy = false;
        _busy = false;
      });
      _goTo(_SendStep.review);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _busy = false;
      });
    }
  }

  String get _amountLabel {
    final s = _selected;
    if (s == null) return '';
    if (s.currency == 'XRP') return '${_amountController.text.trim()} XRP';
    final sym = CurrencyDisplay.symbol(s.currency, issuer: s.issuer);
    return '${_amountController.text.trim()} $sym';
  }

  Future<void> _submit() async {
    final selected = _selected;
    if (selected == null) return;
    if (_feeBusy || _feeError != null || _feeDrops == null) return;

    final pinOk = await promptAndVerifyWalletPin(
      context,
      ref,
      title: 'Confirm send',
      message: 'Enter your wallet PIN to sign and submit this payment.',
      confirmLabel: 'Sign',
    );
    if (!pinOk || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    String? secret;
    try {
      await _ensureConnected();

      final rpc = ref.read(xrplRpcClientProvider).requireProvider();
      final dest = _destinationController.text.trim();
      final tag = PaymentValidators.parseDestinationTag(_tagController.text);
      final account = widget.account;

      final PaymentSubmitResult result;
      if (account.useLedger) {
        result = await _submitWithLedger(
          account: account,
          selected: selected,
          dest: dest,
          tag: tag,
          rpc: rpc,
        );
      } else {
        final vault = ref.read(keyVaultProvider);
        secret = await vault.readSecret(account.id);
        if (secret == null || secret.isEmpty) {
          throw StateError('No secret found for this wallet');
        }

        if (selected.currency == 'XRP') {
          result = await _paymentService.sendXrp(
            walletId: account.id,
            secret: secret,
            fromAddress: account.address,
            destination: dest,
            destinationTag: tag,
            amountXrp: _amountController.text.trim(),
            rpc: rpc,
            expectedFeeDrops: _feeDrops,
          );
        } else {
          result = await _paymentService.sendIou(
            walletId: account.id,
            secret: secret,
            fromAddress: account.address,
            destination: dest,
            destinationTag: tag,
            currency: selected.currency,
            issuer: selected.issuer ?? '',
            value: _amountController.text.trim(),
            rpc: rpc,
            expectedFeeDrops: _feeDrops,
          );
        }
      }

      // Best-effort balance refresh after successful submit.
      if (result.isSuccess) {
        // ignore: unawaited_futures
        ref
            .read(walletListControllerProvider.notifier)
            .refreshBalances(walletIds: [widget.account.id]);
      }

      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _SendStep.result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = widget.account.useLedger
            ? LedgerXrpDevice.userFacingError(e)
            : userFacingError(e);
        _busy = false;
      });
    } finally {
      // Drop local secret reference as soon as possible.
      secret = null;
    }
  }

  Future<PaymentSubmitResult> _submitWithLedger({
    required WalletAccount account,
    required LedgerBalance selected,
    required String dest,
    required int? tag,
    required XRPProvider rpc,
  }) async {
    if (!mounted) throw StateError('Widget disposed');
    final pathHint = "m/44'/144'/${account.ledgerAccountIndex}'/0/0";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Connect Ledger (USB), open the XRP app ($pathHint), '
          'then approve on the device…',
        ),
        duration: const Duration(seconds: 8),
      ),
    );

    final session = await LedgerXrpDevice.connectUsb();
    try {
      final got = await LedgerXrpDevice.getAddress(
        session,
        accountIndex: account.ledgerAccountIndex,
      );
      if (got.address != account.address) {
        throw StateError(
          'Ledger path $pathHint derives ${got.address}, which does not '
          'match this wallet (${account.address}). Uncheck Ledger Device '
          'or change the account index so the device address matches.',
        );
      }

      Future<String> signTxBlob(List<int> blob) async {
        final der = await LedgerXrpDevice.signTransaction(
          session,
          blob,
          accountIndex: account.ledgerAccountIndex,
        );
        return BytesUtils.toHexString(der, lowerCase: false);
      }

      if (selected.currency == 'XRP') {
        return await _paymentService.sendXrpWithLedger(
          fromAddress: account.address,
          destination: dest,
          destinationTag: tag,
          amountXrp: _amountController.text.trim(),
          rpc: rpc,
          publicKeyHex: got.publicKeyHex,
          signTransactionBlob: signTxBlob,
          expectedFeeDrops: _feeDrops,
        );
      }
      return await _paymentService.sendIouWithLedger(
        fromAddress: account.address,
        destination: dest,
        destinationTag: tag,
        currency: selected.currency,
        issuer: selected.issuer ?? '',
        value: _amountController.text.trim(),
        rpc: rpc,
        publicKeyHex: got.publicKeyHex,
        signTransactionBlob: signTxBlob,
        expectedFeeDrops: _feeDrops,
      );
    } finally {
      try {
        await session.close();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(networkControllerProvider);
    final listState = ref.watch(walletListControllerProvider);
    final balances =
        listState.balances[widget.account.id] ?? const <LedgerBalance>[];
    final preferred = widget.account.preferredNetwork;
    final networkMismatch = networkState.network != preferred;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hasPresetDestination
              ? 'Buy a coffee'
              : 'Send · ${widget.account.label}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _back,
        ),
      ),
      body: Column(
        children: [
          if (_step != _SendStep.result)
            LinearProgressIndicator(
              value: (_stepIndex + 1) / (_SendStep.values.length - 1),
            ),
          if (networkMismatch)
            MaterialBanner(
              content: Text(
                'Active network is ${networkState.network.label}, but this '
                'wallet prefers ${preferred.label}.',
              ),
              leading: const Icon(Icons.warning_amber_rounded),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await ref
                              .read(networkControllerProvider.notifier)
                              .setNetwork(preferred);
                          await ref
                              .read(networkControllerProvider.notifier)
                              .connect(network: preferred);
                        },
                  child: Text('Switch to ${preferred.label}'),
                ),
              ],
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_stepTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Network: ${networkState.network.label}'
                  '${networkState.isConnected ? '' : ' (not connected)'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ..._buildStepBody(context, balances, networkState),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildBottomActions(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStepBody(
    BuildContext context,
    List<LedgerBalance> balances,
    NetworkState networkState,
  ) {
    switch (_step) {
      case _SendStep.asset:
        return _buildAssetPicker(balances);
      case _SendStep.destination:
        return _buildDestinationFields();
      case _SendStep.amount:
        return _buildAmountFields();
      case _SendStep.review:
        return _buildReview(networkState);
      case _SendStep.result:
        return _buildResult();
    }
  }

  List<Widget> _buildAssetPicker(List<LedgerBalance> balances) {
    final items = balances.isEmpty
        ? const [LedgerBalance(currency: 'XRP', value: '0')]
        : balances;

    return [
      if (balances.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('No cached balances — showing XRP. Refresh if needed.'),
        ),
      ...items.map((b) {
        final selected =
            _selected != null &&
            _selected!.currency == b.currency &&
            _selected!.issuer == b.issuer;
        final title = CurrencyDisplay.title(b.currency, issuer: b.issuer);
        final symbol = CurrencyDisplay.symbol(b.currency, issuer: b.issuer);
        final subtitle = b.issuer == null
            ? 'Available: ${b.value} $symbol'
            : 'Issuer: ${b.issuer}\nAvailable: ${b.value} $symbol';
        return Card(
          child: ListTile(
            selected: selected,
            onTap: () => setState(() {
              _selected = b;
              _error = null;
            }),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: selected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : const Icon(Icons.circle_outlined),
          ),
        );
      }),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await ref
                      .read(walletListControllerProvider.notifier)
                      .refreshBalances(walletIds: [widget.account.id]);
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh balances'),
      ),
    ];
  }

  List<Widget> _buildDestinationFields() {
    return [
      TextField(
        controller: _destinationController,
        decoration: const InputDecoration(
          labelText: 'Destination address',
          hintText: 'r…',
          border: OutlineInputBorder(),
        ),
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.text,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        enabled: !_busy,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _tagController,
        decoration: const InputDecoration(
          labelText: 'Destination tag (optional)',
          hintText: 'e.g. 12345',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        enabled: !_busy,
      ),
    ];
  }

  List<Widget> _buildAmountFields() {
    final s = _selected;
    final currency = s == null
        ? 'XRP'
        : CurrencyDisplay.symbol(s.currency, issuer: s.issuer);
    final available = s?.value ?? '—';
    return [
      if (_hasPresetDestination) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.coffee),
          title: const Text('Coffee for the developer'),
          subtitle: Text(widget.presetDestination!),
        ),
        const SizedBox(height: 12),
      ],
      Text(
        'Available: $available $currency',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (s?.issuer != null) ...[
        const SizedBox(height: 4),
        Text(
          'Issuer: ${s!.issuer}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _amountController,
        decoration: InputDecoration(
          labelText: 'Amount ($currency)',
          border: const OutlineInputBorder(),
          suffixText: currency,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enabled: !_busy,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      ),
    ];
  }

  List<Widget> _buildReview(NetworkState networkState) {
    final s = _selected!;
    int? tag;
    try {
      tag = PaymentValidators.parseDestinationTag(_tagController.text);
    } catch (_) {}

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('From', widget.account.address),
              const Divider(height: 24),
              _reviewRow('To', _destinationController.text.trim()),
              if (tag != null) ...[
                const SizedBox(height: 8),
                _reviewRow('Destination tag', tag.toString()),
              ],
              const Divider(height: 24),
              _reviewRow('Amount', _amountLabel),
              if (s.issuer != null) ...[
                const SizedBox(height: 8),
                _reviewRow('Issuer', s.issuer!),
              ],
              const Divider(height: 24),
              _reviewRow('Network', networkState.network.label),
              const SizedBox(height: 8),
              _reviewRow('Fee', _feeReviewLabel),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Confirm to sign with the key stored on this device and broadcast '
        'the payment. This cannot be undone.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  String get _feeReviewLabel {
    if (_feeBusy) return 'Estimating…';
    if (_feeError != null) return _feeError!;
    final drops = _feeDrops;
    if (drops == null) return 'Unavailable';
    return '${XrpAmount.dropsToXrp(drops)} XRP';
  }

  Widget _reviewRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: value.startsWith('r') || value.length > 40
                ? 'monospace'
                : null,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResult() {
    final r = _result;
    if (r == null) {
      return [const Text('No result')];
    }
    final color = r.isSuccess
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return [
      Icon(
        r.isSuccess ? Icons.check_circle : Icons.error,
        size: 64,
        color: color,
      ),
      const SizedBox(height: 16),
      Text(
        r.isSuccess ? 'Payment submitted' : 'Submission failed',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
      ),
      const SizedBox(height: 12),
      _reviewRow('Engine result', r.engineResult),
      const SizedBox(height: 8),
      _reviewRow('Message', r.engineResultMessage),
      const SizedBox(height: 8),
      _reviewRow('Hash', r.hash),
      if (r.feeDrops != null) ...[
        const SizedBox(height: 8),
        _reviewRow('Fee', '${XrpAmount.dropsToXrp(r.feeDrops!)} XRP'),
      ],
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: r.hash));
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Hash copied')));
          }
        },
        icon: const Icon(Icons.copy),
        label: const Text('Copy hash'),
      ),
    ];
  }

  Widget _buildBottomActions(BuildContext context) {
    if (_step == _SendStep.result) {
      return FilledButton(
        onPressed: () => Navigator.of(context).pop(_result?.isSuccess == true),
        child: const Text('Done'),
      );
    }

    final isReview = _step == _SendStep.review;
    final reviewBlocked = isReview && (_feeBusy || _feeError != null);
    return Row(
      children: [
        if (_step != _SendStep.asset)
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _back,
              child: const Text('Back'),
            ),
          ),
        if (_step != _SendStep.asset) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: (_busy || reviewBlocked)
                ? null
                : () {
                    switch (_step) {
                      case _SendStep.asset:
                        _continueFromAsset();
                      case _SendStep.destination:
                        _continueFromDestination();
                      case _SendStep.amount:
                        _continueFromAmount();
                      case _SendStep.review:
                        _submit();
                      case _SendStep.result:
                        break;
                    }
                  },
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isReview ? Icons.send : Icons.arrow_forward),
            label: Text(
              _busy
                  ? (isReview ? 'Sending…' : 'Please wait…')
                  : (isReview ? 'Confirm & send' : 'Continue'),
            ),
          ),
        ),
      ],
    );
  }
}
