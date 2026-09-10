import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Comic pirate glyphs for chrome (nav, settings, primary actions).
///
/// Keep Material icons for affordances that must stay literal: chevrons,
/// show/hide secret, copy, traffic-light dots, and money-result check/error.
///
/// Glossary:
/// | Place | Glyph |
/// | Wallets tab | [PirateGlyph.ship] |
/// | Activity tab / log | [PirateGlyph.scroll] |
/// | Settings tab | [PirateGlyph.chest] |
/// | Network | [PirateGlyph.spyglass] |
/// | Wallet settings / captain | [PirateGlyph.captain] |
/// | Security | [PirateGlyph.sword] |
/// | Monitoring | [PirateGlyph.cannon] |
/// | Escrow | [PirateGlyph.shovel] |
/// | About | [PirateGlyph.parrot] |
/// | Exit | [PirateGlyph.plank] |
/// | Wipe | [PirateGlyph.skull] |
/// | Coffee | [PirateGlyph.grog] |
/// | Send | [PirateGlyph.bottle] |
/// | Receive | [PirateGlyph.chest] (open loot) |
/// | Trade | [PirateGlyph.crossedSwords] |
/// | Ledger | [PirateGlyph.compass] |
/// | Keys / seed | [PirateGlyph.key] |
/// | Watch-only | [PirateGlyph.spyglass] |
/// | PIN | [PirateGlyph.eyepatch] |
/// | Game PIN | [PirateGlyph.helm] |
/// | Create wallet | [PirateGlyph.dice] |
/// | Import / map | [PirateGlyph.map] |
/// | Refresh | [PirateGlyph.helm] |
/// | Faucet | [PirateGlyph.barrel] |
/// | RLUSD / coins | [PirateGlyph.doubloon] |
/// | Paste phrase | [PirateGlyph.quill] |
enum PirateGlyph {
  ship,
  scroll,
  chest,
  spyglass,
  captain,
  sword,
  cannon,
  shovel,
  parrot,
  plank,
  skull,
  grog,
  bottle,
  crossedSwords,
  compass,
  helm,
  dice,
  key,
  map,
  eyepatch,
  barrel,
  doubloon,
  quill,
}

class PirateIcon extends StatelessWidget {
  const PirateIcon({super.key, required this.glyph, this.size, this.color});

  final PirateGlyph glyph;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final resolvedSize = size ?? theme.size ?? 24;
    final resolvedColor =
        color ?? theme.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: glyph.name,
      child: SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: CustomPaint(
          painter: _PirateGlyphPainter(glyph: glyph, color: resolvedColor),
        ),
      ),
    );
  }
}

class _PirateGlyphPainter extends CustomPainter {
  _PirateGlyphPainter({required this.glyph, required this.color});

  final PirateGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF1A1208)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.09).clamp(1.4, 2.6)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(size.width * 0.08, size.height * 0.08);
    final s = Size(size.width * 0.84, size.height * 0.84);

    switch (glyph) {
      case PirateGlyph.ship:
        _ship(canvas, s, fill, stroke);
      case PirateGlyph.scroll:
        _scroll(canvas, s, fill, stroke);
      case PirateGlyph.chest:
        _chest(canvas, s, fill, stroke);
      case PirateGlyph.spyglass:
        _spyglass(canvas, s, fill, stroke);
      case PirateGlyph.captain:
        _captain(canvas, s, fill, stroke);
      case PirateGlyph.sword:
        _sword(canvas, s, fill, stroke);
      case PirateGlyph.cannon:
        _cannon(canvas, s, fill, stroke);
      case PirateGlyph.shovel:
        _shovel(canvas, s, fill, stroke);
      case PirateGlyph.parrot:
        _parrot(canvas, s, fill, stroke);
      case PirateGlyph.plank:
        _plank(canvas, s, fill, stroke);
      case PirateGlyph.skull:
        _skull(canvas, s, fill, stroke);
      case PirateGlyph.grog:
        _grog(canvas, s, fill, stroke);
      case PirateGlyph.bottle:
        _bottle(canvas, s, fill, stroke);
      case PirateGlyph.crossedSwords:
        _crossedSwords(canvas, s, fill, stroke);
      case PirateGlyph.compass:
        _compass(canvas, s, fill, stroke);
      case PirateGlyph.helm:
        _helm(canvas, s, fill, stroke);
      case PirateGlyph.dice:
        _dice(canvas, s, fill, stroke);
      case PirateGlyph.key:
        _key(canvas, s, fill, stroke);
      case PirateGlyph.map:
        _map(canvas, s, fill, stroke);
      case PirateGlyph.eyepatch:
        _eyepatch(canvas, s, fill, stroke);
      case PirateGlyph.barrel:
        _barrel(canvas, s, fill, stroke);
      case PirateGlyph.doubloon:
        _doubloon(canvas, s, fill, stroke);
      case PirateGlyph.quill:
        _quill(canvas, s, fill, stroke);
    }
    canvas.restore();
  }

  void _ship(Canvas c, Size s, Paint fill, Paint stroke) {
    final hull = Path()
      ..moveTo(s.width * 0.08, s.height * 0.62)
      ..lineTo(s.width * 0.92, s.height * 0.62)
      ..lineTo(s.width * 0.78, s.height * 0.88)
      ..lineTo(s.width * 0.22, s.height * 0.88)
      ..close();
    c.drawPath(hull, fill);
    c.drawPath(hull, stroke);
    c.drawLine(
      Offset(s.width * 0.50, s.height * 0.12),
      Offset(s.width * 0.50, s.height * 0.62),
      stroke,
    );
    final sail = Path()
      ..moveTo(s.width * 0.52, s.height * 0.14)
      ..lineTo(s.width * 0.84, s.height * 0.38)
      ..lineTo(s.width * 0.52, s.height * 0.54)
      ..close();
    c.drawPath(sail, fill);
    c.drawPath(sail, stroke);
  }

  void _scroll(Canvas c, Size s, Paint fill, Paint stroke) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s.width * 0.18,
        s.height * 0.12,
        s.width * 0.64,
        s.height * 0.76,
      ),
      Radius.circular(s.width * 0.08),
    );
    c.drawRRect(body, fill);
    c.drawRRect(body, stroke);
    c.drawLine(
      Offset(s.width * 0.32, s.height * 0.34),
      Offset(s.width * 0.68, s.height * 0.34),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.32, s.height * 0.50),
      Offset(s.width * 0.68, s.height * 0.50),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.32, s.height * 0.66),
      Offset(s.width * 0.58, s.height * 0.66),
      stroke,
    );
  }

  void _chest(Canvas c, Size s, Paint fill, Paint stroke) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s.width * 0.12,
        s.height * 0.42,
        s.width * 0.76,
        s.height * 0.46,
      ),
      Radius.circular(s.width * 0.08),
    );
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s.width * 0.10,
        s.height * 0.18,
        s.width * 0.80,
        s.height * 0.28,
      ),
      Radius.circular(s.width * 0.12),
    );
    c.drawRRect(body, fill);
    c.drawRRect(body, stroke);
    c.drawRRect(lid, fill);
    c.drawRRect(lid, stroke);
    c.drawLine(
      Offset(s.width * 0.12, s.height * 0.44),
      Offset(s.width * 0.88, s.height * 0.44),
      stroke,
    );
  }

  void _spyglass(Canvas c, Size s, Paint fill, Paint stroke) {
    final a = Offset(s.width * 0.18, s.height * 0.78);
    final b = Offset(s.width * 0.78, s.height * 0.22);
    final fat = Paint()
      ..color = fill.color
      ..strokeWidth = s.width * 0.22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(a, b, fat);
    c.drawLine(a, b, stroke);
    c.drawCircle(b, s.width * 0.14, fill);
    c.drawCircle(b, s.width * 0.14, stroke);
  }

  void _captain(Canvas c, Size s, Paint fill, Paint stroke) {
    final head = Offset(s.width * 0.50, s.height * 0.58);
    c.drawCircle(head, s.width * 0.28, fill);
    c.drawCircle(head, s.width * 0.28, stroke);
    final hat = Path()
      ..moveTo(s.width * 0.12, s.height * 0.42)
      ..lineTo(s.width * 0.50, s.height * 0.08)
      ..lineTo(s.width * 0.88, s.height * 0.42)
      ..lineTo(s.width * 0.70, s.height * 0.38)
      ..lineTo(s.width * 0.30, s.height * 0.38)
      ..close();
    c.drawPath(hat, fill);
    c.drawPath(hat, stroke);
    c.drawLine(
      Offset(s.width * 0.22, s.height * 0.56),
      Offset(s.width * 0.42, s.height * 0.56),
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.62, s.height * 0.56),
      s.width * 0.05,
      stroke,
    );
  }

  void _sword(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawLine(
      Offset(s.width * 0.28, s.height * 0.78),
      Offset(s.width * 0.78, s.height * 0.18),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.18, s.height * 0.62),
      Offset(s.width * 0.42, s.height * 0.82),
      stroke,
    );
    final blade = Path()
      ..moveTo(s.width * 0.40, s.height * 0.62)
      ..lineTo(s.width * 0.78, s.height * 0.18)
      ..lineTo(s.width * 0.52, s.height * 0.52)
      ..close();
    c.drawPath(blade, fill);
    c.drawPath(blade, stroke);
  }

  void _cannon(Canvas c, Size s, Paint fill, Paint stroke) {
    final barrel = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s.width * 0.18,
        s.height * 0.28,
        s.width * 0.70,
        s.height * 0.28,
      ),
      Radius.circular(s.width * 0.08),
    );
    c.drawRRect(barrel, fill);
    c.drawRRect(barrel, stroke);
    c.drawCircle(Offset(s.width * 0.32, s.height * 0.72), s.width * 0.14, fill);
    c.drawCircle(
      Offset(s.width * 0.32, s.height * 0.72),
      s.width * 0.14,
      stroke,
    );
    c.drawCircle(Offset(s.width * 0.58, s.height * 0.72), s.width * 0.14, fill);
    c.drawCircle(
      Offset(s.width * 0.58, s.height * 0.72),
      s.width * 0.14,
      stroke,
    );
  }

  void _shovel(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawLine(
      Offset(s.width * 0.32, s.height * 0.12),
      Offset(s.width * 0.62, s.height * 0.58),
      stroke,
    );
    final blade = Path()
      ..moveTo(s.width * 0.48, s.height * 0.50)
      ..lineTo(s.width * 0.88, s.height * 0.58)
      ..lineTo(s.width * 0.70, s.height * 0.92)
      ..lineTo(s.width * 0.38, s.height * 0.72)
      ..close();
    c.drawPath(blade, fill);
    c.drawPath(blade, stroke);
  }

  void _parrot(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width * 0.46, s.height * 0.52),
        width: s.width * 0.48,
        height: s.height * 0.62,
      ),
      fill,
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width * 0.46, s.height * 0.52),
        width: s.width * 0.48,
        height: s.height * 0.62,
      ),
      stroke,
    );
    c.drawCircle(Offset(s.width * 0.62, s.height * 0.28), s.width * 0.16, fill);
    c.drawCircle(
      Offset(s.width * 0.62, s.height * 0.28),
      s.width * 0.16,
      stroke,
    );
    final beak = Path()
      ..moveTo(s.width * 0.74, s.height * 0.26)
      ..lineTo(s.width * 0.94, s.height * 0.34)
      ..lineTo(s.width * 0.74, s.height * 0.40)
      ..close();
    c.drawPath(beak, fill);
    c.drawPath(beak, stroke);
    c.drawCircle(
      Offset(s.width * 0.66, s.height * 0.26),
      s.width * 0.04,
      stroke,
    );
  }

  void _plank(Canvas c, Size s, Paint fill, Paint stroke) {
    final board = Path()
      ..moveTo(s.width * 0.08, s.height * 0.42)
      ..lineTo(s.width * 0.92, s.height * 0.28)
      ..lineTo(s.width * 0.92, s.height * 0.48)
      ..lineTo(s.width * 0.08, s.height * 0.62)
      ..close();
    c.drawPath(board, fill);
    c.drawPath(board, stroke);
    c.drawLine(
      Offset(s.width * 0.18, s.height * 0.72),
      Offset(s.width * 0.18, s.height * 0.52),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.08, s.height * 0.78),
      Offset(s.width * 0.42, s.height * 0.70),
      stroke,
    );
  }

  void _skull(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawCircle(Offset(s.width * 0.50, s.height * 0.42), s.width * 0.32, fill);
    c.drawCircle(
      Offset(s.width * 0.50, s.height * 0.42),
      s.width * 0.32,
      stroke,
    );
    final jaw = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s.width * 0.50, s.height * 0.72),
        width: s.width * 0.36,
        height: s.height * 0.22,
      ),
      Radius.circular(s.width * 0.06),
    );
    c.drawRRect(jaw, fill);
    c.drawRRect(jaw, stroke);
    c.drawCircle(
      Offset(s.width * 0.38, s.height * 0.40),
      s.width * 0.07,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.62, s.height * 0.40),
      s.width * 0.07,
      stroke,
    );
  }

  void _grog(Canvas c, Size s, Paint fill, Paint stroke) {
    final mug = Path()
      ..moveTo(s.width * 0.22, s.height * 0.28)
      ..lineTo(s.width * 0.70, s.height * 0.28)
      ..lineTo(s.width * 0.64, s.height * 0.88)
      ..lineTo(s.width * 0.28, s.height * 0.88)
      ..close();
    c.drawPath(mug, fill);
    c.drawPath(mug, stroke);
    c.drawArc(
      Rect.fromLTWH(
        s.width * 0.62,
        s.height * 0.40,
        s.width * 0.28,
        s.height * 0.32,
      ),
      -1.2,
      2.4,
      false,
      stroke,
    );
  }

  void _bottle(Canvas c, Size s, Paint fill, Paint stroke) {
    final body = Path()
      ..moveTo(s.width * 0.38, s.height * 0.22)
      ..lineTo(s.width * 0.62, s.height * 0.22)
      ..lineTo(s.width * 0.62, s.height * 0.38)
      ..lineTo(s.width * 0.78, s.height * 0.52)
      ..lineTo(s.width * 0.78, s.height * 0.88)
      ..lineTo(s.width * 0.22, s.height * 0.88)
      ..lineTo(s.width * 0.22, s.height * 0.52)
      ..lineTo(s.width * 0.38, s.height * 0.38)
      ..close();
    c.drawPath(body, fill);
    c.drawPath(body, stroke);
    c.drawLine(
      Offset(s.width * 0.42, s.height * 0.12),
      Offset(s.width * 0.58, s.height * 0.12),
      stroke,
    );
  }

  void _crossedSwords(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawLine(
      Offset(s.width * 0.18, s.height * 0.82),
      Offset(s.width * 0.82, s.height * 0.18),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.18, s.height * 0.18),
      Offset(s.width * 0.82, s.height * 0.82),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.12, s.height * 0.68),
      Offset(s.width * 0.32, s.height * 0.88),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.12, s.height * 0.32),
      Offset(s.width * 0.32, s.height * 0.12),
      stroke,
    );
  }

  void _compass(Canvas c, Size s, Paint fill, Paint stroke) {
    final o = Offset(s.width * 0.5, s.height * 0.5);
    c.drawCircle(o, s.width * 0.38, fill);
    c.drawCircle(o, s.width * 0.38, stroke);
    final needle = Path()
      ..moveTo(o.dx, o.dy - s.height * 0.28)
      ..lineTo(o.dx + s.width * 0.08, o.dy)
      ..lineTo(o.dx, o.dy + s.height * 0.28)
      ..lineTo(o.dx - s.width * 0.08, o.dy)
      ..close();
    c.drawPath(needle, stroke);
  }

  void _helm(Canvas c, Size s, Paint fill, Paint stroke) {
    final o = Offset(s.width * 0.5, s.height * 0.5);
    c.drawCircle(o, s.width * 0.22, fill);
    c.drawCircle(o, s.width * 0.22, stroke);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      c.drawLine(
        Offset(
          o.dx + s.width * 0.16 * math.cos(a),
          o.dy + s.height * 0.16 * math.sin(a),
        ),
        Offset(
          o.dx + s.width * 0.42 * math.cos(a),
          o.dy + s.height * 0.42 * math.sin(a),
        ),
        stroke,
      );
    }
  }

  void _dice(Canvas c, Size s, Paint fill, Paint stroke) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s.width * 0.16,
        s.height * 0.16,
        s.width * 0.68,
        s.height * 0.68,
      ),
      Radius.circular(s.width * 0.10),
    );
    c.drawRRect(r, fill);
    c.drawRRect(r, stroke);
    c.drawCircle(
      Offset(s.width * 0.34, s.height * 0.34),
      s.width * 0.05,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.66, s.height * 0.34),
      s.width * 0.05,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.50, s.height * 0.50),
      s.width * 0.05,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.34, s.height * 0.66),
      s.width * 0.05,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.66, s.height * 0.66),
      s.width * 0.05,
      stroke,
    );
  }

  void _key(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawCircle(Offset(s.width * 0.32, s.height * 0.34), s.width * 0.22, fill);
    c.drawCircle(
      Offset(s.width * 0.32, s.height * 0.34),
      s.width * 0.22,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.32, s.height * 0.34),
      s.width * 0.08,
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.48, s.height * 0.46),
      Offset(s.width * 0.84, s.height * 0.80),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.68, s.height * 0.84),
      Offset(s.width * 0.82, s.height * 0.70),
      stroke,
    );
  }

  void _map(Canvas c, Size s, Paint fill, Paint stroke) {
    final p = Path()
      ..moveTo(s.width * 0.14, s.height * 0.22)
      ..lineTo(s.width * 0.38, s.height * 0.30)
      ..lineTo(s.width * 0.62, s.height * 0.18)
      ..lineTo(s.width * 0.86, s.height * 0.28)
      ..lineTo(s.width * 0.86, s.height * 0.80)
      ..lineTo(s.width * 0.62, s.height * 0.70)
      ..lineTo(s.width * 0.38, s.height * 0.84)
      ..lineTo(s.width * 0.14, s.height * 0.72)
      ..close();
    c.drawPath(p, fill);
    c.drawPath(p, stroke);
  }

  void _eyepatch(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawLine(
      Offset(s.width * 0.08, s.height * 0.28),
      Offset(s.width * 0.92, s.height * 0.22),
      stroke,
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width * 0.38, s.height * 0.52),
        width: s.width * 0.46,
        height: s.height * 0.40,
      ),
      fill,
    );
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width * 0.38, s.height * 0.52),
        width: s.width * 0.46,
        height: s.height * 0.40,
      ),
      stroke,
    );
  }

  void _barrel(Canvas c, Size s, Paint fill, Paint stroke) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        s.width * 0.22,
        s.height * 0.12,
        s.width * 0.56,
        s.height * 0.76,
      ),
      Radius.circular(s.width * 0.18),
    );
    c.drawRRect(body, fill);
    c.drawRRect(body, stroke);
    c.drawLine(
      Offset(s.width * 0.22, s.height * 0.32),
      Offset(s.width * 0.78, s.height * 0.32),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.22, s.height * 0.68),
      Offset(s.width * 0.78, s.height * 0.68),
      stroke,
    );
  }

  void _doubloon(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawCircle(Offset(s.width * 0.50, s.height * 0.50), s.width * 0.36, fill);
    c.drawCircle(
      Offset(s.width * 0.50, s.height * 0.50),
      s.width * 0.36,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.50, s.height * 0.50),
      s.width * 0.20,
      stroke,
    );
  }

  void _quill(Canvas c, Size s, Paint fill, Paint stroke) {
    final feather = Path()
      ..moveTo(s.width * 0.22, s.height * 0.18)
      ..lineTo(s.width * 0.58, s.height * 0.12)
      ..lineTo(s.width * 0.48, s.height * 0.48)
      ..close();
    c.drawPath(feather, fill);
    c.drawPath(feather, stroke);
    c.drawLine(
      Offset(s.width * 0.48, s.height * 0.42),
      Offset(s.width * 0.82, s.height * 0.86),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PirateGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
