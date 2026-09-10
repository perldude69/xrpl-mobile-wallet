import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/domain/trade/amm_pool.dart';
import 'package:xrpl_mobile_wallet/domain/trade/order_book.dart';
import 'package:xrpl_mobile_wallet/domain/trade/tape_format.dart';
import 'package:xrpl_mobile_wallet/domain/trade/trade_decimal.dart';

/// Colorized bid–spread–ask tape. Geometry is display-only.
class BookTape extends StatelessWidget {
  const BookTape({super.key, required this.snapshot, this.amm});

  final BookSnapshot snapshot;
  final AmmPoolSnapshot? amm;

  @override
  Widget build(BuildContext context) {
    final bid = snapshot.bestBid;
    final ask = snapshot.bestAsk;
    final scheme = Theme.of(context).colorScheme;
    final bidColor = Colors.greenAccent.shade400;
    final askColor = Colors.orangeAccent.shade400;
    final spreadColor = scheme.tertiary;
    final outline = scheme.outline;

    if (bid == null || ask == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Track(
            bidColor: scheme.surfaceContainerHighest,
            spreadColor: scheme.surfaceContainerHighest,
            askColor: scheme.surfaceContainerHighest,
            tickColor: outline,
            showTick: false,
          ),
          const SizedBox(height: 8),
          Text(
            'Bid/ask unavailable',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: outline),
          ),
        ],
      );
    }

    final spread = ask - bid;
    final bidLabel = formatTapeDecimal(bid);
    final askLabel = formatTapeDecimal(ask);
    final spreadLabel = formatTapeDecimal(spread);
    final midLabel = snapshot.mid == null
        ? null
        : formatTapeDecimal(snapshot.mid!);
    final bidShare = tapeBidVolumeShareThousandths(snapshot);
    final askShare = 1000 - bidShare;

    return Semantics(
      label:
          'Bid $bidLabel, ask $askLabel, spread $spreadLabel, '
          'ledger ${snapshot.ledgerIndex}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(bidLabel, style: _rateStyle(context, bidColor)),
              ),
              Text(
                spreadLabel,
                textAlign: TextAlign.center,
                style: _rateStyle(context, spreadColor),
              ),
              Expanded(
                child: Text(
                  askLabel,
                  textAlign: TextAlign.right,
                  style: _rateStyle(context, askColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Track(
            bidColor: bidColor,
            spreadColor: spreadColor,
            askColor: askColor,
            tickColor: scheme.onSurface,
            showTick: true,
            ammFraction: _ammFraction(bid, ask),
            ammColor: scheme.secondary,
          ),
          if (midLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              midLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Ledger ${snapshot.ledgerIndex} · ${snapshot.bids.length} bids / '
            '${snapshot.asks.length} asks',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: outline),
          ),
          if (amm != null) ...[
            const SizedBox(height: 4),
            Text(
              'AMM ${formatTapeDecimal(amm!.spot)} · fee ${amm!.feePercentLabel}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.secondary),
            ),
          ],
          if (snapshot.bids.isNotEmpty || snapshot.asks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: SizedBox(
                height: 2,
                child: Row(
                  children: [
                    if (bidShare > 0)
                      Expanded(
                        flex: bidShare,
                        child: ColoredBox(color: bidColor),
                      ),
                    if (askShare > 0)
                      Expanded(
                        flex: askShare,
                        child: ColoredBox(color: askColor),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _ammFraction(TradeDecimal bid, TradeDecimal ask) {
    final pool = amm;
    if (pool == null) return null;
    if (!pool.spotInsideSpread(bestBid: bid, bestAsk: ask)) return null;
    final span = ask - bid;
    if (span.isZero) return null;
    final offset = pool.spot - bid;
    final ratio = offset.divide(span, scale: 6, roundUp: false);
    return double.parse(ratio.toString());
  }

  TextStyle? _rateStyle(BuildContext context, Color color) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({
    required this.bidColor,
    required this.spreadColor,
    required this.askColor,
    required this.tickColor,
    required this.showTick,
    this.ammFraction,
    this.ammColor,
  });

  final Color bidColor;
  final Color spreadColor;
  final Color askColor;
  final Color tickColor;
  final bool showTick;
  final double? ammFraction;
  final Color? ammColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frac = ammFraction;
          return Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: ColoredBox(color: bidColor)),
                    Expanded(flex: 1, child: ColoredBox(color: spreadColor)),
                    Expanded(flex: 2, child: ColoredBox(color: askColor)),
                  ],
                ),
              ),
              if (showTick)
                Center(
                  child: Container(width: 2, height: 12, color: tickColor),
                ),
              if (frac != null && ammColor != null)
                Positioned(
                  left: (constraints.maxWidth * frac.clamp(0.0, 1.0)) - 1,
                  top: -1,
                  bottom: -1,
                  child: Container(width: 2, color: ammColor),
                ),
            ],
          );
        },
      ),
    );
  }
}
