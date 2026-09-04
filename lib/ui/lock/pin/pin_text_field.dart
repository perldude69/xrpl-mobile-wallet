import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PIN entry that opts out of Autofill / IME learning.
class PinTextField extends StatelessWidget {
  const PinTextField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.autofocus = false,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 12,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      enabled: enabled,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofillHints: const <String>[],
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
    );
  }
}
