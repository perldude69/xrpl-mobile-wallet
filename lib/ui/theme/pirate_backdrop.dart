import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/config/theme.dart';

/// Full-screen comic cove behind every route. A navy scrim keeps list text
/// readable; the scene is atmosphere, not a wallpaper that fights numbers.
class PirateBackdrop extends StatelessWidget {
  const PirateBackdrop({super.key, required this.child});

  final Widget child;

  static const assetPath = 'assets/theme/beach_cove.jpg';

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: PiratePalette.nightSea),
        Image.asset(
          assetPath,
          package: 'xrpl_mobile_wallet',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.2),
          errorBuilder: (context, error, stackTrace) =>
              const ColoredBox(color: PiratePalette.nightSea),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xA60B1C24), Color(0xC20B1C24), Color(0xE00B1C24)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
