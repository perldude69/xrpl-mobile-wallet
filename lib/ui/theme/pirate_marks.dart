import 'package:flutter/material.dart';

class JollyRogerMark extends StatelessWidget {
  const JollyRogerMark({super.key, this.size = 36});

  final double size;

  static const assetPath = 'assets/theme/jolly_roger.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      package: 'xrpl_mobile_wallet',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.flag,
        size: size * 0.85,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class PirateMascot extends StatelessWidget {
  const PirateMascot({super.key, this.size = 128});

  final double size;

  static const assetPath = 'assets/theme/pirate_mascot.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      package: 'xrpl_mobile_wallet',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.face,
        size: size * 0.7,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
