import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/secure/screen_security.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_importer.dart';
import 'package:xrpl_mobile_wallet/domain/validation/mnemonic_grid.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/import/bip39_word_field.dart';
import 'package:xrpl_mobile_wallet/ui/user_facing_error.dart';

enum AttachKeysMode { pasteMnemonic, gridMnemonic, familySeed }

/// Entry UI for attaching keys to a watch-only wallet.
class AttachKeysEntryScreen extends ConsumerStatefulWidget {
  const AttachKeysEntryScreen({
    super.key,
    required this.walletId,
    required this.address,
    required this.label,
    required this.mode,
  });

  final String walletId;
  final String address;
  final String label;
  final AttachKeysMode mode;

  @override
  ConsumerState<AttachKeysEntryScreen> createState() =>
      _AttachKeysEntryScreenState();
}

class _AttachKeysEntryScreenState extends ConsumerState<AttachKeysEntryScreen> {
  final _importer = WalletImporter();
  final _pasteController = TextEditingController();
  final _seedController = TextEditingController();
  late final List<TextEditingController> _gridControllers;
  late final List<FocusNode> _gridFocus;
  String? _error;
  bool _busy = false;
  bool _obscureSeed = true;

  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
    _gridControllers = List.generate(
      MnemonicGrid.slotCount,
      (_) => TextEditingController(),
    );
    _gridFocus = List.generate(MnemonicGrid.slotCount, (_) => FocusNode());
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    _scrub(_pasteController);
    _scrub(_seedController);
    for (final c in _gridControllers) {
      _scrub(c);
      c.dispose();
    }
    for (final f in _gridFocus) {
      f.dispose();
    }
    _pasteController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  void _scrub(TextEditingController c) {
    final len = c.text.length;
    if (len > 0) {
      c.value = TextEditingValue(
        text: ' ' * len,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    c.clear();
  }

  String get _title {
    switch (widget.mode) {
      case AttachKeysMode.pasteMnemonic:
        return 'Paste phrase';
      case AttachKeysMode.gridMnemonic:
        return 'Enter phrase';
      case AttachKeysMode.familySeed:
        return 'Family seed';
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final DerivedSecret material;
      switch (widget.mode) {
        case AttachKeysMode.pasteMnemonic:
          material = _importer.deriveMnemonicForAddress(
            _pasteController.text,
            expectedAddress: widget.address,
          );
        case AttachKeysMode.gridMnemonic:
          final phrase = MnemonicGrid.phraseFromCells(
            _gridControllers.map((c) => c.text).toList(),
          );
          material = _importer.deriveMnemonicForAddress(
            phrase,
            expectedAddress: widget.address,
          );
        case AttachKeysMode.familySeed:
          material = _importer.deriveFamilySeedForAddress(
            _seedController.text,
            expectedAddress: widget.address,
          );
      }

      await ref
          .read(walletListControllerProvider.notifier)
          .attachKeys(widget.walletId, material);

      _scrub(_pasteController);
      _scrub(_seedController);
      for (final c in _gridControllers) {
        _scrub(c);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (e) {
      setState(
        () => _error = userFacingError(
          e,
          fallback: 'The key material is invalid.',
        ),
      );
    } catch (e) {
      setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillGridFromWords(List<String> words, {int startIndex = 0}) {
    final normalized = words
        .map(MnemonicGrid.normalizeWord)
        .where((w) => w.isNotEmpty)
        .toList();
    for (var i = 0; i < MnemonicGrid.slotCount; i++) {
      final src = startIndex + i;
      _gridControllers[i].text = src < normalized.length ? normalized[src] : '';
    }
    setState(() => _error = null);
    final nextEmpty = _gridControllers.indexWhere((c) => c.text.isEmpty);
    if (nextEmpty >= 0 && nextEmpty < _gridFocus.length) {
      _gridFocus[nextEmpty].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _pastePhraseIntoGrid() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = 'Clipboard is empty');
      return;
    }
    _fillGridFromWords(MnemonicGrid.splitPaste(text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(
            widget.address,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 20),
          switch (widget.mode) {
            AttachKeysMode.pasteMnemonic => _buildPaste(),
            AttachKeysMode.gridMnemonic => _buildGrid(),
            AttachKeysMode.familySeed => _buildSeed(),
          },
          if (_error != null) ...[
            const SizedBox(height: 16),
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
                : const Icon(Icons.key),
            label: Text(_busy ? 'Checking…' : 'Add keys'),
          ),
          const SizedBox(height: 12),
          Text(
            'Your secret is stored only in encrypted device storage. '
            'It must match this wallet’s address.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPaste() {
    return TextField(
      controller: _pasteController,
      enabled: !_busy,
      minLines: 3,
      maxLines: 6,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: const <String>[],
      keyboardType: TextInputType.visiblePassword,
      decoration: const InputDecoration(
        labelText: 'Recovery phrase',
        hintText: '12 or 24 words',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _buildSeed() {
    return TextField(
      controller: _seedController,
      enabled: !_busy,
      obscureText: _obscureSeed,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: const <String>[],
      decoration: InputDecoration(
        labelText: 'Family seed',
        hintText: 's…',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscureSeed ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureSeed = !_obscureSeed),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter 24 words (or the first 12 only). Autocomplete uses the '
          'English BIP39 list.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pastePhraseIntoGrid,
          icon: const Icon(Icons.content_paste),
          label: const Text('Paste phrase into grid'),
        ),
        const SizedBox(height: 12),
        for (var row = 0; row < 8; row++) ...[
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: Bip39WordField(
                    index: row * 3 + col + 1,
                    controller: _gridControllers[row * 3 + col],
                    focusNode: _gridFocus[row * 3 + col],
                    enabled: !_busy,
                    nextFocusNode: row * 3 + col + 1 < _gridFocus.length
                        ? _gridFocus[row * 3 + col + 1]
                        : null,
                    onPasteMultiWord: (words) {
                      _fillGridFromWords(words, startIndex: 0);
                    },
                  ),
                ),
              ],
            ],
          ),
          if (row < 7) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
