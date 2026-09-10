import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Session-unlocked confirm: slide to sign. The wallet PIN already unlocked
/// [KeyVault]; this is explicit intent, not a second cryptographic factor.
///
/// Destructive actions (wipe, delete wallet) must still use the PIN prompt.
Future<bool> promptSwipeToSign(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Slide to sign',
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
      ),
      child: SwipeToSignPanel(
        title: title,
        message: message,
        actionLabel: actionLabel,
      ),
    ),
  );
  return ok == true;
}

/// Visible slide control; used by [promptSwipeToSign] and Widgetbook.
class SwipeToSignPanel extends StatefulWidget {
  const SwipeToSignPanel({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.onComplete,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onComplete;

  @override
  State<SwipeToSignPanel> createState() => _SwipeToSignPanelState();
}

class _SwipeToSignPanelState extends State<SwipeToSignPanel> {
  double _progress = 0;
  static const _done = 0.92;

  void _setProgress(double value) {
    setState(() => _progress = value.clamp(0.0, 1.0));
  }

  void _endDrag() {
    if (_progress >= _done) {
      HapticFeedback.mediumImpact();
      final extra = widget.onComplete;
      if (extra != null) {
        extra();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() => _progress = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(widget.message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            const thumb = 56.0;
            final max = (constraints.maxWidth - thumb).clamp(1.0, 10000.0);
            return GestureDetector(
              onHorizontalDragUpdate: (d) {
                _setProgress(_progress + d.delta.dx / max);
              },
              onHorizontalDragEnd: (_) => _endDrag(),
              onHorizontalDragCancel: _endDrag,
              child: Container(
                height: thumb,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(thumb / 2),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(
                      child: Text(
                        widget.actionLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Positioned(
                      left: _progress * max,
                      child: Material(
                        color: scheme.primary,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: SizedBox(
                          width: thumb,
                          height: thumb,
                          child: Icon(
                            Icons.chevron_right,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
