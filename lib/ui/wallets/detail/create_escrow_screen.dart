import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/ledger_device/ledger_xrp_device.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/domain/validation/address_validator.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/state/activity_controller.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/swipe_to_sign.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';

class CreateEscrowScreen extends ConsumerStatefulWidget {
  const CreateEscrowScreen({super.key, required this.account});
  final WalletAccount account;
  @override
  ConsumerState<CreateEscrowScreen> createState() => _CreateEscrowScreenState();
}

class _CreateEscrowScreenState extends ConsumerState<CreateEscrowScreen> {
  final _destination = TextEditingController();
  final _tag = TextEditingController();
  final _amount = TextEditingController();
  late DateTime _finish;
  late DateTime _cancel;
  bool _lockForMyself = false;
  bool _busy = false;
  BigInt? _reserveIncrementDrops;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _finish = now.add(const Duration(hours: 1));
    _cancel = now.add(const Duration(hours: 2));
    _loadReserve();
  }

  Future<void> _loadReserve() async {
    try {
      final inc = await ref
          .read(xrplRpcClientProvider)
          .fetchOwnerReserveIncrementDrops();
      if (mounted) setState(() => _reserveIncrementDrops = inc);
    } catch (_) {}
  }

  String get _reserveCopy {
    final inc = _reserveIncrementDrops;
    if (inc == null) {
      return 'The amount is locked until release or refund, and this wallet holds extra owner reserve until the escrow is closed.';
    }
    return 'The amount is locked until release or refund, and about ${XrpAmount.dropsToXrp(inc.toString())} XRP extra owner reserve is held until the escrow is closed.';
  }

  @override
  void dispose() {
    _destination.dispose();
    _tag.dispose();
    _amount.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date at $time';
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final parts = <String>[];
    if (days > 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
    if (hours > 0) parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
    if (minutes > 0 || parts.isEmpty) {
      parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
    }
    return parts.join(', ');
  }

  Future<DateTime?> _pickDateTime(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: current.toLocal(),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current.toLocal()),
    );
    if (time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc();
  }

  Future<void> _pickFinish() async {
    final value = await _pickDateTime(_finish);
    if (value != null) setState(() => _finish = value);
  }

  Future<void> _pickCancel() async {
    final value = await _pickDateTime(_cancel);
    if (value != null) setState(() => _cancel = value);
  }

  Future<void> _submit() async {
    final finish = _finish, cancel = _cancel;
    final error = PaymentService.validateEscrowTimes(finish, cancel);
    if (error != null) {
      _show(error);
      return;
    }
    final amountError = PaymentValidators.validateXrpAmount(_amount.text);
    if (amountError != null) {
      _show(amountError);
      return;
    }
    final destination = _lockForMyself
        ? widget.account.address
        : _destination.text.trim();
    if (!_lockForMyself && !AddressValidator.isValidClassic(destination)) {
      _show('Enter a valid destination address.');
      return;
    }
    final int? destinationTag;
    try {
      destinationTag = _lockForMyself
          ? null
          : PaymentValidators.parseDestinationTag(_tag.text);
    } on FormatException catch (e) {
      _show(e.message);
      return;
    }

    final client = ref.read(xrplRpcClientProvider);
    final DestinationAccountPolicy policy;
    final BigInt feeDrops;
    try {
      policy = await client.fetchDestinationPolicy(destination);
      final destError = policy.sendError(
        isXrp: true,
        destinationTag: destinationTag,
      );
      if (destError != null) {
        _show(destError);
        return;
      }
      feeDrops = await client.fetchMinimumFeeDrops();
      final info = await client.fetchAccountReserveInfo(widget.account.address);
      final spendableError = PaymentService.validateEscrowCreateSpendable(
        amountXrp: _amount.text,
        balanceDrops: info.xrpBalanceDrops,
        currentReserveDrops: info.currentReserveDrops,
        reserveIncrementDrops: info.incrementDrops,
        feeDrops: feeDrops.toString(),
        destUnfunded: !policy.exists,
      );
      if (spendableError != null) {
        _show(spendableError);
        return;
      }
      if (mounted) {
        setState(() => _reserveIncrementDrops = info.incrementDrops);
      }
    } catch (e) {
      _show(userFacingError(e));
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review escrow'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_amount.text.trim()} XRP'),
              const SizedBox(height: 8),
              Text(
                _lockForMyself
                    ? 'Destination: This wallet'
                    : 'To: $destination',
              ),
              if (destinationTag != null)
                Text('Destination tag $destinationTag'),
              Text('Available: ${_formatDateTime(finish)}'),
              Text('Refund available: ${_formatDateTime(cancel)}'),
              const SizedBox(height: 12),
              Text(
                'Estimated network fee: ${XrpAmount.dropsToXrp(feeDrops.toString())} XRP',
              ),
              const SizedBox(height: 12),
              Text(_reserveCopy),
              const SizedBox(height: 12),
              const Text('This transaction cannot be edited after signing.'),
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
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await promptSwipeToSign(
      context,
      title: 'Confirm escrow',
      message: 'Slide to sign and submit this XRP escrow.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    String? secret;
    try {
      final rpc = client.requireProvider();
      final account = widget.account;
      final payments = PaymentService(database: ref.read(databaseProvider));
      final network = ref.read(networkControllerProvider).network.name;
      final fee = feeDrops.toString();
      final PaymentSubmitResult result;
      if (account.useLedger) {
        final session = await LedgerXrpDevice.connectUsb();
        try {
          final got = await LedgerXrpDevice.getAddress(
            session,
            accountIndex: account.ledgerAccountIndex,
          );
          if (got.address != account.address) {
            throw StateError('Ledger address does not match this wallet.');
          }
          Future<String> sign(List<int> blob) async {
            final der = await LedgerXrpDevice.signTransaction(
              session,
              blob,
              accountIndex: account.ledgerAccountIndex,
            );
            if (!verifyLedgerSignature(
              publicKeyHex: got.publicKeyHex,
              transactionBlob: blob,
              derSignature: der,
            )) {
              throw StateError('Ledger returned an invalid signature.');
            }
            return der
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join()
                .toUpperCase();
          }

          result = await payments.createXrpEscrowWithLedger(
            walletId: account.id,
            network: network,
            fromAddress: account.address,
            destination: destination,
            destinationTag: destinationTag,
            amountXrp: _amount.text,
            finishAfter: finish,
            cancelAfter: cancel,
            rpc: rpc,
            publicKeyHex: got.publicKeyHex,
            signTransactionBlob: sign,
            expectedFeeDrops: fee,
          );
        } finally {
          await session.close();
        }
      } else {
        secret = await ref.read(keyVaultProvider).readSecret(account.id);
        if (secret == null || secret.isEmpty) {
          throw StateError('No secret found for this wallet');
        }
        result = await payments.createXrpEscrow(
          walletId: account.id,
          network: network,
          secret: secret,
          fromAddress: account.address,
          destination: destination,
          destinationTag: destinationTag,
          amountXrp: _amount.text,
          finishAfter: finish,
          cancelAfter: cancel,
          rpc: rpc,
          expectedFeeDrops: fee,
        );
      }
      if (!mounted) return;
      _show(
        result.isSuccess
            ? 'Escrow submitted (${result.hash.substring(0, 12)}...)'
            : result.engineResultMessage,
      );
      if (result.isSuccess) {
        await ref
            .read(walletListControllerProvider.notifier)
            .refreshBalances(walletIds: [account.id]);
        await ref
            .read(activityControllerProvider.notifier)
            .refreshFromNetwork();
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _show(
          widget.account.useLedger
              ? LedgerXrpDevice.userFacingError(e)
              : userFacingError(e),
        );
      }
    } finally {
      secret = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Widget _field(String label, TextEditingController c, {TextInputType? type}) =>
      TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create XRP escrow')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Set aside XRP until a chosen release time. Ledger timing can vary by a few seconds.',
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lock up for myself'),
          subtitle: const Text('Send the escrow back to this wallet.'),
          value: _lockForMyself,
          onChanged: (value) => setState(() => _lockForMyself = value),
        ),
        if (!_lockForMyself) ...[
          _field('Destination address', _destination),
          _field(
            'Destination tag (optional)',
            _tag,
            type: TextInputType.number,
          ),
        ],
        _field(
          'Amount (XRP)',
          _amount,
          type: const TextInputType.numberWithOptions(decimal: true),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available),
          title: const Text('Available to release'),
          subtitle: Text(_formatDateTime(_finish)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickFinish,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.assignment_return_outlined),
          title: const Text('Refund available after'),
          subtitle: Text(_formatDateTime(_cancel)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickCancel,
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(
              'Locked for ${_formatDuration(_finish.difference(DateTime.now().toUtc()))}',
            ),
            subtitle: Text(
              'Refund window opens ${_formatDuration(_cancel.difference(_finish))} after release. $_reserveCopy',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const PirateIcon(glyph: PirateGlyph.shovel),
          label: const Text('Sign and submit escrow'),
        ),
      ],
    ),
  );
}
