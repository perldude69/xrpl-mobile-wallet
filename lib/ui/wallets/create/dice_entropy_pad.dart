import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xrpl_mobile_wallet/data/wallet/entropy_mixer.dart';

/// Palette for the five dice (coral, amber, mint, sky, violet).
class DieColor {
  const DieColor({
    required this.face,
    required this.faceDark,
    required this.faceLight,
    required this.pip,
    required this.chipBg,
    required this.chipFg,
    required this.chipBorder,
  });

  final Color face;
  final Color faceDark;
  final Color faceLight;
  final Color pip;
  final Color chipBg;
  final Color chipFg;
  final Color chipBorder;

  static const List<DieColor> palette = [
    DieColor(
      face: Color(0xFFF07167),
      faceDark: Color(0xFFB83C36),
      faceLight: Color(0xFFFFB4A8),
      pip: Color(0xFF2A0C0A),
      chipBg: Color(0x33F07167),
      chipFg: Color(0xFFFFC9C2),
      chipBorder: Color(0x8CF07167),
    ),
    DieColor(
      face: Color(0xFFF0B429),
      faceDark: Color(0xFFB07E08),
      faceLight: Color(0xFFFFE6A3),
      pip: Color(0xFF2E2204),
      chipBg: Color(0x2EF0B429),
      chipFg: Color(0xFFFFE6A3),
      chipBorder: Color(0x8CF0B429),
    ),
    DieColor(
      face: Color(0xFF3ECF8E),
      faceDark: Color(0xFF1A8A56),
      faceLight: Color(0xFFB8F5D4),
      pip: Color(0xFF082016),
      chipBg: Color(0x2E3ECF8E),
      chipFg: Color(0xFFB8F5D4),
      chipBorder: Color(0x8C3ECF8E),
    ),
    DieColor(
      face: Color(0xFF00A3BF),
      faceDark: Color(0xFF006A7C),
      faceLight: Color(0xFFA8E8F5),
      pip: Color(0xFF041820),
      chipBg: Color(0x2E00A3BF),
      chipFg: Color(0xFFA8E8F5),
      chipBorder: Color(0x8C00A3BF),
    ),
    DieColor(
      face: Color(0xFF9B7CF0),
      faceDark: Color(0xFF5E3FB8),
      faceLight: Color(0xFFD4C4FF),
      pip: Color(0xFF140C30),
      chipBg: Color(0x339B7CF0),
      chipFg: Color(0xFFD4C4FF),
      chipBorder: Color(0x8C9B7CF0),
    ),
  ];
}

/// Rigid-body style die: table position + continuous 3D orientation.
///
/// Inspired by Fantastic Dice / dice-box (Ammo rigid bodies): motion and the
/// final face are one simulation — no separate “snap to random face” step.
class _DieBody {
  _DieBody({required this.colorIndex, required this.x, required this.y});

  final int colorIndex;

  /// Center on the felt (logical pixels).
  double x;
  double y;
  double vx = 0;
  double vy = 0;

  /// Orientation as Tait–Bryan angles (radians). Applied Z→Y→X for display.
  double rx = 0;
  double ry = 0;
  double rz = 0;

  /// Angular velocity (rad/s).
  double wx = 0;
  double wy = 0;
  double wz = 0;

  /// Cached face toward camera (1–6), updated every frame from orientation.
  int face = 1;

  /// Per-die rest: each die settles as soon as *it* stops (not the whole set).
  bool easingToRest = false;
  bool settled = false;
  int stillFrames = 0;
  double restT = 0;
  double restRx0 = 0, restRy0 = 0, restRz0 = 0;
  double restRx1 = 0, restRy1 = 0, restRz1 = 0;
}

/// Swipeable dice pad with continuous physics-style tumbling.
class DiceEntropyPad extends StatefulWidget {
  const DiceEntropyPad({super.key, required this.onChanged, this.height = 300});

  final void Function({
    required double motionScore,
    required List<int> faces,
    required List<DiceRollSample> rolls,
  })
  onChanged;

  final double height;

  @override
  State<DiceEntropyPad> createState() => DiceEntropyPadState();
}

class DiceEntropyPadState extends State<DiceEntropyPad>
    with SingleTickerProviderStateMixin {
  static const int _dieCount = 5;
  static const double _dieSize = 46;
  static const double _half = _dieSize / 2;

  /// Keep centers far enough that cubes rarely stack as a pack.
  static const double _sep = _dieSize + 18;
  static const double _wall = 10;

  /// Fixed physics step (~60 Hz) for smooth motion like a real engine.
  static const double _dt = 1 / 60;
  static const double _maxFrame = 0.05;

  final math.Random _rng = math.Random();
  final List<_DieBody> _dice = [];
  final List<DiceRollSample> _rolls = [];
  final List<_PathPoint> _swipePath = [];

  double _motionScore = 0;
  Size _area = Size.zero;
  bool _dragging = false;
  bool _simulating = false;
  Offset? _lastPan;
  double _swipeVx = 0;
  double _swipeVy = 0;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _accum = 0;
  _PendingSample? _pendingSample;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void resetRitual() {
    _ticker?.stop();
    _simulating = false;
    _dragging = false;
    _motionScore = 0;
    _rolls.clear();
    _pendingSample = null;
    _lastTick = Duration.zero;
    _accum = 0;
    if (_area.width >= 48) {
      _spawnDice(_area);
    } else {
      _dice.clear();
    }
    if (mounted) setState(() {});
    _notify();
  }

  void _ensureLayout(Size size) {
    if (!size.width.isFinite || size.width < 48) return;
    final changed = _area != size;
    _area = size;
    if (_dice.isEmpty) {
      _spawnDice(size);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          _notify();
        }
      });
    } else if (changed) {
      final b = _bounds;
      for (final d in _dice) {
        d.x = d.x.clamp(b.left + _half, b.right - _half);
        d.y = d.y.clamp(b.top + _half, b.bottom - _half);
      }
    }
  }

  void _spawnDice(Size size) {
    _dice.clear();
    const starts = [
      Offset(0.20, 0.32),
      Offset(0.50, 0.26),
      Offset(0.78, 0.34),
      Offset(0.34, 0.62),
      Offset(0.66, 0.60),
    ];
    for (var i = 0; i < _dieCount; i++) {
      final d = _DieBody(
        colorIndex: i,
        x: size.width * starts[i].dx,
        y: size.height * starts[i].dy,
      );
      // Rest pose: slight camera-friendly tilt, face 1 forward.
      d.rx = -0.35;
      d.ry = 0.45 + (i - 2) * 0.04;
      d.rz = (i - 2) * 0.08;
      d.face = _faceTowardCamera(d);
      _dice.add(d);
    }
    _resolveCollisions(bounce: false);
    for (final d in _dice) {
      d.face = _faceTowardCamera(d);
    }
  }

  Rect get _bounds => Rect.fromLTRB(
    _wall,
    _wall,
    math.max(_wall + _dieSize, _area.width - _wall),
    math.max(_wall + _dieSize, _area.height - _wall),
  );

  void _notify() {
    widget.onChanged(
      motionScore: _motionScore,
      faces: _dice.map((d) => d.face).toList(growable: false),
      rolls: List<DiceRollSample>.unmodifiable(_rolls),
    );
  }

  void _setMotion(double score) {
    _motionScore = score.clamp(0, 100);
    _notify();
  }

  // ── Orientation / face readout (physics-driven result) ──────────────────

  /// Rotate vector by die orientation (Z then Y then X — matches draw order).
  static List<double> _rotateVec(_DieBody d, double x, double y, double z) {
    // Rz
    final cz = math.cos(d.rz), sz = math.sin(d.rz);
    var x1 = x * cz - y * sz;
    var y1 = x * sz + y * cz;
    var z1 = z;
    // Ry
    final cy = math.cos(d.ry), sy = math.sin(d.ry);
    var x2 = x1 * cy + z1 * sy;
    var y2 = y1;
    var z2 = -x1 * sy + z1 * cy;
    // Rx
    final cx = math.cos(d.rx), sx = math.sin(d.rx);
    final y3 = y2 * cx - z2 * sx;
    final z3 = y2 * sx + z2 * cx;
    return [x2, y3, z3];
  }

  /// Face normals in local space → value on that face.
  /// +Z=1, -Z=6, +X=3, -X=4, +Y=2, -Y=5  (opposites sum to 7).
  static const _faceNormals = <(int, double, double, double)>[
    (1, 0, 0, 1),
    (6, 0, 0, -1),
    (3, 1, 0, 0),
    (4, -1, 0, 0),
    (2, 0, 1, 0),
    (5, 0, -1, 0),
  ];

  /// Camera looks roughly from +Z with a bit of +Y (down onto the table).
  static int _faceTowardCamera(_DieBody d) {
    var best = 1;
    var bestDot = -1e9;
    // Prefer faces pointing toward the viewer (screen out = +Z after rotate).
    for (final (face, nx, ny, nz) in _faceNormals) {
      final w = _rotateVec(d, nx, ny, nz);
      final dot = w[2]; // world Z toward camera
      if (dot > bestDot) {
        bestDot = dot;
        best = face;
      }
    }
    return best;
  }

  /// Snap angles to nearest pose where [face] points at camera.
  static (double, double, double) _restPoseForFace(int face, double preferRz) {
    // Poses that put each face most toward +Z with a gentle display tilt.
    const table = <int, (double, double)>{
      1: (0.0, 0.0),
      2: (-math.pi / 2, 0.0),
      3: (0.0, -math.pi / 2),
      4: (0.0, math.pi / 2),
      5: (math.pi / 2, 0.0),
      6: (0.0, math.pi),
    };
    final base = table[face] ?? (0.0, 0.0);
    // Display tilt so settled dice still look 3D (Fantastic Dice always shows depth).
    const tiltX = -0.32;
    const tiltY = 0.38;
    return (base.$1 + tiltX, base.$2 + tiltY, preferRz);
  }

  static double _normAngle(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  static double _lerpAngle(double a, double b, double t) {
    final d = _normAngle(b - a);
    return a + d * t;
  }

  // ── Collisions ──────────────────────────────────────────────────────────

  void _resolveCollisions({required bool bounce}) {
    final b = _bounds;
    for (var iter = 0; iter < 8; iter++) {
      for (var i = 0; i < _dice.length; i++) {
        for (var j = i + 1; j < _dice.length; j++) {
          final a = _dice[i];
          final c = _dice[j];
          // Settled / face-easing dice act as fixed obstacles.
          final aFixed = a.settled || a.easingToRest;
          final cFixed = c.settled || c.easingToRest;
          if (aFixed && cFixed) continue;

          var dx = c.x - a.x;
          var dy = c.y - a.y;
          var dist = math.sqrt(dx * dx + dy * dy);
          if (dist < 1e-4) {
            final ang = (i * 2.1 + j * 1.7 + iter) + _rng.nextDouble();
            dx = math.cos(ang);
            dy = math.sin(ang);
            dist = 1e-4;
          }
          if (dist < _sep) {
            final overlap = (_sep - dist) * 0.55 + 0.8;
            final nx = dx / dist;
            final ny = dy / dist;
            // Only move non-fixed dice when separating
            if (!aFixed && !cFixed) {
              a.x = (a.x - nx * overlap).clamp(b.left + _half, b.right - _half);
              a.y = (a.y - ny * overlap).clamp(b.top + _half, b.bottom - _half);
              c.x = (c.x + nx * overlap).clamp(b.left + _half, b.right - _half);
              c.y = (c.y + ny * overlap).clamp(b.top + _half, b.bottom - _half);
            } else if (aFixed && !cFixed) {
              c.x = (c.x + nx * overlap * 2).clamp(
                b.left + _half,
                b.right - _half,
              );
              c.y = (c.y + ny * overlap * 2).clamp(
                b.top + _half,
                b.bottom - _half,
              );
            } else if (!aFixed && cFixed) {
              a.x = (a.x - nx * overlap * 2).clamp(
                b.left + _half,
                b.right - _half,
              );
              a.y = (a.y - ny * overlap * 2).clamp(
                b.top + _half,
                b.bottom - _half,
              );
            }
            if (bounce) {
              final vn = (a.vx - c.vx) * nx + (a.vy - c.vy) * ny;
              if (vn < 0) {
                final side = (_rng.nextDouble() - 0.5) * 40;
                if (!aFixed && !cFixed) {
                  final jImp = -(1.35) * vn * 0.5;
                  a.vx += jImp * nx - ny * side;
                  a.vy += jImp * ny + nx * side;
                  c.vx -= jImp * nx - ny * side * 0.6;
                  c.vy -= jImp * ny + nx * side * 0.6;
                  a.wz += -vn * 0.03;
                  c.wz += vn * 0.03;
                  a.wx += ny * 0.9;
                  a.wy += -nx * 0.9;
                  c.wx += -ny * 0.9;
                  c.wy += nx * 0.9;
                } else if (aFixed && !cFixed) {
                  // Bounce off stationary die
                  final jImp = -(1.5) * vn;
                  c.vx -= jImp * nx - ny * side;
                  c.vy -= jImp * ny + nx * side;
                  c.wx += -ny * 1.0;
                  c.wy += nx * 1.0;
                } else if (!aFixed && cFixed) {
                  final jImp = -(1.5) * vn;
                  a.vx += jImp * nx - ny * side;
                  a.vy += jImp * ny + nx * side;
                  a.wx += ny * 1.0;
                  a.wy += -nx * 1.0;
                }
              }
            }
          }
        }
      }
    }
  }

  // ── Simulation step ─────────────────────────────────────────────────────

  bool _dieNearlyStill(_DieBody d) {
    final speed = math.sqrt(d.vx * d.vx + d.vy * d.vy);
    final spin = math.sqrt(d.wx * d.wx + d.wy * d.wy + d.wz * d.wz);
    return speed <= 18 && spin <= 1.2;
  }

  /// Start face settle for one die as soon as it alone has stopped.
  void _beginRestEaseFor(_DieBody d) {
    if (d.easingToRest || d.settled) return;
    final face = _faceTowardCamera(d);
    final pose = _restPoseForFace(face, d.rz);
    d.easingToRest = true;
    d.stillFrames = 0;
    d.restT = 0;
    d.restRx0 = d.rx;
    d.restRy0 = d.ry;
    d.restRz0 = d.rz;
    d.restRx1 = pose.$1;
    d.restRy1 = pose.$2;
    d.restRz1 = _normAngle(pose.$3);
    d.vx = d.vy = 0;
    d.wx = d.wy = d.wz = 0;
    d.face = face;
  }

  void _completeSettleFor(_DieBody d) {
    d.easingToRest = false;
    d.settled = true;
    d.restT = 1;
    d.rx = d.restRx1;
    d.ry = d.restRy1;
    d.rz = d.restRz1;
    d.vx = d.vy = 0;
    d.wx = d.wy = d.wz = 0;
    d.face = _faceTowardCamera(d);
  }

  void _stepPhysics(double dt) {
    final b = _bounds;
    for (final d in _dice) {
      // Already done — stay put (others can bounce off this die).
      if (d.settled) {
        d.vx = d.vy = 0;
        d.wx = d.wy = d.wz = 0;
        continue;
      }

      // Per-die face settle animation
      if (d.easingToRest) {
        d.restT = (d.restT + dt / 0.28).clamp(0.0, 1.0);
        final t = d.restT;
        final e = t * t * (3 - 2 * t); // smoothstep
        d.rx = _lerpAngle(d.restRx0, d.restRx1, e);
        d.ry = _lerpAngle(d.restRy0, d.restRy1, e);
        d.rz = _lerpAngle(d.restRz0, d.restRz1, e);
        d.vx = d.vy = 0;
        d.wx = d.wy = d.wz = 0;
        d.face = _faceTowardCamera(d);
        if (d.restT >= 1) {
          _completeSettleFor(d);
        }
        continue;
      }

      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.rx += d.wx * dt;
      d.ry += d.wy * dt;
      d.rz += d.wz * dt;

      // Walls — stronger bounce + random glancing so they don't all hug one edge
      if (d.x < b.left + _half) {
        d.x = b.left + _half;
        d.vx = d.vx.abs() * 0.72 + 15;
        d.vy += (_rng.nextDouble() - 0.5) * 80;
        d.wy *= -0.55;
        d.wz += d.vx * 0.015;
      } else if (d.x > b.right - _half) {
        d.x = b.right - _half;
        d.vx = -d.vx.abs() * 0.72 - 15;
        d.vy += (_rng.nextDouble() - 0.5) * 80;
        d.wy *= -0.55;
        d.wz += d.vx * 0.015;
      }
      if (d.y < b.top + _half) {
        d.y = b.top + _half;
        d.vy = d.vy.abs() * 0.72 + 15;
        d.vx += (_rng.nextDouble() - 0.5) * 80;
        d.wx *= -0.55;
      } else if (d.y > b.bottom - _half) {
        d.y = b.bottom - _half;
        d.vy = -d.vy.abs() * 0.72 - 15;
        d.vx += (_rng.nextDouble() - 0.5) * 80;
        d.wx *= -0.55;
      }

      final speed = math.sqrt(d.vx * d.vx + d.vy * d.vy);
      final spin = math.sqrt(d.wx * d.wx + d.wy * d.wy + d.wz * d.wz);

      const maxSpin = 10.0;
      if (spin > maxSpin) {
        final s = maxSpin / spin;
        d.wx *= s;
        d.wy *= s;
        d.wz *= s;
      }

      final linDamp = speed > 180 ? 0.996 : (speed > 60 ? 0.982 : 0.94);
      final angDamp = spin > 6 ? 0.985 : 0.955;
      d.vx *= math.pow(linDamp, dt * 60).toDouble();
      d.vy *= math.pow(linDamp, dt * 60).toDouble();
      d.wx *= math.pow(angDamp, dt * 60).toDouble();
      d.wy *= math.pow(angDamp, dt * 60).toDouble();
      d.wz *= math.pow(angDamp, dt * 60).toDouble();

      if (speed > 40) {
        d.wx += -d.vy * 0.004 * dt * 60;
        d.wy += d.vx * 0.004 * dt * 60;
      }

      d.face = _faceTowardCamera(d);

      // Independent settle: this die alone is still enough frames → ease face now
      if (_simulating && _dieNearlyStill(d)) {
        d.stillFrames++;
        if (d.stillFrames >= 4) {
          _beginRestEaseFor(d);
        }
      } else {
        d.stillFrames = 0;
      }
    }

    _resolveCollisions(bounce: true);
  }

  void _onTick(Duration elapsed) {
    if (_area == Size.zero) return;
    final raw = _lastTick == Duration.zero
        ? _dt
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    _accum += raw.clamp(0.0, _maxFrame);

    var steps = 0;
    while (_accum >= _dt && steps < 5) {
      _stepPhysics(_dt);
      _accum -= _dt;
      steps++;
    }

    setState(() {});

    if (!_simulating) return;

    // Roll complete only when every die has finished its own settle.
    if (_dice.isNotEmpty && _dice.every((d) => d.settled)) {
      _finishRoll();
    }
  }

  void _finishRoll() {
    if (!_simulating) return;
    _ticker?.stop();
    _simulating = false;
    _lastTick = Duration.zero;
    _accum = 0;

    final faces = _dice.map((d) => d.face).toList();
    for (final d in _dice) {
      d.vx = d.vy = 0;
      d.wx = d.wy = d.wz = 0;
      d.easingToRest = false;
      d.settled = true;
    }

    final pending = _pendingSample;
    if (pending != null) {
      _rolls.add(
        DiceRollSample(
          pathLength: pending.pathLength,
          durationMs: pending.durationMs,
          speedAvg: pending.speedAvg,
          faces: faces,
          pathPoints: pending.pathPoints,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      _pendingSample = null;
    }

    setState(() {});
    _notify();
  }

  // ── Gestures ────────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details) {
    if (_simulating) return;
    _dragging = true;
    _lastPan = details.localPosition;
    _swipePath
      ..clear()
      ..add(_PathPoint(details.localPosition, DateTime.now()));
    _swipeVx = 0;
    _swipeVy = 0;
    _ticker?.stop();
    for (final d in _dice) {
      d.easingToRest = false;
      d.settled = false;
      d.stillFrames = 0;
      d.restT = 0;
    }
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging || _lastPan == null) return;
    final p = details.localPosition;
    final dx = p.dx - _lastPan!.dx;
    final dy = p.dy - _lastPan!.dy;
    final now = DateTime.now();
    final lastT = _swipePath.isEmpty ? now : _swipePath.last.t;
    final ms = math.max(1, now.difference(lastT).inMilliseconds);
    _swipeVx = dx / ms * 1000; // px/s
    _swipeVy = dy / ms * 1000;
    _swipePath.add(_PathPoint(p, now));

    final b = _bounds;
    final swipeLen = math.sqrt(dx * dx + dy * dy).clamp(0.001, 100.0);
    // Unit swipe + perpendicular for fanning
    final sx = dx / swipeLen;
    final sy = dy / swipeLen;
    final px = -sy;
    final py = sx;

    for (var i = 0; i < _dice.length; i++) {
      final d = _dice[i];
      // Each die gets its own mix of forward + sideways (not a rigid pack)
      final forward = 0.28 + i * 0.05 + _rng.nextDouble() * 0.12;
      final sideSign = (i.isEven ? 1.0 : -1.0) * (0.55 + i * 0.12);
      final side = sideSign * (0.45 + _rng.nextDouble() * 0.55);
      final jitterX = (_rng.nextDouble() - 0.5) * 0.35;
      final jitterY = (_rng.nextDouble() - 0.5) * 0.35;

      final moveX = (sx * forward + px * side + jitterX) * swipeLen;
      final moveY = (sy * forward + py * side + jitterY) * swipeLen;

      d.x = (d.x + moveX).clamp(b.left + _half, b.right - _half);
      d.y = (d.y + moveY).clamp(b.top + _half, b.bottom - _half);
      d.vx = moveX * 18 + (_rng.nextDouble() - 0.5) * 30;
      d.vy = moveY * 18 + (_rng.nextDouble() - 0.5) * 30;

      d.wx += -moveY * 0.018 + (_rng.nextDouble() - 0.5) * 0.15;
      d.wy += moveX * 0.018 + (_rng.nextDouble() - 0.5) * 0.15;
      d.wz += (moveX - moveY) * 0.005;
      d.wx *= 0.9;
      d.wy *= 0.9;
      d.wz *= 0.9;
      d.rx += d.wx * 0.012;
      d.ry += d.wy * 0.012;
      d.rz += d.wz * 0.012;
      d.face = _faceTowardCamera(d);
    }
    _resolveCollisions(bounce: true);
    _lastPan = p;
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    _lastPan = null;

    var pathLen = 0.0;
    var speedSum = 0.0;
    for (var i = 1; i < _swipePath.length; i++) {
      final a = _swipePath[i - 1];
      final b = _swipePath[i];
      pathLen += (b.p - a.p).distance;
      final ms = math.max(1, b.t.difference(a.t).inMilliseconds);
      speedSum += (b.p - a.p).distance / ms * 1000;
    }
    final durationMs = _swipePath.length < 2
        ? 0
        : _swipePath.last.t.difference(_swipePath.first.t).inMilliseconds;
    final contribution = math.min(
      45.0,
      pathLen / 16 + speedSum / 400 + math.min(durationMs / 40, 10),
    );
    _setMotion(_motionScore + contribution);

    // Toss: shared swipe direction + strong per-die scatter so they don't clump.
    final fling = details.velocity.pixelsPerSecond;
    final baseVx = (_swipeVx * 0.5 + fling.dx * 0.18).clamp(-480.0, 480.0);
    final baseVy = (_swipeVy * 0.5 + fling.dy * 0.18).clamp(-480.0, 480.0);
    final baseSpd = math
        .sqrt(baseVx * baseVx + baseVy * baseVy)
        .clamp(1.0, 600.0);
    final fx = baseVx / baseSpd;
    final fy = baseVy / baseSpd;
    final px = -fy;
    final py = fx;

    for (var i = 0; i < _dice.length; i++) {
      final d = _dice[i];
      // Spread angles across a wide cone around the swipe (not a tiny fan)
      final cone = (i / math.max(1, _dieCount - 1) - 0.5) * 1.9; // ~±55°
      final coneJitter = (_rng.nextDouble() - 0.5) * 0.7;
      final ang = cone + coneJitter;
      final cosA = math.cos(ang);
      final sinA = math.sin(ang);
      // Rotate (fx,fy) by ang
      final dirX = fx * cosA - fy * sinA;
      final dirY = fx * sinA + fy * cosA;

      final speedMul = 0.55 + _rng.nextDouble() * 0.7 + i * 0.04;
      final sideBurst =
          (i.isEven ? 1.0 : -1.0) *
          (60 + _rng.nextDouble() * 140) *
          (0.7 + baseSpd / 500);

      d.vx =
          dirX * baseSpd * speedMul +
          px * sideBurst +
          (_rng.nextDouble() - 0.5) * 50;
      d.vy =
          dirY * baseSpd * speedMul +
          py * sideBurst +
          (_rng.nextDouble() - 0.5) * 50;

      // Nudge from current position so clustered dice start separating
      d.x += px * (i - 2) * 6 + (_rng.nextDouble() - 0.5) * 8;
      d.y += py * (i - 2) * 6 + (_rng.nextDouble() - 0.5) * 8;
      final bb = _bounds;
      d.x = d.x.clamp(bb.left + _half, bb.right - _half);
      d.y = d.y.clamp(bb.top + _half, bb.bottom - _half);

      if (math.sqrt(d.vx * d.vx + d.vy * d.vy) < 90) {
        d.vx += dirX * 100 + px * sideBurst * 0.5;
        d.vy += dirY * 100 + py * sideBurst * 0.5;
      }

      final throwSpd = math.sqrt(d.vx * d.vx + d.vy * d.vy);
      final spinScale = (throwSpd / 400).clamp(0.25, 1.0);
      d.wx =
          -d.vy * 0.012 * spinScale + (_rng.nextDouble() - 0.5) * 4 * spinScale;
      d.wy =
          d.vx * 0.012 * spinScale + (_rng.nextDouble() - 0.5) * 4 * spinScale;
      d.wz = (_rng.nextDouble() - 0.5) * 3.5 * spinScale;
      d.easingToRest = false;
      d.settled = false;
      d.stillFrames = 0;
      d.restT = 0;
    }
    // Several separation passes so they don't start overlapping
    for (var k = 0; k < 4; k++) {
      _resolveCollisions(bounce: true);
    }

    _pendingSample = _PendingSample(
      pathLength: pathLen,
      durationMs: durationMs,
      speedAvg: speedSum / math.max(1, _swipePath.length),
      pathPoints: _swipePath
          .take(64)
          .map(
            (pt) => [
              pt.p.dx.round(),
              pt.p.dy.round(),
              pt.t.millisecondsSinceEpoch % 1000000,
            ],
          )
          .toList(),
    );

    _lastTick = Duration.zero;
    _accum = 0;
    _simulating = true;
    _ticker?.start();
    _swipePath.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            _ensureLayout(size);
            return GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _dragging || _simulating
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.45),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A2830),
                      theme.colorScheme.surface.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Felt texture hint
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, 0.2),
                              radius: 0.95,
                              colors: [
                                const Color(0xFF0E3D2F).withValues(alpha: 0.35),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_motionScore < 1 && !_dragging && !_simulating)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Swipe to roll\nToss hard for a longer tumble',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    for (final d in _dice)
                      Positioned(
                        left: d.x - _half - 8,
                        top: d.y - _half - 8,
                        width: _dieSize + 16,
                        height: _dieSize + 16,
                        child: CustomPaint(
                          painter: _CubeDiePainter(
                            size: _dieSize,
                            rx: d.rx,
                            ry: d.ry,
                            rz: d.rz,
                            color: DieColor.palette[d.colorIndex],
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
        Row(
          children: [
            Text('Motion', style: theme.textTheme.labelMedium),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _motionScore / 100,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 40,
              child: Text(
                '${_motionScore.round()}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _dice.length; i++)
              _FaceChip(value: _dice[i].face, color: DieColor.palette[i]),
          ],
        ),
      ],
    );
  }
}

class _PendingSample {
  _PendingSample({
    required this.pathLength,
    required this.durationMs,
    required this.speedAvg,
    required this.pathPoints,
  });

  final double pathLength;
  final int durationMs;
  final double speedAvg;
  final List<List<int>> pathPoints;
}

class _PathPoint {
  _PathPoint(this.p, this.t);
  final Offset p;
  final DateTime t;
}

class _FaceChip extends StatelessWidget {
  const _FaceChip({required this.value, required this.color});

  final int value;
  final DieColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.chipBorder, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: TextStyle(
          color: color.chipFg,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── 3D cube painter (projected, painter’s algorithm) ──────────────────────

class _CubeDiePainter extends CustomPainter {
  _CubeDiePainter({
    required this.size,
    required this.rx,
    required this.ry,
    required this.rz,
    required this.color,
  });

  final double size;
  final double rx, ry, rz;
  final DieColor color;

  static const _pips = <int, List<int>>{
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  /// Local face: center normal, face value, 4 corners in local space.
  static List<_FaceGeom> _faces(double h) {
    // h = half-size
    return [
      _FaceGeom(1, 0, 0, 1, [
        Offset3(-h, -h, h),
        Offset3(h, -h, h),
        Offset3(h, h, h),
        Offset3(-h, h, h),
      ]),
      _FaceGeom(6, 0, 0, -1, [
        Offset3(h, -h, -h),
        Offset3(-h, -h, -h),
        Offset3(-h, h, -h),
        Offset3(h, h, -h),
      ]),
      _FaceGeom(3, 1, 0, 0, [
        Offset3(h, -h, h),
        Offset3(h, -h, -h),
        Offset3(h, h, -h),
        Offset3(h, h, h),
      ]),
      _FaceGeom(4, -1, 0, 0, [
        Offset3(-h, -h, -h),
        Offset3(-h, -h, h),
        Offset3(-h, h, h),
        Offset3(-h, h, -h),
      ]),
      _FaceGeom(2, 0, 1, 0, [
        Offset3(-h, h, h),
        Offset3(h, h, h),
        Offset3(h, h, -h),
        Offset3(-h, h, -h),
      ]),
      _FaceGeom(5, 0, -1, 0, [
        Offset3(-h, -h, -h),
        Offset3(h, -h, -h),
        Offset3(h, -h, h),
        Offset3(-h, -h, h),
      ]),
    ];
  }

  Offset3 _rot(Offset3 p) {
    // Z → Y → X
    var x = p.x, y = p.y, z = p.z;
    final cz = math.cos(rz), sz = math.sin(rz);
    var x1 = x * cz - y * sz;
    var y1 = x * sz + y * cz;
    var z1 = z;
    final cy = math.cos(ry), sy = math.sin(ry);
    var x2 = x1 * cy + z1 * sy;
    var y2 = y1;
    var z2 = -x1 * sy + z1 * cy;
    final cx = math.cos(rx), sx = math.sin(rx);
    final y3 = y2 * cx - z2 * sx;
    final z3 = y2 * sx + z2 * cx;
    return Offset3(x2, y3, z3);
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;
    final h = size / 2;

    // Soft shadow under die
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + h * 0.85),
        width: size * 0.9,
        height: size * 0.28,
      ),
      shadow,
    );

    final faces = _faces(h);
    final projected = <_ProjFace>[];

    for (final f in faces) {
      final wn = _rot(Offset3(f.nx, f.ny, f.nz));
      // Back-face cull (camera along +Z looking toward origin)
      if (wn.z <= 0.02) continue;

      final pts = f.corners.map((c) {
        final w = _rot(c);
        // Simple perspective
        final scale = 1.15 / (1.15 - w.z / (size * 1.8));
        return Offset(cx + w.x * scale, cy + w.y * scale);
      }).toList();

      final depth = f.corners.map((c) => _rot(c).z).reduce((a, b) => a + b) / 4;

      projected.add(
        _ProjFace(
          value: f.value,
          points: pts,
          depth: depth,
          light: wn.z.clamp(0.35, 1.0),
        ),
      );
    }

    // Painter's algorithm: far faces first
    projected.sort((a, b) => a.depth.compareTo(b.depth));

    for (final f in projected) {
      final path = Path()..addPolygon(f.points, true);
      final lit = Color.lerp(color.faceDark, color.faceLight, f.light)!;
      final mid = Color.lerp(color.faceDark, color.face, f.light * 0.85)!;

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            f.points[0],
            f.points[2],
            [lit, mid, color.faceDark],
            const [0.0, 0.45, 1.0],
          ),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.black.withValues(alpha: 0.28),
      );

      // Pips in face quad (bilinear)
      final cells = _pips[f.value] ?? const <int>[];
      final pipR = size * 0.055;
      for (final idx in cells) {
        final col = idx % 3;
        final row = idx ~/ 3;
        final u = (col + 0.5) / 3;
        final v = (row + 0.5) / 3;
        // Shrink toward center so pips sit inside face
        final u2 = 0.18 + u * 0.64;
        final v2 = 0.18 + v * 0.64;
        final p = _bilinear(f.points, u2, v2);
        canvas.drawCircle(
          p.translate(0.5, 0.6),
          pipR,
          Paint()..color = Colors.black.withValues(alpha: 0.2),
        );
        canvas.drawCircle(p, pipR, Paint()..color = color.pip);
        canvas.drawCircle(
          p.translate(-pipR * 0.25, -pipR * 0.25),
          pipR * 0.3,
          Paint()..color = Color.lerp(color.pip, Colors.white, 0.25)!,
        );
      }
    }
  }

  Offset _bilinear(List<Offset> q, double u, double v) {
    // q: TL TR BR BL  (0,1,2,3) for front-like winding
    final top = Offset.lerp(q[0], q[1], u)!;
    final bot = Offset.lerp(q[3], q[2], u)!;
    return Offset.lerp(top, bot, v)!;
  }

  @override
  bool shouldRepaint(covariant _CubeDiePainter old) {
    return old.rx != rx ||
        old.ry != ry ||
        old.rz != rz ||
        old.color.face != color.face;
  }
}

class Offset3 {
  const Offset3(this.x, this.y, this.z);
  final double x, y, z;
}

class _FaceGeom {
  _FaceGeom(this.value, this.nx, this.ny, this.nz, this.corners);
  final int value;
  final double nx, ny, nz;
  final List<Offset3> corners;
}

class _ProjFace {
  _ProjFace({
    required this.value,
    required this.points,
    required this.depth,
    required this.light,
  });
  final int value;
  final List<Offset> points;
  final double depth;
  final double light;
}
