import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/data/secure/screen_security.dart';
import 'package:xrpl_mobile_wallet/data/wallet/entropy_mixer.dart';
import 'package:xrpl_mobile_wallet/data/wallet/wallet_generator.dart';
import 'package:xrpl_mobile_wallet/state/network_controller.dart';
import 'package:xrpl_mobile_wallet/state/wallet_list_controller.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/create/dice_entropy_pad.dart';

enum _CreateStep { label, dice, word, reveal, quiz }

/// Guided flow: label → dice ritual → personal word → mix → backup → quiz → save.
class CreateWalletScreen extends ConsumerStatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  ConsumerState<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends ConsumerState<CreateWalletScreen> {
  final _generator = WalletGenerator();
  final _labelController = TextEditingController();
  final _wordController = TextEditingController();
  final GlobalKey<DiceEntropyPadState> _dicePadKey =
      GlobalKey<DiceEntropyPadState>();

  _CreateStep _step = _CreateStep.label;
  String? _mnemonic;
  List<String> _words = const [];
  List<MnemonicQuizItem> _quiz = const [];
  final Map<int, String> _answers = {};
  String? _error;
  bool _busy = false;
  bool _wroteDown = false;
  bool _phraseVisible = true;

  // Ritual state
  double _motionScore = 0;
  List<DiceRollSample> _rolls = const [];
  double _wordStrength = 0;
  /// Once true, the dice pad stays mounted (hidden on other steps) so Back
  /// from the word step still shows the same dice.
  bool _dicePadMounted = false;

  @override
  void initState() {
    super.initState();
    ScreenSecurity.enable();
    _wordController.addListener(_onWordChanged);
  }

  @override
  void dispose() {
    ScreenSecurity.disable();
    _wordController.removeListener(_onWordChanged);
    _labelController.dispose();
    _wordController.dispose();
    _clearSecrets();
    super.dispose();
  }

  void _clearSecrets() {
    _mnemonic = null;
    _words = const [];
    _quiz = const [];
    _answers.clear();
    _rolls = const [];
    _wordController.clear();
  }

  void _onWordChanged() {
    setState(() {
      _wordStrength = EntropyMixer.wordStrength(_wordController.text);
      _error = null;
    });
  }

  void _onDiceChanged({
    required double motionScore,
    required List<int> faces,
    required List<DiceRollSample> rolls,
  }) {
    // Ignore bootstrap empty notifies that would wipe progress if a pad
    // remounted mid-frame (should not happen with keep-alive host).
    if (rolls.isEmpty &&
        motionScore == 0 &&
        _rolls.isNotEmpty &&
        _motionScore > 0) {
      return;
    }
    setState(() {
      _motionScore = motionScore;
      _rolls = rolls;
      if (_error != null) _error = null;
    });
  }

  void _goToDice() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Label is required');
      return;
    }
    setState(() {
      _error = null;
      _step = _CreateStep.dice;
      // Fresh pad only when first entering or after full ritual reset.
      if (!_dicePadMounted) {
        _dicePadMounted = true;
        _motionScore = 0;
        _rolls = const [];
      }
    });
  }

  void _restartDiceRitual() {
    setState(() {
      _mnemonic = null;
      _words = const [];
      _wroteDown = false;
      _motionScore = 0;
      _rolls = const [];
      _wordController.clear();
      _wordStrength = 0;
      _dicePadMounted = true;
      _step = _CreateStep.dice;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dicePadKey.currentState?.resetRitual();
    });
  }

  void _goToWord() {
    if (_motionScore < EntropyMixer.minMotionScore) {
      setState(() => _error = 'Keep rolling until the motion meter is full');
      return;
    }
    if (_rolls.isEmpty) {
      setState(() => _error = 'Swipe the dice at least once');
      return;
    }
    setState(() {
      _error = null;
      _step = _CreateStep.word;
    });
  }

  Future<void> _goToReveal() async {
    final word = _wordController.text;
    if (EntropyMixer.wordStrength(word) < EntropyMixer.minWordStrength) {
      setState(
        () => _error =
            'Use a longer, less guessable phrase (mix letters, numbers, symbols)',
      );
      return;
    }
    if (_rolls.isEmpty) {
      setState(() => _error = 'Dice ritual incomplete — go back and roll');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final ritual = RitualEntropyInput(
        rolls: List<DiceRollSample>.from(_rolls),
        personalWord: word,
        motionScore: _motionScore,
      );
      final phrase = _generator.generateMnemonic24FromRitual(ritual);
      final words = phrase.split(RegExp(r'\s+'));
      if (words.length != 24) {
        throw StateError('Expected 24 words, got ${words.length}');
      }

      // Drop ritual inputs from memory once mixed into the phrase.
      _rolls = const [];
      _wordController.clear();
      _wordStrength = 0;

      setState(() {
        _mnemonic = phrase;
        _words = words;
        _step = _CreateStep.reveal;
        _wroteDown = false;
        _phraseVisible = true;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  void _goToQuiz() {
    final phrase = _mnemonic;
    if (phrase == null) return;
    if (!_wroteDown) {
      setState(() => _error = 'Confirm that you wrote down the recovery phrase');
      return;
    }
    final quiz = _generator.buildQuiz(phrase: phrase, count: 3);
    setState(() {
      _error = null;
      _quiz = quiz;
      _answers.clear();
      _step = _CreateStep.quiz;
      _phraseVisible = false;
    });
  }

  Future<void> _finish() async {
    final phrase = _mnemonic;
    if (phrase == null) return;

    for (final item in _quiz) {
      if (_answers[item.wordIndex] != item.correctWord) {
        setState(() {
          _error =
              'Word ${item.displayPosition} is incorrect. Check your backup and try again.';
        });
        return;
      }
    }

    final network = ref.read(networkControllerProvider).network;
    final label = _labelController.text.trim();

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      final result = _generator.createFromMnemonic(
        phrase,
        label: label,
        network: network,
      );
      await ref.read(walletListControllerProvider.notifier).addImported(result);

      _clearSecrets();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _copyPhrase() async {
    final phrase = _mnemonic;
    if (phrase == null) return;
    await Clipboard.setData(ClipboardData(text: phrase));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Copied. Clipboard is not secure — clear it after writing the phrase down.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    Future<void>.delayed(const Duration(seconds: 60), () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == phrase) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (_step == _CreateStep.label) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard new wallet?'),
        content: const Text(
          'If you leave now, this recovery phrase will not be saved. '
          'Make sure you have not funded any address derived from it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  String get _title => switch (_step) {
        _CreateStep.label => 'Create wallet',
        _CreateStep.dice => 'Entropy ritual',
        _CreateStep.word => 'Entropy ritual',
        _CreateStep.reveal => 'Recovery phrase',
        _CreateStep.quiz => 'Confirm backup',
      };

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkControllerProvider).network;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StepHeader(step: _step),
            const SizedBox(height: 16),
            if (_step == _CreateStep.label) ...[
              Text(
                'Generate a new 24-word BIP39 recovery phrase. You will contribute '
                'randomness with dice and a personal word; the device CSPRNG is '
                'always mixed in so the wallet stays strong.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g. Main',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                enabled: !_busy,
                onSubmitted: (_) => _goToDice(),
              ),
              const SizedBox(height: 12),
              Text(
                'Network: ${network.label}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _goToDice,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Continue to entropy ritual'),
              ),
            ],
            if (_step == _CreateStep.dice) ...[
              Text(
                '1 · Roll the dice',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Swipe across the pad like tossing dice on a table. Movement '
                'speed and path feed the seed mixer. Roll until the meter is full.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
            ],
            // Keep the pad mounted (heightFactor 0 when hidden) so Back from
            // the word step still shows the same dice instead of an empty pad.
            if (_dicePadMounted)
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _step == _CreateStep.dice ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: _step != _CreateStep.dice,
                    child: DiceEntropyPad(
                      key: _dicePadKey,
                      onChanged: _onDiceChanged,
                    ),
                  ),
                ),
              ),
            if (_step == _CreateStep.dice) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _motionScore >= EntropyMixer.minMotionScore &&
                        _rolls.isNotEmpty
                    ? _goToWord
                    : null,
                child: const Text('Next: personal word'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _step = _CreateStep.label;
                  _error = null;
                }),
                child: const Text('Back'),
              ),
            ],
            if (_step == _CreateStep.word) ...[
              Text(
                '2 · Personal word',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Type something only you would invent — nonsense, mixed languages, '
                'numbers. Avoid a single dictionary word or your name. We hash '
                'the UTF-8 bytes and mix them with OS entropy and the dice.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: 'Your contribution',
                  hintText: 'e.g. purple-toaster-7!moth',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
                enableSuggestions: false,
                obscureText: false,
                enabled: !_busy,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Strength', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _wordStrength / 100,
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_wordStrength.round()}%',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
              if (_wordController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'UTF-8 → hex (preview)',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _hexPreview(_wordController.text),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ||
                        _wordStrength < EntropyMixer.minWordStrength
                    ? null
                    : _goToReveal,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _busy ? 'Mixing entropy…' : 'Mix & generate recovery phrase',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _step = _CreateStep.dice;
                          _error = null;
                        }),
                child: const Text('Back'),
              ),
            ],
            if (_step == _CreateStep.reveal) ...[
              Card(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Write these 24 words on paper, in order. Never share them, '
                          'store them in cloud notes, or take a screenshot. '
                          'This is the only way to recover this wallet.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phraseVisible)
                _WordGrid(words: _words)
              else
                Text(
                  'Phrase hidden. Use your paper backup for the next step.',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _phraseVisible = !_phraseVisible),
                    icon: Icon(
                      _phraseVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    label: Text(_phraseVisible ? 'Hide' : 'Show'),
                  ),
                  TextButton.icon(
                    onPressed: _copyPhrase,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _wroteDown,
                onChanged: (v) => setState(() {
                  _wroteDown = v ?? false;
                  _error = null;
                }),
                title: const Text(
                  'I wrote down my recovery phrase and stored it offline',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _goToQuiz,
                child: const Text('Continue to verification'),
              ),
              TextButton(
                onPressed: _restartDiceRitual,
                child: const Text('Back (new ritual)'),
              ),
            ],
            if (_step == _CreateStep.quiz) ...[
              Text(
                'Select the correct word for each position to confirm your backup.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final item in _quiz) ...[
                Text(
                  'Word ${item.displayPosition}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in item.choices)
                      ChoiceChip(
                        label: Text(choice),
                        selected: _answers[item.wordIndex] == choice,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                  _answers[item.wordIndex] = choice;
                                  _error = null;
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _busy || _answers.length < _quiz.length
                    ? null
                    : _finish,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_busy ? 'Saving…' : 'Create wallet'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _step = _CreateStep.reveal;
                          _phraseVisible = true;
                          _answers.clear();
                          _error = null;
                        }),
                child: const Text('Back to phrase'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Seed = SHA-256(OS CSPRNG ‖ dice ritual ‖ word hash). Secrets stay in '
              'encrypted device storage. Screenshots are blocked on Android while '
              'this screen is open.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _hexPreview(String s) {
    return utf8.encode(s).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final _CreateStep step;

  @override
  Widget build(BuildContext context) {
    final labels = ['Label', 'Dice', 'Word', 'Backup', 'Verify'];
    final index = step.index;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const Expanded(child: Divider()),
          Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: i <= index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: i <= index
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ],
    );
  }
}

class _WordGrid extends StatelessWidget {
  const _WordGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 360 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: words.length,
            gridDelegate: theSliverGrid(columns),
            itemBuilder: (context, i) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        words[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount theSliverGrid(int columns) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.2,
    );
  }
}
