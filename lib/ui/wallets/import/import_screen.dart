import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/secure/screen_security.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/state/network_controller.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/import/qr_scan_screen.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';
import 'package:xrpl_mobile_wallet/domain/validation/mnemonic_grid.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/import/bip39_word_field.dart';

enum _ImportTab { mnemonic, familySeed, watchAddress }

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _ImportTab _tab = _ImportTab.mnemonic;
  final _labelController = TextEditingController();
  final _secretController = TextEditingController();
  final _mnemonicControllers = List.generate(
    MnemonicGrid.slotCount,
    (_) => TextEditingController(),
  );
  final _mnemonicFocus = List.generate(
    MnemonicGrid.slotCount,
    (_) => FocusNode(),
  );
  String? _error;
  bool _busy = false;
  bool _obscureSecret = true;

  final _importer = WalletImporter();

  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    // Scrub secret material from the controller before release.
    _clearSecretField();
    _labelController.dispose();
    _secretController.dispose();
    for (final controller in _mnemonicControllers) {
      controller.dispose();
    }
    for (final focus in _mnemonicFocus) {
      focus.dispose();
    }
    super.dispose();
  }

  void _clearSecretField() {
    // Overwrite then clear so residual text is less likely to linger.
    final len = _secretController.text.length;
    if (len > 0) {
      _secretController.value = TextEditingValue(
        text: ' ' * len,
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    _secretController.clear();
  }

  Future<void> _submit() async {
    final label = _labelController.text;
    final String secret;
    try {
      secret = _tab == _ImportTab.mnemonic
          ? MnemonicGrid.phraseFromCells(
              _mnemonicControllers.map((c) => c.text).toList(),
            )
          : _secretController.text;
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString());
      return;
    }
    final network = ref.read(networkControllerProvider).network;

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final ImportResult result;
      switch (_tab) {
        case _ImportTab.mnemonic:
          result = _importer.importMnemonic(
            secret,
            label: label,
            network: network,
          );
        case _ImportTab.familySeed:
          result = _importer.importFamilySeed(
            secret,
            label: label,
            network: network,
          );
        case _ImportTab.watchAddress:
          result = _importer.importWatchOnly(
            secret,
            label: label,
            network: network,
          );
      }

      await ref.read(walletListControllerProvider.notifier).addImported(result);

      _labelController.clear();
      _clearSecretField();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      setState(
        () => _error = userFacingError(
          e,
          fallback: 'The imported value is invalid.',
        ),
      );
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _secretHint {
    switch (_tab) {
      case _ImportTab.mnemonic:
        return '12 or 24 word recovery phrase';
      case _ImportTab.familySeed:
        return 'Family seed (starts with s…)';
      case _ImportTab.watchAddress:
        return 'Classic address (r…)';
    }
  }

  String get _secretLabel {
    switch (_tab) {
      case _ImportTab.mnemonic:
        return 'Mnemonic';
      case _ImportTab.familySeed:
        return 'Family seed';
      case _ImportTab.watchAddress:
        return 'Address';
    }
  }

  bool get _isSecretField =>
      _tab == _ImportTab.mnemonic || _tab == _ImportTab.familySeed;

  bool get _cameraSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _scanQr() async {
    final address = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (address == null || !mounted) return;
    setState(() {
      _secretController.text = address;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkControllerProvider).network;

    return Scaffold(
      appBar: AppBar(title: const Text('Import wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_ImportTab>(
            segments: const [
              ButtonSegment(
                value: _ImportTab.mnemonic,
                label: Text('Mnemonic'),
                icon: Icon(Icons.password),
              ),
              ButtonSegment(
                value: _ImportTab.familySeed,
                label: Text('Seed'),
                icon: Icon(Icons.key),
              ),
              ButtonSegment(
                value: _ImportTab.watchAddress,
                label: Text('Watch'),
                icon: Icon(Icons.visibility),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) {
              setState(() {
                _tab = s.first;
                _error = null;
                _clearSecretField();
                for (final controller in _mnemonicControllers) {
                  controller.clear();
                }
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'e.g. Savings',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          const SizedBox(height: 16),
          if (_tab == _ImportTab.mnemonic)
            _MnemonicImportGrid(
              controllers: _mnemonicControllers,
              focusNodes: _mnemonicFocus,
              enabled: !_busy,
              onPaste: _fillMnemonic,
            )
          else
            TextField(
              controller: _secretController,
              decoration: InputDecoration(
                labelText: _secretLabel,
                hintText: _secretHint,
                border: const OutlineInputBorder(),
                suffixIcon: _isSecretField
                    ? IconButton(
                        icon: Icon(
                          _obscureSecret
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _obscureSecret = !_obscureSecret),
                      )
                    : (_tab == _ImportTab.watchAddress && _cameraSupported
                          ? IconButton(
                              tooltip: 'Scan QR code',
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _busy ? null : _scanQr,
                            )
                          : null),
              ),
              obscureText: _isSecretField && _obscureSecret,
              enableSuggestions: !_isSecretField,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              autofillHints: const <String>[],
              keyboardType: TextInputType.text,
              inputFormatters: _tab == _ImportTab.watchAddress
                  ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
                  : null,
              enabled: !_busy,
            ),
          if (_tab == _ImportTab.watchAddress && _cameraSupported) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _scanQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan address QR'),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Network: ${network.label}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_busy ? 'Importing…' : 'Import'),
          ),
          if (_isSecretField) ...[
            const SizedBox(height: 16),
            Text(
              'Your secret is stored only in encrypted device storage and never leaves this phone.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  void _fillMnemonic(List<String> words) {
    for (var i = 0; i < _mnemonicControllers.length; i++) {
      _mnemonicControllers[i].text = i < words.length ? words[i] : '';
    }
    setState(() => _error = null);
  }
}

class _MnemonicImportGrid extends StatelessWidget {
  const _MnemonicImportGrid({
    required this.controllers,
    required this.focusNodes,
    required this.enabled,
    required this.onPaste,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool enabled;
  final ValueChanged<List<String>> onPaste;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recovery phrase', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MnemonicGrid.slotCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.7,
          ),
          itemBuilder: (context, index) => Bip39WordField(
            index: index + 1,
            controller: controllers[index],
            focusNode: focusNodes[index],
            enabled: enabled,
            onPasteMultiWord: onPaste,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter 12 words in fields 1–12, or fill all 24 fields. Tap a suggestion to avoid spelling errors.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
