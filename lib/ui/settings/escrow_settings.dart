import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/data/payments/escrow_service.dart';
import 'package:xrpl_mobile_wallet/data/payments/payment_service.dart';
import 'package:xrpl_mobile_wallet/data/xrpl_rpc/xrpl_rpc_client.dart';
import 'package:xrpl_mobile_wallet/state/providers.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';
import 'package:xrpl_mobile_wallet/data/ledger_device/ledger_xrp_device.dart';
import 'package:xrpl_mobile_wallet/domain/amount/xrp_amount.dart';
import 'package:xrpl_mobile_wallet/ui/lock/pin/swipe_to_sign.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';
import 'package:blockchain_utils/utils/utils.dart';

class EscrowSettings extends ConsumerStatefulWidget {
  const EscrowSettings({super.key});
  @override
  ConsumerState<EscrowSettings> createState() => _EscrowSettingsState();
}

class _EscrowSettingsState extends ConsumerState<EscrowSettings> {
  List<XrpEscrow>? _escrows;
  BigInt? _reserveIncrementDrops;
  Object? _error;
  bool _hadPartialErrors = false;
  bool _loading = true;
  bool _busy = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _reload();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _escrows != null && !_busy) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _escrows == null;
      _error = null;
      _hadPartialErrors = false;
    });
    try {
      final wallets = ref.read(walletListControllerProvider).wallets;
      final client = ref.read(xrplRpcClientProvider);
      final catalog = await _service(
        client,
      ).listVisible(wallets.map((w) => w.address));
      BigInt? reserve;
      try {
        reserve = await client.fetchOwnerReserveIncrementDrops();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _escrows = catalog.escrows;
        _hadPartialErrors = catalog.hadErrors;
        _reserveIncrementDrops = reserve;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  EscrowService _service([XrplRpcClient? client]) => EscrowService(
    client ?? ref.read(xrplRpcClientProvider),
    payments: PaymentService(database: ref.read(databaseProvider)),
  );

  Set<String> get _localAddresses => ref
      .read(walletListControllerProvider)
      .wallets
      .map((w) => w.address)
      .toSet();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _escrows == null) {
      return _scroll([
        Text(_facing(_error!, ledger: false)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _reload, child: const Text('Retry')),
      ]);
    }
    final escrows = _escrows ?? const <XrpEscrow>[];
    return RefreshIndicator(
      onRefresh: _reload,
      child: _scroll([
        _inspectButton(),
        if (_hadPartialErrors) ...[
          const SizedBox(height: 12),
          Text(
            'Some wallets could not be queried. Pull to refresh or inspect by owner and sequence.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        if (escrows.isEmpty)
          const Text('No open XRP escrows found for these wallets.')
        else ...[
          _summary(escrows),
          const SizedBox(height: 12),
          ...escrows.map((e) => _row(context, e)),
        ],
      ]),
    );
  }

  Widget _summary(List<XrpEscrow> escrows) {
    final xrp = escrows.where((e) => e.isXrpAmount);
    BigInt drops = BigInt.zero;
    for (final e in xrp) {
      drops += BigInt.tryParse(e.amountDrops) ?? BigInt.zero;
    }
    final owned = escrows
        .where((e) => _localAddresses.contains(e.owner))
        .length;
    final locked = XrpAmount.dropsToXrp(drops.toString());
    final reserve = _reserveIncrementDrops;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$locked XRP locked in ${escrows.length} open escrow${escrows.length == 1 ? '' : 's'}.',
            ),
            if (owned > 0) ...[
              const SizedBox(height: 8),
              Text(
                reserve == null
                    ? 'Each escrow you own holds extra owner reserve until it is finished or cancelled.'
                    : 'About ${XrpAmount.dropsToXrp((reserve * BigInt.from(owned)).toString())} XRP extra owner reserve across $owned outgoing escrow${owned == 1 ? '' : 's'}.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, XrpEscrow escrow) {
    final now = DateTime.now().toUtc();
    final canFinish = escrow.canFinishAt(now);
    final canCancel = escrow.canCancelAt(now);
    final local = _localAddresses;
    final outgoing = local.contains(escrow.owner);
    final incoming = local.contains(escrow.destination);
    final direction = outgoing && incoming
        ? 'Self'
        : incoming
        ? 'Incoming'
        : 'Outgoing';
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    escrow.isXrpAmount
                        ? '${escrow.amountXrp} XRP'
                        : escrow.amountDrops,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('$direction · ${escrow.statusAt(now)}'),
                  const SizedBox(height: 8),
                  Text(
                    escrow.isXrpAmount
                        ? 'This XRP is locked until it is finished or cancelled.'
                        : 'Token escrow is not supported in this version.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (outgoing && _reserveIncrementDrops != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'About ${XrpAmount.dropsToXrp(_reserveIncrementDrops.toString())} XRP extra owner reserve until this escrow is closed.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Release available: ${_formatEscrowDate(escrow.finishAfterUtc)}',
                  ),
                  Text(
                    'Refund available: ${_formatEscrowDate(escrow.cancelAfterUtc)}',
                  ),
                  const SizedBox(height: 8),
                  Text('To ${escrow.destination}'),
                  if (escrow.destinationTag != null)
                    Text('Destination tag ${escrow.destinationTag}'),
                  Text(
                    'Owner ${escrow.owner} · Sequence ${escrow.sequence}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              enabled: !_busy && (canFinish || canCancel),
              onSelected: (action) => _submit(escrow, action),
              itemBuilder: (_) => [
                if (canFinish)
                  const PopupMenuItem(value: 'finish', child: Text('Finish')),
                if (canCancel)
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatEscrowDate(DateTime? value) {
    if (value == null) return 'not set';
    return DateFormat.yMMMd().add_jm().format(value.toLocal());
  }

  Widget _scroll(List<Widget> children) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    children: children,
  );

  Widget _inspectButton() => OutlinedButton.icon(
    onPressed: _busy ? null : _inspectForeign,
    icon: const Icon(Icons.search),
    label: const Text('Inspect escrow by owner and sequence'),
  );

  Future<void> _inspectForeign() async {
    final owner = TextEditingController();
    final sequence = TextEditingController();
    final input = await showDialog<(String, int)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inspect escrow'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: owner,
              decoration: const InputDecoration(labelText: 'Owner address'),
            ),
            TextField(
              controller: sequence,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Escrow sequence'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              owner.text.trim(),
              int.tryParse(sequence.text.trim()) ?? -1,
            )),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    owner.dispose();
    sequence.dispose();
    if (input == null || input.$2 < 0 || !mounted) return;
    try {
      final escrow = await _service().inspect(
        owner: input.$1,
        sequence: input.$2,
      );
      if (!mounted) return;
      if (escrow == null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Escrow details'),
            content: const Text(
              'No validated XRP escrow was found for that owner and sequence.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      final now = DateTime.now().toUtc();
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Escrow details'),
          content: SingleChildScrollView(
            child: Text(
              '${escrow.isXrpAmount ? '${escrow.amountXrp} XRP' : escrow.amountDrops}\n'
              '${escrow.statusAt(now)}\n'
              'To ${escrow.destination}\n'
              '${escrow.destinationTag == null ? '' : 'Destination tag ${escrow.destinationTag}\n'}'
              'Release available: ${_formatEscrowDate(escrow.finishAfterUtc)}\n'
              'Refund available: ${_formatEscrowDate(escrow.cancelAfterUtc)}\n'
              'Owner ${escrow.owner} · Sequence ${escrow.sequence}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (escrow.canFinishAt(now))
              FilledButton(
                onPressed: () => Navigator.pop(context, 'finish'),
                child: const Text('Finish'),
              ),
            if (escrow.canCancelAt(now))
              FilledButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Cancel'),
              ),
          ],
        ),
      );
      if (action != null && mounted) await _submit(escrow, action);
    } catch (e) {
      _snack(_facing(e, ledger: false));
    }
  }

  Future<void> _submit(XrpEscrow escrow, String action) async {
    if (_busy) return;
    final wallets = ref
        .read(walletListControllerProvider)
        .wallets
        .where((w) => w.canSign)
        .toList();
    if (wallets.isEmpty) {
      _snack('Add a signing wallet to pay the network fee.');
      return;
    }
    final feeWallet = await showModalBottomSheet<WalletAccount>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose fee-paying wallet')),
            ...wallets.map(
              (wallet) => ListTile(
                leading: PirateIcon(
                  glyph: wallet.useLedger
                      ? PirateGlyph.compass
                      : PirateGlyph.key,
                ),
                title: Text(wallet.label),
                subtitle: Text(
                  wallet.useLedger
                      ? 'Ledger · ${wallet.address}'
                      : wallet.address,
                ),
                onTap: () => Navigator.of(context).pop(wallet),
              ),
            ),
          ],
        ),
      ),
    );
    if (feeWallet == null || !mounted) return;

    BigInt? feeDrops;
    try {
      feeDrops = await ref.read(xrplRpcClientProvider).fetchMinimumFeeDrops();
    } catch (_) {}
    if (!mounted) return;

    final memoController = TextEditingController();
    final memo = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'finish' ? 'Review escrow finish' : 'Review escrow cancel',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                escrow.isXrpAmount
                    ? '${escrow.amountXrp} XRP'
                    : escrow.amountDrops,
              ),
              const SizedBox(height: 8),
              Text('To ${escrow.destination}'),
              Text('Owner ${escrow.owner}'),
              Text('Sequence ${escrow.sequence}'),
              Text(
                'Release available: ${_formatEscrowDate(escrow.finishAfterUtc)}',
              ),
              Text(
                'Refund available: ${_formatEscrowDate(escrow.cancelAfterUtc)}',
              ),
              const SizedBox(height: 12),
              Text('Fee wallet: ${feeWallet.label}'),
              Text(
                feeDrops == null
                    ? 'Network fee is confirmed at signing and capped for safety.'
                    : 'Estimated network fee: ${XrpAmount.dropsToXrp(feeDrops.toString())} XRP',
              ),
              const SizedBox(height: 12),
              Text(
                action == 'finish'
                    ? 'Finishing releases the locked XRP to the destination and frees the owner’s extra reserve.'
                    : 'Cancelling refunds the locked XRP to the owner and frees the extra reserve.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: memoController,
                maxLength: 256,
                decoration: const InputDecoration(labelText: 'Memo (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, memoController.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    memoController.dispose();
    if (memo == null || !mounted) return;

    final pinOk = await promptSwipeToSign(
      context,
      title: action == 'finish'
          ? 'Confirm escrow finish'
          : 'Confirm escrow cancel',
      message: 'Slide to sign and submit this transaction.',
    );
    if (!pinOk || !mounted) return;

    String? secret;
    if (!feeWallet.useLedger) {
      secret = await ref.read(keyVaultProvider).readSecret(feeWallet.id);
      if (secret == null || secret.isEmpty) {
        _snack('Selected fee wallet keys are unavailable.');
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final service = _service();
      final current = (await service.list(
        escrow.owner,
      )).where((e) => e.sequence == escrow.sequence).firstOrNull;
      if (current == null ||
          current.entry.toString() != escrow.entry.toString()) {
        throw StateError('Escrow changed or is no longer available.');
      }
      final now = DateTime.now().toUtc();
      if (action == 'finish' && !current.canFinishAt(now)) {
        throw StateError('This escrow is not eligible to finish yet.');
      }
      if (action == 'cancel' && !current.canCancelAt(now)) {
        throw StateError('This escrow is not eligible to cancel yet.');
      }
      final network = ref.read(networkControllerProvider).network.name;
      final fee = feeDrops?.toString();
      final result = feeWallet.useLedger
          ? await _submitLedger(
              service,
              current,
              feeWallet,
              action,
              memo,
              network,
              fee,
            )
          : action == 'finish'
          ? await service.finish(
              escrow: current,
              feeAccount: feeWallet.address,
              secret: secret!,
              provider: ref.read(xrplRpcClientProvider).requireProvider(),
              walletId: feeWallet.id,
              network: network,
              memo: memo,
              expectedFeeDrops: fee,
            )
          : await service.cancel(
              escrow: current,
              feeAccount: feeWallet.address,
              secret: secret!,
              provider: ref.read(xrplRpcClientProvider).requireProvider(),
              walletId: feeWallet.id,
              network: network,
              memo: memo,
              expectedFeeDrops: fee,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess ? 'Submitted' : result.engineResultMessage,
          ),
        ),
      );
      await _reload();
    } catch (e) {
      _snack(_facing(e, ledger: feeWallet.useLedger));
    } finally {
      secret = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<dynamic> _submitLedger(
    EscrowService service,
    XrpEscrow escrow,
    WalletAccount wallet,
    String action,
    String? memo,
    String network,
    String? expectedFeeDrops,
  ) async {
    final session = await LedgerXrpDevice.connectUsb();
    try {
      final got = await LedgerXrpDevice.getAddress(
        session,
        accountIndex: wallet.ledgerAccountIndex,
      );
      if (got.address != wallet.address) {
        throw StateError(
          'Ledger address does not match this wallet. Check the account index.',
        );
      }
      Future<String> sign(List<int> blob) async {
        final der = await LedgerXrpDevice.signTransaction(
          session,
          blob,
          accountIndex: wallet.ledgerAccountIndex,
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

      final provider = ref.read(xrplRpcClientProvider).requireProvider();
      return await (action == 'finish'
          ? service.finishWithLedger(
              escrow: escrow,
              feeAccount: wallet.address,
              walletId: wallet.id,
              network: network,
              provider: provider,
              publicKeyHex: got.publicKeyHex,
              signTransactionBlob: sign,
              memo: memo,
              expectedFeeDrops: expectedFeeDrops,
            )
          : service.cancelWithLedger(
              escrow: escrow,
              feeAccount: wallet.address,
              walletId: wallet.id,
              network: network,
              provider: provider,
              publicKeyHex: got.publicKeyHex,
              signTransactionBlob: sign,
              memo: memo,
              expectedFeeDrops: expectedFeeDrops,
            ));
    } finally {
      await session.close();
    }
  }

  String _facing(Object error, {required bool ledger}) {
    if (error is StateError) return error.message;
    if (error is ArgumentError) {
      return error.message ?? userFacingError(error);
    }
    return ledger
        ? LedgerXrpDevice.userFacingError(error)
        : userFacingError(error);
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
