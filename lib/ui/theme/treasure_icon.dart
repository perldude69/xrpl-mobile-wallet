import 'package:flutter/material.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/treasure_kind.dart';
import 'package:xrpl_mobile_wallet/domain/wallet/wallet_account.dart';

/// Circular comic treasure used as a wallet avatar.
class TreasureAvatar extends StatelessWidget {
  const TreasureAvatar({super.key, required this.account, this.radius = 20});

  final WalletAccount account;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final kind = TreasureKind.fromAddress(account.address);
    return Semantics(
      label: kind.semanticLabel,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: account.displayColor,
        child: Padding(
          padding: EdgeInsets.all(radius * 0.18),
          child: TreasureIcon(kind: kind, color: _onFill(account.displayColor)),
        ),
      ),
    );
  }

  static Color _onFill(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? const Color(0xFFFFF6E0)
        : const Color(0xFF1A1208);
  }
}

class TreasureIcon extends StatelessWidget {
  const TreasureIcon({super.key, required this.kind, required this.color});

  final TreasureKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TreasurePainter(kind: kind, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _TreasurePainter extends CustomPainter {
  _TreasurePainter({required this.kind, required this.color});

  final TreasureKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF1A1208)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w * 0.08, h * 0.08);
    final s = Size(w * 0.84, h * 0.84);

    switch (kind) {
      case TreasureKind.chest:
        _chest(canvas, s, fill, stroke);
      case TreasureKind.coins:
        _coins(canvas, s, fill, stroke);
      case TreasureKind.goblet:
        _goblet(canvas, s, fill, stroke);
      case TreasureKind.pearl:
        _pearl(canvas, s, fill, stroke);
      case TreasureKind.crown:
        _crown(canvas, s, fill, stroke);
      case TreasureKind.compass:
        _compass(canvas, s, fill, stroke);
      case TreasureKind.map:
        _map(canvas, s, fill, stroke);
      case TreasureKind.gem:
        _gem(canvas, s, fill, stroke);
      case TreasureKind.spyglass:
        _spyglass(canvas, s, fill, stroke);
      case TreasureKind.key:
        _key(canvas, s, fill, stroke);
      case TreasureKind.ring:
        _ring(canvas, s, fill, stroke);
      case TreasureKind.anchor:
        _anchor(canvas, s, fill, stroke);
    }
    canvas.restore();
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
    final lock = Rect.fromCenter(
      center: Offset(s.width * 0.5, s.height * 0.62),
      width: s.width * 0.16,
      height: s.height * 0.18,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(lock, Radius.circular(s.width * 0.04)),
      stroke,
    );
  }

  void _coins(Canvas c, Size s, Paint fill, Paint stroke) {
    void coin(Offset o, double r) {
      c.drawCircle(o, r, fill);
      c.drawCircle(o, r, stroke);
    }

    final r = s.width * 0.22;
    coin(Offset(s.width * 0.38, s.height * 0.62), r);
    coin(Offset(s.width * 0.62, s.height * 0.58), r);
    coin(Offset(s.width * 0.50, s.height * 0.38), r);
  }

  void _goblet(Canvas c, Size s, Paint fill, Paint stroke) {
    final cup = Path()
      ..moveTo(s.width * 0.22, s.height * 0.18)
      ..lineTo(s.width * 0.78, s.height * 0.18)
      ..quadraticBezierTo(
        s.width * 0.72,
        s.height * 0.55,
        s.width * 0.50,
        s.height * 0.58,
      )
      ..quadraticBezierTo(
        s.width * 0.28,
        s.height * 0.55,
        s.width * 0.22,
        s.height * 0.18,
      );
    c.drawPath(cup, fill);
    c.drawPath(cup, stroke);
    c.drawLine(
      Offset(s.width * 0.50, s.height * 0.58),
      Offset(s.width * 0.50, s.height * 0.78),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.32, s.height * 0.84),
      Offset(s.width * 0.68, s.height * 0.84),
      stroke,
    );
  }

  void _pearl(Canvas c, Size s, Paint fill, Paint stroke) {
    final shell = Path()
      ..moveTo(s.width * 0.12, s.height * 0.70)
      ..quadraticBezierTo(
        s.width * 0.18,
        s.height * 0.22,
        s.width * 0.50,
        s.height * 0.18,
      )
      ..quadraticBezierTo(
        s.width * 0.82,
        s.height * 0.22,
        s.width * 0.88,
        s.height * 0.70,
      )
      ..close();
    c.drawPath(shell, fill);
    c.drawPath(shell, stroke);
    c.drawCircle(Offset(s.width * 0.50, s.height * 0.52), s.width * 0.16, fill);
    c.drawCircle(
      Offset(s.width * 0.50, s.height * 0.52),
      s.width * 0.16,
      stroke,
    );
  }

  void _crown(Canvas c, Size s, Paint fill, Paint stroke) {
    final p = Path()
      ..moveTo(s.width * 0.12, s.height * 0.78)
      ..lineTo(s.width * 0.12, s.height * 0.42)
      ..lineTo(s.width * 0.30, s.height * 0.58)
      ..lineTo(s.width * 0.50, s.height * 0.18)
      ..lineTo(s.width * 0.70, s.height * 0.58)
      ..lineTo(s.width * 0.88, s.height * 0.42)
      ..lineTo(s.width * 0.88, s.height * 0.78)
      ..close();
    c.drawPath(p, fill);
    c.drawPath(p, stroke);
  }

  void _compass(Canvas c, Size s, Paint fill, Paint stroke) {
    final o = Offset(s.width * 0.5, s.height * 0.5);
    final r = s.width * 0.36;
    c.drawCircle(o, r, fill);
    c.drawCircle(o, r, stroke);
    final needle = Path()
      ..moveTo(o.dx, o.dy - r * 0.7)
      ..lineTo(o.dx + r * 0.16, o.dy)
      ..lineTo(o.dx, o.dy + r * 0.7)
      ..lineTo(o.dx - r * 0.16, o.dy)
      ..close();
    c.drawPath(needle, stroke);
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
    c.drawLine(
      Offset(s.width * 0.32, s.height * 0.48),
      Offset(s.width * 0.70, s.height * 0.58),
      stroke,
    );
  }

  void _gem(Canvas c, Size s, Paint fill, Paint stroke) {
    final p = Path()
      ..moveTo(s.width * 0.50, s.height * 0.12)
      ..lineTo(s.width * 0.82, s.height * 0.38)
      ..lineTo(s.width * 0.50, s.height * 0.88)
      ..lineTo(s.width * 0.18, s.height * 0.38)
      ..close();
    c.drawPath(p, fill);
    c.drawPath(p, stroke);
    c.drawLine(
      Offset(s.width * 0.18, s.height * 0.38),
      Offset(s.width * 0.82, s.height * 0.38),
      stroke,
    );
  }

  void _spyglass(Canvas c, Size s, Paint fill, Paint stroke) {
    final a = Offset(s.width * 0.18, s.height * 0.72);
    final b = Offset(s.width * 0.78, s.height * 0.28);
    c.drawLine(a, b, stroke..strokeWidth = s.width * 0.22);
    final inner = Paint()
      ..color = fill.color
      ..strokeWidth = s.width * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(a, b, inner);
    c.drawCircle(b, s.width * 0.14, fill);
    c.drawCircle(b, s.width * 0.14, stroke..strokeWidth = s.width * 0.08);
  }

  void _key(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawCircle(Offset(s.width * 0.32, s.height * 0.36), s.width * 0.22, fill);
    c.drawCircle(
      Offset(s.width * 0.32, s.height * 0.36),
      s.width * 0.22,
      stroke,
    );
    c.drawCircle(
      Offset(s.width * 0.32, s.height * 0.36),
      s.width * 0.10,
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.48, s.height * 0.48),
      Offset(s.width * 0.84, s.height * 0.78),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.70, s.height * 0.82),
      Offset(s.width * 0.82, s.height * 0.68),
      stroke,
    );
  }

  void _ring(Canvas c, Size s, Paint fill, Paint stroke) {
    final o = Offset(s.width * 0.5, s.height * 0.58);
    c.drawCircle(o, s.width * 0.32, stroke);
    c.drawCircle(o, s.width * 0.18, stroke);
    final gem = Path()
      ..moveTo(s.width * 0.50, s.height * 0.10)
      ..lineTo(s.width * 0.62, s.height * 0.28)
      ..lineTo(s.width * 0.50, s.height * 0.38)
      ..lineTo(s.width * 0.38, s.height * 0.28)
      ..close();
    c.drawPath(gem, fill);
    c.drawPath(gem, stroke);
  }

  void _anchor(Canvas c, Size s, Paint fill, Paint stroke) {
    c.drawCircle(
      Offset(s.width * 0.50, s.height * 0.18),
      s.width * 0.12,
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.50, s.height * 0.28),
      Offset(s.width * 0.50, s.height * 0.78),
      stroke,
    );
    c.drawLine(
      Offset(s.width * 0.28, s.height * 0.42),
      Offset(s.width * 0.72, s.height * 0.42),
      stroke,
    );
    final hook = Path()
      ..moveTo(s.width * 0.18, s.height * 0.62)
      ..quadraticBezierTo(
        s.width * 0.18,
        s.height * 0.92,
        s.width * 0.50,
        s.height * 0.88,
      )
      ..quadraticBezierTo(
        s.width * 0.82,
        s.height * 0.92,
        s.width * 0.82,
        s.height * 0.62,
      );
    c.drawPath(hook, stroke);
    c.drawCircle(Offset(s.width * 0.50, s.height * 0.18), s.width * 0.06, fill);
  }

  @override
  bool shouldRepaint(covariant _TreasurePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
