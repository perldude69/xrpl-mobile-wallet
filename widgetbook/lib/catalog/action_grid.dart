import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/detail/wallet_action_tile.dart';

WidgetbookUseCase actionGridUseCase() {
  return WidgetbookUseCase(
    name: 'Action tiles',
    builder: (context) {
      final columns = context.knobs.int.slider(
        label: 'Columns',
        initialValue: 2,
        min: 2,
        max: 4,
      );
      final aspect = context.knobs.double.slider(
        label: 'Aspect ratio',
        initialValue: 2.2,
        min: 1.2,
        max: 3.0,
      );
      return Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspect,
          children: [
            WalletActionTile(
              glyph: PirateGlyph.bottle,
              label: 'Send',
              onPressed: () {},
            ),
            WalletActionTile(
              glyph: PirateGlyph.chest,
              label: 'Receive',
              onPressed: () {},
            ),
            WalletActionTile(
              glyph: PirateGlyph.crossedSwords,
              label: 'Trade',
              onPressed: () {},
            ),
            WalletActionTile(
              glyph: PirateGlyph.shovel,
              label: 'Escrow',
              onPressed: () {},
            ),
          ],
        ),
      );
    },
  );
}
