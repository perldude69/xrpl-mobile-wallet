import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:xrpl_mobile_wallet/ui/theme/pirate_icon.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/detail/wallet_action_tile.dart';

WidgetbookUseCase walletDetailUseCase() {
  return WidgetbookUseCase(
    name: 'Wallet detail (layout)',
    builder: (context) {
      final watchOnly = context.knobs.boolean(
        label: 'Watch-only',
        initialValue: false,
      );
      final testnet = context.knobs.boolean(
        label: 'Testnet tools',
        initialValue: true,
      );
      final xrp = context.knobs.string(
        label: 'XRP balance',
        initialValue: '141.989237',
      );
      final rlusd = context.knobs.string(
        label: 'RLUSD',
        initialValue: '1333.67',
      );
      final aspect = context.knobs.double.slider(
        label: 'Action tile aspect',
        initialValue: 2.2,
        min: 1.4,
        max: 2.8,
      );

      return Scaffold(
        appBar: AppBar(
          title: const Text('T1'),
          actions: const [
            Icon(Icons.copy),
            SizedBox(width: 8),
            PirateIcon(glyph: PirateGlyph.helm),
            SizedBox(width: 8),
            Icon(Icons.more_vert),
            SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(xrp, style: Theme.of(context).textTheme.headlineSmall),
                    const Text('XRP'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: PirateIcon(
                            glyph: watchOnly
                                ? PirateGlyph.spyglass
                                : PirateGlyph.key,
                            size: 16,
                          ),
                          label: Text(watchOnly ? 'Watch-only' : 'Signing'),
                        ),
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Testnet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'rGCiRsS3Hhb33ic98LBfu1TS5fkKzeU5Dy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspect,
              children: [
                WalletActionTile(
                  glyph: PirateGlyph.bottle,
                  label: 'Send',
                  enabled: !watchOnly,
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
                  enabled: !watchOnly,
                  onPressed: () {},
                ),
              ],
            ),
            if (testnet) ...[
              const SizedBox(height: 12),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: PirateIcon(glyph: PirateGlyph.barrel),
                      title: Text('Fund XRP'),
                    ),
                    ListTile(
                      leading: PirateIcon(glyph: PirateGlyph.doubloon),
                      title: Text('Official RLUSD faucet'),
                      trailing: Icon(Icons.open_in_new, size: 18),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Balances', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const PirateIcon(glyph: PirateGlyph.chest),
                    title: const Text('XRP'),
                    trailing: Text(
                      xrp,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const PirateIcon(glyph: PirateGlyph.doubloon),
                    title: const Text('RLUSD'),
                    subtitle: const Text(
                      'rQhWct2f…iLKV',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      rlusd,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
