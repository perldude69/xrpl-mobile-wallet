import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single BIP39 English word field with prefix autocomplete.
class Bip39WordField extends StatelessWidget {
  const Bip39WordField({
    super.key,
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.onSubmitted,
    this.nextFocusNode,
    this.onPasteMultiWord,
  });

  /// 1-based display index.
  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  /// After a suggestion tap or keyboard Next, focus this field.
  final FocusNode? nextFocusNode;

  /// When the user pastes multiple words into this field.
  final void Function(List<String> words)? onPasteMultiWord;

  static final List<String> _wordList = List<String>.from(
    Bip39Languages.english.wordList,
  );

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        // Multi-word paste: do not open suggestions.
        if (q.contains(' ')) return const Iterable<String>.empty();
        return _wordList.where((w) => w.startsWith(q)).take(8);
      },
      onSelected: (String selection) {
        controller.value = TextEditingValue(
          text: selection,
          selection: TextSelection.collapsed(offset: selection.length),
        );
        onSubmitted?.call(selection);
        _focusNext();
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 13),
          inputFormatters: [
            _MultiWordPasteFormatter(onMultiWord: onPasteMultiWord),
          ],
          decoration: InputDecoration(
            isDense: true,
            prefixText: '$index ',
            prefixStyle: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
          ),
          onSubmitted: (v) {
            onFieldSubmitted();
            onSubmitted?.call(v);
            _focusNext();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 160),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _focusNext() {
    final next = nextFocusNode;
    if (next == null) return;
    // Autocomplete re-asserts focus on this field after onSelected; wait
    // two frames so the next cell actually receives it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (next.canRequestFocus) next.requestFocus();
      });
    });
  }
}

/// Detects multi-word paste and notifies; leaves single words alone.
class _MultiWordPasteFormatter extends TextInputFormatter {
  _MultiWordPasteFormatter({this.onMultiWord});

  final void Function(List<String> words)? onMultiWord;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.length > 1 && onMultiWord != null) {
      // Defer so we do not mutate controllers during format.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMultiWord!(parts);
      });
      return oldValue;
    }
    return newValue;
  }
}
