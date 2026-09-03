import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xrpl_mobile_wallet/config/app_config.dart';
import 'package:xrpl_mobile_wallet/data/endpoints/endpoint_preferences.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_export.dart';

class ChangePinResult {
  const ChangePinResult({required this.current, required this.next});
  final String current;
  final String next;
}

enum GamePinAction { change, clear }

class GamePinDialogResult {
  const GamePinDialogResult({
    required this.walletPin,
    required this.gamePin,
  });
  final String walletPin;
  final String gamePin;
}

class ChangePinDialog extends StatefulWidget {
  const ChangePinDialog({super.key});

  @override
  State<ChangePinDialog> createState() => ChangePinDialogState();
}

class ChangePinDialogState extends State<ChangePinDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.clear();
    _next.clear();
    _confirm.clear();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;

    if (current.isEmpty) {
      setState(() => _error = 'Enter your current PIN');
      return;
    }
    if (next.length < AppConfig.pinMinLength ||
        !RegExp(r'^\d+$').hasMatch(next)) {
      setState(() {
        _error =
            'New PIN must be at least ${AppConfig.pinMinLength} digits';
      });
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'New PINs do not match');
      return;
    }
    Navigator.of(context).pop(
      ChangePinResult(current: current, next: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _current,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _next,
              decoration: const InputDecoration(
                labelText: 'New PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              decoration: const InputDecoration(
                labelText: 'Confirm new PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _submit(),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Update PIN'),
        ),
      ],
    );
  }
}

class GamePinDialog extends StatefulWidget {
  const GamePinDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
  });

  final String title;
  final String confirmLabel;

  @override
  State<GamePinDialog> createState() => _GamePinDialogState();
}

class _GamePinDialogState extends State<GamePinDialog> {
  final _wallet = TextEditingController();
  final _game = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _wallet.clear();
    _game.clear();
    _confirm.clear();
    _wallet.dispose();
    _game.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final wallet = _wallet.text;
    final game = _game.text;
    final confirm = _confirm.text;

    if (wallet.isEmpty) {
      setState(() => _error = 'Enter your wallet PIN');
      return;
    }
    if (game.length < AppConfig.pinMinLength ||
        !RegExp(r'^\d+$').hasMatch(game)) {
      setState(() {
        _error =
            'Game PIN must be at least ${AppConfig.pinMinLength} digits';
      });
      return;
    }
    if (game == wallet) {
      setState(() => _error = 'Game PIN must differ from the wallet PIN');
      return;
    }
    if (game != confirm) {
      setState(() => _error = 'Game PINs do not match');
      return;
    }
    Navigator.of(context).pop(
      GamePinDialogResult(walletPin: wallet, gamePin: game),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Opens Zerpland instead of the wallet when entered on unlock.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wallet,
              decoration: const InputDecoration(
                labelText: 'Wallet PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _game,
              decoration: const InputDecoration(
                labelText: 'Game PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              decoration: const InputDecoration(
                labelText: 'Confirm game PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _submit(),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class ConfirmWalletPinDialog extends StatefulWidget {
  const ConfirmWalletPinDialog({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  State<ConfirmWalletPinDialog> createState() => ConfirmWalletPinDialogState();
}

class ConfirmWalletPinDialogState extends State<ConfirmWalletPinDialog> {
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.clear();
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pin.text;
    if (pin.isEmpty) {
      setState(() => _error = 'Enter your wallet PIN');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              decoration: const InputDecoration(
                labelText: 'Wallet PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 12,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _submit(),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Clear game PIN'),
        ),
      ],
    );
  }
}

/// Password entry for encrypted export / import (not the app unlock PIN).
class PasswordDialog extends StatefulWidget {
  const PasswordDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.requireConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool requireConfirm;

  @override
  State<PasswordDialog> createState() => PasswordDialogState();
}

class PasswordDialogState extends State<PasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _password.clear();
    _confirm.clear();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _password.text;
    if (p.length < WalletExport.minPasswordLength) {
      setState(() {
        _error =
            'Password must be at least ${WalletExport.minPasswordLength} characters';
      });
      return;
    }
    if (widget.requireConfirm && p != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              autofocus: true,
              onSubmitted: widget.requireConfirm ? null : (_) => _submit(),
            ),
            if (widget.requireConfirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class CustomEndpointDraft {
  const CustomEndpointDraft({required this.label, required this.url});
  final String label;
  final String url;
}

class CustomEndpointDialog extends StatefulWidget {
  const CustomEndpointDialog({
    super.key,
    required this.kind,
    this.initialLabel,
    this.initialUrl,
  });

  final EndpointKind kind;
  final String? initialLabel;
  final String? initialUrl;

  @override
  State<CustomEndpointDialog> createState() => CustomEndpointDialogState();
}

class CustomEndpointDialogState extends State<CustomEndpointDialog> {
  late final TextEditingController _label;
  late final TextEditingController _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.initialLabel ?? '');
    _url = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final error = EndpointUrl.validate(kind: widget.kind, url: _url.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      CustomEndpointDraft(label: _label.text.trim(), url: _url.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHttp = widget.kind == EndpointKind.http;
    return AlertDialog(
      title: Text(isHttp ? 'HTTPS JSON-RPC node' : 'WSS node'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: isHttp ? 'https://…' : 'wss://…',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
