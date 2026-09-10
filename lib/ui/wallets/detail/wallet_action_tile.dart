import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';

/// Equal-geometry action used on wallet detail (Send / Receive / Trade / Escrow).
class WalletActionTile extends StatelessWidget {
  const WalletActionTile({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.tooltip,
  });

  final PirateGlyph glyph;
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.tonal(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PirateIcon(glyph: glyph, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
