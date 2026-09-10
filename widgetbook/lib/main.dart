import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:xrpl_mobile_wallet/config/theme.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_backdrop.dart';

import 'catalog/action_grid.dart';
import 'catalog/swipe_sign.dart';
import 'catalog/trade_tape.dart';
import 'catalog/wallet_detail.dart';

void main() {
  runApp(const WalletWidgetbook());
}

class WalletWidgetbook extends StatelessWidget {
  const WalletWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Wallets',
          children: [walletDetailUseCase(), actionGridUseCase()],
        ),
        WidgetbookFolder(name: 'Trade', children: [tradeTapeUseCase()]),
        WidgetbookFolder(name: 'Lock', children: [swipeSignUseCase()]),
      ],
      addons: [
        ViewportAddon([
          Viewports.none,
          AndroidViewports.samsungGalaxyS20,
          IosViewports.iPad,
        ]),
        InspectorAddon(),
        AlignmentAddon(),
        MaterialThemeAddon(
          themes: [WidgetbookTheme(name: 'Pirate dark', data: buildAppTheme())],
        ),
      ],
      appBuilder: (context, child) {
        return PirateBackdrop(
          child: ColoredBox(color: Colors.transparent, child: child),
        );
      },
    );
  }
}
