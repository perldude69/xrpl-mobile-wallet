import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xrpl_mobile_wallet/config/app_exit.dart';
import 'package:xrpl_mobile_wallet/data/game/runner_scoreboard.dart';

/// Full-screen landscape endless runner (decoy after failed unlock / game PIN).
///
/// Presents as a standalone title — **Zerpland** — no wallet / PIN language.
class ZerplandRunnerScreen extends StatefulWidget {
  const ZerplandRunnerScreen({super.key});

  @override
  State<ZerplandRunnerScreen> createState() => _ZerplandRunnerScreenState();
}

enum _Phase { ready, playing, gameOver }

enum _ObstacleKind { pillar, tallPillar, drone, glyph }

class _Entity {
  _Entity({
    required this.x,
    required this.kind,
    this.bobPhase = 0,
  });

  double x;
  final _ObstacleKind kind;
  bool collected = false;
  double bobPhase;

  bool get isHazard => kind != _ObstacleKind.glyph;

  double get width => switch (kind) {
        _ObstacleKind.pillar => 30,
        _ObstacleKind.tallPillar => 28,
        _ObstacleKind.drone => 38,
        _ObstacleKind.glyph => 22,
      };

  double get height => switch (kind) {
        _ObstacleKind.pillar => 36,
        _ObstacleKind.tallPillar => 56,
        _ObstacleKind.drone => 30,
        _ObstacleKind.glyph => 22,
      };

  /// Bottom of hit box from ground (0 = ground). Glyphs float.
  double get bottom => switch (kind) {
        _ObstacleKind.drone => 56 + 8 * math.sin(bobPhase),
        _ObstacleKind.glyph => 48 + 10 * math.sin(bobPhase * 1.3),
        _ => 0,
      };
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
    this.size = 2.5,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final Color color;
  final double size;
}

class _FloatText {
  _FloatText({
    required this.text,
    required this.x,
    required this.y,
    required this.life,
  });

  final String text;
  double x;
  double y;
  double life;
}

class _ZerplandRunnerScreenState extends State<ZerplandRunnerScreen>
    with SingleTickerProviderStateMixin {
  static const _gravity = 2550.0;
  static const _jumpV = -860.0;
  static const _doubleJumpV = -780.0;
  static const _runnerW = 48.0;
  static const _runnerH = 40.0;
  static const _maxJumps = 2;

  final _scoreboard = RunnerScoreboard();
  final _rng = math.Random();

  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  _Phase _phase = _Phase.ready;
  double _runnerY = 0; // 0 = on ground, negative = up
  double _runnerVy = 0;
  bool _onGround = true;
  int _jumpsLeft = _maxJumps;
  double _runPhase = 0;
  double _wingPhase = 0;
  double _scroll = 0;
  double _speed = 280;
  double _distance = 0;
  int _score = 0;
  int _best = 0;
  int _glyphs = 0;
  int _combo = 0;
  double _spawnTimer = 0;
  final List<_Entity> _entities = [];
  final List<_Particle> _particles = [];
  final List<_FloatText> _floatTexts = [];
  List<RunnerScoreEntry> _board = const [];
  bool _newHigh = false;
  int _frame = 0;
  double _landSquash = 0;
  double _flash = 0;
  String? _milestone;
  double _milestoneLife = 0;

  late final List<Offset> _stars;
  late final List<_FogPuff> _fog;

  @override
  void initState() {
    super.initState();
    _enterLandscapeFullscreen();
    _stars = List.generate(
      64,
      (i) => Offset(_rng.nextDouble(), _rng.nextDouble() * 0.58),
    );
    _fog = List.generate(
      10,
      (i) => _FogPuff(
        x: _rng.nextDouble(),
        y: 0.55 + _rng.nextDouble() * 0.2,
        w: 80 + _rng.nextDouble() * 120,
        speed: 0.08 + _rng.nextDouble() * 0.12,
      ),
    );
    _ticker = createTicker(_onTick);
    _loadBoard();
  }

  Future<void> _enterLandscapeFullscreen() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restorePortraitChrome() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }

  /// Leave the game screen and return to the unlock PIN (decoy cover).
  Future<void> _closeGame() async {
    await _restorePortraitChrome();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// Quit the whole app from the game (clear exit).
  Future<void> _exitApp() async {
    await _restorePortraitChrome();
    await exitApplication();
  }

  Future<void> _loadBoard() async {
    final board = await _scoreboard.load();
    final best = await _scoreboard.bestScore();
    if (!mounted) return;
    setState(() {
      _board = board.take(RunnerScoreboard.maxEntries).toList();
      _best = best;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _start() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _phase = _Phase.playing;
      _runnerY = 0;
      _runnerVy = 0;
      _onGround = true;
      _jumpsLeft = _maxJumps;
      _runPhase = 0;
      _wingPhase = 0;
      _scroll = 0;
      _speed = 300;
      _distance = 0;
      _score = 0;
      _glyphs = 0;
      _combo = 0;
      _spawnTimer = 1.0;
      _entities.clear();
      _particles.clear();
      _floatTexts.clear();
      _newHigh = false;
      _frame = 0;
      _landSquash = 0;
      _flash = 0;
      _milestone = null;
      _milestoneLife = 0;
      _lastTick = Duration.zero;
    });
    _ticker.start();
  }

  void _jump() {
    if (_phase == _Phase.ready) {
      _start();
      _runnerVy = _jumpV * 0.85;
      _onGround = false;
      _jumpsLeft = _maxJumps - 1;
      _spawnDust(12, soft: true);
      return;
    }
    if (_phase != _Phase.playing) return;
    if (_jumpsLeft <= 0) return;

    final isDouble = !_onGround;
    _runnerVy = isDouble ? _doubleJumpV : _jumpV;
    _onGround = false;
    _jumpsLeft--;
    _wingPhase = 0;
    if (isDouble) {
      HapticFeedback.lightImpact();
      _spawnDust(6, soft: true);
      SystemSound.play(SystemSoundType.click);
    } else {
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _spawnDust(int n, {bool soft = false}) {
    final gy = _groundLineY();
    for (var i = 0; i < n; i++) {
      _particles.add(
        _Particle(
          x: 72 + _runnerW * 0.5 + (_rng.nextDouble() - 0.5) * 20,
          y: gy - 2,
          vx: (_rng.nextDouble() - 0.5) * (soft ? 80 : 140) - 40,
          vy: -20 - _rng.nextDouble() * (soft ? 40 : 90),
          life: 0.25 + _rng.nextDouble() * 0.35,
          color: Colors.white.withValues(alpha: soft ? 0.35 : 0.55),
          size: 1.5 + _rng.nextDouble() * 2.5,
        ),
      );
    }
  }

  void _spawnBurst(Offset at, Color color, int n) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = 60 + _rng.nextDouble() * 180;
      _particles.add(
        _Particle(
          x: at.dx,
          y: at.dy,
          vx: math.cos(a) * sp,
          vy: math.sin(a) * sp,
          life: 0.35 + _rng.nextDouble() * 0.45,
          color: color,
          size: 2 + _rng.nextDouble() * 3,
        ),
      );
    }
  }

  void _onTick(Duration elapsed) {
    if (_phase != _Phase.playing) return;
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final t = dt.clamp(0.0, 0.05);
    _frame++;

    final wasAir = !_onGround;

    // Physics
    _runnerVy += _gravity * t;
    _runnerY += _runnerVy * t;
    if (_runnerY >= 0) {
      _runnerY = 0;
      if (wasAir && _runnerVy > 80) {
        _landSquash = 1;
        _spawnDust(10);
        HapticFeedback.selectionClick();
      }
      _runnerVy = 0;
      _onGround = true;
      _jumpsLeft = _maxJumps;
    }

    if (_onGround) {
      _runPhase += t * (_speed / 38);
    } else {
      _wingPhase += t * 14;
    }
    _landSquash = math.max(0, _landSquash - t * 5);
    _flash = math.max(0, _flash - t * 3);
    if (_milestoneLife > 0) {
      _milestoneLife -= t;
      if (_milestoneLife <= 0) _milestone = null;
    }

    _speed = (300 + _distance * 0.09).clamp(300.0, 680.0);
    _scroll += _speed * t;
    final prevDist = _distance;
    _distance += _speed * t * 0.04;
    _score = math.max(_score, (_distance * 10).floor() + _glyphs * 50 + _combo * 5);

    // Distance milestones
    for (final m in const [100, 250, 500, 1000, 2000]) {
      if (prevDist < m && _distance >= m) {
        _milestone = '${m}m';
        _milestoneLife = 1.4;
        HapticFeedback.mediumImpact();
        break;
      }
    }

    // Spawn
    _spawnTimer -= t;
    if (_spawnTimer <= 0) {
      _spawnEntity();
      _spawnTimer = 0.78 + _rng.nextDouble() * 1.05 - (_speed - 300) / 750;
      _spawnTimer = _spawnTimer.clamp(0.38, 1.7);
    }

    // Move + bob entities
    for (final e in _entities) {
      e.x -= _speed * t;
      e.bobPhase += t * 4;
    }
    _entities.removeWhere((e) => e.x < -90 || e.collected);

    // Particles
    for (final p in _particles) {
      p.x += p.vx * t;
      p.y += p.vy * t;
      p.vy += 280 * t;
      p.life -= t;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final f in _floatTexts) {
      f.y -= 28 * t;
      f.life -= t;
    }
    _floatTexts.removeWhere((f) => f.life <= 0);

    // Collisions
    final runnerRect = Rect.fromLTWH(
      72,
      _groundLineY() - _runnerH + _runnerY,
      _runnerW,
      _runnerH,
    ).deflate(7);

    for (final e in _entities) {
      if (e.collected) continue;
      final oRect = Rect.fromLTWH(
        e.x,
        _groundLineY() - e.height - e.bottom,
        e.width,
        e.height,
      );
      if (!runnerRect.overlaps(oRect.deflate(e.isHazard ? 2 : 0))) continue;

      if (e.kind == _ObstacleKind.glyph) {
        e.collected = true;
        _glyphs++;
        _combo++;
        _score += 50 + (_combo * 5);
        final cx = e.x + e.width / 2;
        final cy = _groundLineY() - e.height / 2 - e.bottom;
        _spawnBurst(Offset(cx, cy), const Color(0xFFE8E4D9), 12);
        _floatTexts.add(
          _FloatText(
            text: '+${50 + _combo * 5}',
            x: cx,
            y: cy - 10,
            life: 0.8,
          ),
        );
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);
      } else {
        _gameOver();
        return;
      }
    }

    // Combo decay when no recent glyph — soft, only via distance
    if (_combo > 0 && _frame % 180 == 0) {
      _combo = math.max(0, _combo - 1);
    }

    setState(() {});
  }

  double _groundLineY() {
    final h = MediaQuery.sizeOf(context).height;
    return h * 0.72;
  }

  void _spawnEntity() {
    final roll = _rng.nextDouble();
    final w = MediaQuery.sizeOf(context).width;
    final x = w + 40;

    // Mix hazards and collectible glyphs
    if (roll < 0.18) {
      _entities.add(
        _Entity(x: x, kind: _ObstacleKind.glyph, bobPhase: _rng.nextDouble() * 6),
      );
      return;
    }

    final kind = roll < 0.50
        ? _ObstacleKind.pillar
        : roll < 0.78
            ? _ObstacleKind.tallPillar
            : _ObstacleKind.drone;
    _entities.add(
      _Entity(x: x, kind: kind, bobPhase: _rng.nextDouble() * 6),
    );

    // Double pillar pack
    if (kind == _ObstacleKind.pillar && _rng.nextDouble() < 0.32) {
      _entities.add(
        _Entity(x: x + 38, kind: _ObstacleKind.pillar),
      );
    }
    // Glyph above a gap sometimes
    if (kind == _ObstacleKind.pillar && _rng.nextDouble() < 0.4) {
      _entities.add(
        _Entity(
          x: x + 70,
          kind: _ObstacleKind.glyph,
          bobPhase: _rng.nextDouble() * 6,
        ),
      );
    }
  }

  Future<void> _gameOver() async {
    _ticker.stop();
    _flash = 1;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    final gy = _groundLineY();
    _spawnBurst(
      Offset(72 + _runnerW / 2, gy + _runnerY - _runnerH / 2),
      const Color(0xFFE8E4D9),
      28,
    );

    final entry = RunnerScoreEntry(
      score: _score,
      distanceM: _distance.floor(),
      at: DateTime.now(),
    );
    final board = await _scoreboard.submit(entry);
    final best = board.isEmpty ? _score : board.first.score;
    if (!mounted) return;
    setState(() {
      _phase = _Phase.gameOver;
      _board = board.take(RunnerScoreboard.maxEntries).toList();
      _newHigh = _score >= best && _score > 0;
      _best = best;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            _jump();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _jump,
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _RunnerPainter(
                  scroll: _scroll,
                  runnerY: _runnerY,
                  onGround: _onGround,
                  runPhase: _runPhase,
                  wingPhase: _wingPhase,
                  entities: List.of(_entities),
                  particles: List.of(_particles),
                  floatTexts: List.of(_floatTexts),
                  stars: _stars,
                  fog: _fog,
                  frame: _frame,
                  speed: _speed,
                  landSquash: _landSquash,
                  flash: _flash,
                ),
              ),

              // Top HUD
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close game',
                        onPressed: _closeGame,
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                      IconButton(
                        tooltip: 'Exit app',
                        onPressed: _exitApp,
                        icon: const Icon(Icons.power_settings_new,
                            color: Colors.white54),
                      ),
                      const Text(
                        'ZERPLAND',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      if (_combo >= 2) ...[
                        _HudChip(
                          label: 'COMBO',
                          value: 'x$_combo',
                          accent: const Color(0xFFC4B5A0),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _HudChip(
                        label: 'SCORE',
                        value: '$_score',
                        accent: const Color(0xFFE8E4D9),
                      ),
                      const SizedBox(width: 8),
                      _HudChip(
                        label: 'BEST',
                        value: '$_best',
                        accent: const Color(0xFFA89878),
                      ),
                    ],
                  ),
                ),
              ),

              if (_milestone != null && _phase == _Phase.playing)
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height * 0.28,
                  child: Opacity(
                    opacity: (_milestoneLife / 1.4).clamp(0.0, 1.0),
                    child: Text(
                      _milestone!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

              if (_phase == _Phase.ready)
                _ReadyOverlay(
                  onPlay: _start,
                  onClose: _closeGame,
                  onExitApp: _exitApp,
                ),
              if (_phase == _Phase.gameOver)
                _GameOverOverlay(
                  score: _score,
                  distanceM: _distance.floor(),
                  glyphs: _glyphs,
                  newHigh: _newHigh,
                  board: _board,
                  onRetry: _start,
                  onClose: _closeGame,
                  onExitApp: _exitApp,
                  theme: theme,
                ),

              if (_phase == _Phase.playing)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Text(
                    _jumpsLeft < 2 && !_onGround
                        ? 'TAP AGAIN · DOUBLE JUMP'
                        : 'TAP TO JUMP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.32),
                      letterSpacing: 3.5,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FogPuff {
  _FogPuff({
    required this.x,
    required this.y,
    required this.w,
    required this.speed,
  });
  final double x;
  final double y;
  final double w;
  final double speed;
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.8),
              fontSize: 9,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyOverlay extends StatelessWidget {
  const _ReadyOverlay({
    required this.onPlay,
    required this.onClose,
    required this.onExitApp,
  });

  final VoidCallback onPlay;
  final VoidCallback onClose;
  final VoidCallback onExitApp;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chalk moth glyph
              CustomPaint(
                size: const Size(72, 48),
                painter: _MothLogoPainter(),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF8A8070)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'LIBER PRIMUS · ENDLESS',
                  style: TextStyle(
                    color: Color(0xFFA89878),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'ZERPLAND',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE8E4D9),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  height: 1.05,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jump pillars · double-jump drones · collect glyphs.\n'
                'How deep into the puzzle can you run?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8E4D9),
                  foregroundColor: const Color(0xFF0A0A0A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.2,
                    fontFamily: 'monospace',
                  ),
                ),
                onPressed: onPlay,
                child: const Text('BEGIN'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('CLOSE'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onExitApp,
                    icon: const Icon(Icons.power_settings_new, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    label: const Text('EXIT APP'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Tap · space · up — double jump in air',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.score,
    required this.distanceM,
    required this.glyphs,
    required this.newHigh,
    required this.board,
    required this.onRetry,
    required this.onClose,
    required this.onExitApp,
    required this.theme,
  });

  final int score;
  final int distanceM;
  final int glyphs;
  final bool newHigh;
  final List<RunnerScoreEntry> board;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback onExitApp;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final top = board.take(RunnerScoreboard.maxEntries).toList();
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    newHigh ? 'NEW HIGH SCORE' : 'SIGNAL LOST',
                    style: TextStyle(
                      color: newHigh
                          ? const Color(0xFFE8E4D9)
                          : const Color(0xFFB07070),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 2.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '${distanceM}m  ·  $glyphs glyphs',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF3A3530),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'TOP 5',
                          style: TextStyle(
                            color: Color(0xFFA89878),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (top.isEmpty)
                          Text(
                            'No scores yet — be the first.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          )
                        else
                          ...top.asMap().entries.map((e) {
                            final i = e.key;
                            final s = e.value;
                            final isTop = i == 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '#${i + 1}',
                                      style: TextStyle(
                                        color: isTop
                                            ? const Color(0xFFE8E4D9)
                                            : Colors.white38,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${s.score}  ·  ${s.distanceM}m',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: isTop ? 1 : 0.8),
                                        fontWeight: isTop
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  Text(
                                    df.format(s.at.toLocal()),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.35),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onClose,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white60,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('CLOSE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: onRetry,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE8E4D9),
                            foregroundColor: const Color(0xFF0A0A0A),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                          child: const Text('AGAIN'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onExitApp,
                      icon: const Icon(Icons.power_settings_new, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      label: const Text('EXIT APP'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────

class _MothLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E4D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2 + 2;
    // Body
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx, cy + 12), paint);
    // Wings
    final wing = Path()
      ..moveTo(cx, cy - 4)
      ..quadraticBezierTo(cx - 28, cy - 18, cx - 30, cy + 2)
      ..quadraticBezierTo(cx - 22, cy + 10, cx, cy + 4)
      ..close();
    canvas.drawPath(wing, paint);
    final wingR = Path()
      ..moveTo(cx, cy - 4)
      ..quadraticBezierTo(cx + 28, cy - 18, cx + 30, cy + 2)
      ..quadraticBezierTo(cx + 22, cy + 10, cx, cy + 4)
      ..close();
    canvas.drawPath(wingR, paint);
    // Antennae
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx - 8, cy - 22), paint);
    canvas.drawLine(Offset(cx, cy - 14), Offset(cx + 8, cy - 22), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RunnerPainter extends CustomPainter {
  _RunnerPainter({
    required this.scroll,
    required this.runnerY,
    required this.onGround,
    required this.runPhase,
    required this.wingPhase,
    required this.entities,
    required this.particles,
    required this.floatTexts,
    required this.stars,
    required this.fog,
    required this.frame,
    required this.speed,
    required this.landSquash,
    required this.flash,
  });

  final double scroll;
  final double runnerY;
  final bool onGround;
  final double runPhase;
  final double wingPhase;
  final List<_Entity> entities;
  final List<_Particle> particles;
  final List<_FloatText> floatTexts;
  final List<Offset> stars;
  final List<_FogPuff> fog;
  final int frame;
  final double speed;
  final double landSquash;
  final double flash;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.72;

    // Void sky
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF000000),
          Color(0xFF0A0A0C),
          Color(0xFF121210),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Stars / dust
    for (final s in stars) {
      final twinkle =
          0.25 + 0.75 * (0.5 + 0.5 * math.sin(frame * 0.07 + s.dx * 24));
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * groundY),
        0.8 + s.dx * 1.4,
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.55),
      );
    }

    // Floating cipher numbers in background
    final cipherPaint = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );
    const codes = ['3', '3', '0', '1', '×', '∴', '⊕'];
    for (var i = 0; i < 9; i++) {
      final x = ((i * 97.0) - (scroll * 0.12) % 97 + size.width) %
              (size.width + 40) -
          20;
      final y = 28.0 + (i * 37 % 90);
      cipherPaint.text = TextSpan(
        text: codes[i % codes.length],
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.04 + (i % 3) * 0.02),
          fontSize: 22 + (i % 4) * 6.0,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
        ),
      );
      cipherPaint.layout();
      cipherPaint.paint(canvas, Offset(x, y));
    }

    // Far ruins / pillars parallax
    final ruinScroll = scroll * 0.22;
    for (var i = -1; i < 14; i++) {
      final x = (i * 70.0) - (ruinScroll % 70);
      final h = 28.0 + ((i * 13) % 55);
      final ruin = Paint()..color = const Color(0xFF1A1814);
      canvas.drawRect(Rect.fromLTWH(x, groundY - h - 16, 22, h), ruin);
      canvas.drawRect(
        Rect.fromLTWH(x - 4, groundY - h - 22, 30, 8),
        Paint()..color = const Color(0xFF242018),
      );
    }

    // Fog bands
    for (final f in fog) {
      final fx = ((f.x * size.width) - scroll * f.speed) %
              (size.width + f.w) -
          f.w * 0.5;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(fx + f.w / 2, f.y * size.height),
          width: f.w,
          height: 28,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.03),
      );
    }

    // Horizon
    canvas.drawLine(
      Offset(0, groundY - 14),
      Offset(size.width, groundY - 14),
      Paint()
        ..color = const Color(0xFF3A3530).withValues(alpha: 0.5)
        ..strokeWidth = 1.2,
    );

    // Ground
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = const Color(0xFF080806),
    );
    // Ground lines
    final grid = Paint()
      ..color = const Color(0xFFE8E4D9).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final gOff = scroll % 36;
    for (var x = -gOff; x < size.width + 36; x += 36) {
      canvas.drawLine(Offset(x, groundY), Offset(x - 18, size.height), grid);
    }
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = const Color(0xFFE8E4D9).withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );

    // Entities
    for (final e in entities) {
      if (e.collected) continue;
      _paintEntity(canvas, e, groundY);
    }

    // Runner (moth)
    final squash = 1 - landSquash * 0.18;
    final stretch = 1 + landSquash * 0.12;
    canvas.save();
    final ox = 72.0;
    final oy = groundY + runnerY - 40;
    canvas.translate(ox + 24, oy + 40);
    canvas.scale(stretch, squash);
    canvas.translate(-24, -40);
    _paintMoth(
      canvas,
      Offset.zero,
      runPhase,
      wingPhase,
      onGround,
      frame,
    );
    canvas.restore();

    // Particles
    for (final p in particles) {
      final a = (p.life * 2).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size,
        Paint()..color = p.color.withValues(alpha: a * p.color.a),
      );
    }

    // Float texts
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (final f in floatTexts) {
      tp.text = TextSpan(
        text: f.text,
        style: TextStyle(
          color: const Color(0xFFE8E4D9).withValues(alpha: f.life.clamp(0, 1)),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(f.x - tp.width / 2, f.y));
    }

    // Death flash
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: flash * 0.35),
      );
    }
  }

  void _paintEntity(Canvas canvas, _Entity e, double groundY) {
    final top = groundY - e.height - e.bottom;
    final rect = Rect.fromLTWH(e.x, top, e.width, e.height);
    switch (e.kind) {
      case _ObstacleKind.pillar:
      case _ObstacleKind.tallPillar:
        final body = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF2A2620), Color(0xFF141210)],
          ).createShader(rect);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          body,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF6A6050),
        );
        // Cap
        canvas.drawRect(
          Rect.fromLTWH(e.x - 4, top, e.width + 8, 6),
          Paint()..color = const Color(0xFF3A3530),
        );
        // Etched number
        final label = e.kind == _ObstacleKind.tallPillar ? '3301' : '∴';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: const Color(0xFFE8E4D9).withValues(alpha: 0.35),
              fontSize: e.kind == _ObstacleKind.tallPillar ? 9 : 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            e.x + (e.width - tp.width) / 2,
            top + e.height / 2 - tp.height / 2,
          ),
        );
      case _ObstacleKind.drone:
        // Hovering sigil disc
        final cx = e.x + e.width / 2;
        final cy = top + e.height / 2;
        canvas.drawCircle(
          Offset(cx, cy),
          e.width / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = const Color(0xFFB0A090),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          e.width / 2 - 6,
          Paint()..color = const Color(0xFF1A1814).withValues(alpha: 0.9),
        );
        // Inner eye
        canvas.drawCircle(
          Offset(cx, cy),
          4,
          Paint()..color = const Color(0xFFE8E4D9),
        );
        // Spinning marks
        final spin = (scroll * 0.35 + e.bobPhase) % (math.pi * 2);
        final rotor = Paint()
          ..color = const Color(0xFF8A8070)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < 3; i++) {
          final a = spin + i * (math.pi * 2 / 3);
          canvas.drawLine(
            Offset(cx + math.cos(a) * 6, cy + math.sin(a) * 6),
            Offset(cx + math.cos(a) * 16, cy + math.sin(a) * 16),
            rotor,
          );
        }
      case _ObstacleKind.glyph:
        final cx = e.x + e.width / 2;
        final cy = top + e.height / 2;
        final pulse =
            0.55 + 0.45 * (0.5 + 0.5 * math.sin(e.bobPhase * 2 + frame * 0.1));
        canvas.drawCircle(
          Offset(cx, cy),
          14,
          Paint()
            ..color = const Color(0xFFE8E4D9).withValues(alpha: 0.08 * pulse),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Color.fromRGBO(232, 228, 217, 0.55 + 0.4 * pulse),
        );
        final tp = TextPainter(
          text: const TextSpan(
            text: '×',
            style: TextStyle(
              color: Color(0xFFE8E4D9),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  void _paintMoth(
    Canvas canvas,
    Offset origin,
    double phase,
    double wingP,
    bool grounded,
    int frame,
  ) {
    final x = origin.dx;
    final y = origin.dy;
    final chalk = const Color(0xFFE8E4D9);
    final ink = const Color(0xFF1A1814);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + 24, y + 42),
        width: grounded ? 36 : 22,
        height: grounded ? 7 : 4,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    final flap = grounded
        ? math.sin(phase * 2) * 0.12
        : 0.35 + math.sin(wingP) * 0.45;
    final legSwing = grounded ? math.sin(phase * 2) * 5 : 1.0;

    // Legs
    final leg = Paint()
      ..color = chalk.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x + 18, y + 30),
      Offset(x + 14, y + 40 + legSwing * 0.3),
      leg,
    );
    canvas.drawLine(
      Offset(x + 28, y + 30),
      Offset(x + 32, y + 40 - legSwing * 0.3),
      leg,
    );

    // Wings (behind body)
    final wingPaint = Paint()
      ..color = chalk.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final wingStroke = Paint()
      ..color = chalk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(x + 22, y + 18);
    canvas.rotate(-0.35 - flap);
    final left = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-22, -16, -26, 4)
      ..quadraticBezierTo(-18, 14, 0, 6)
      ..close();
    canvas.drawPath(left, wingPaint);
    canvas.drawPath(left, wingStroke);
    // Wing vein
    canvas.drawLine(
      Offset.zero,
      const Offset(-18, -2),
      Paint()
        ..color = ink.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(x + 26, y + 18);
    canvas.rotate(0.35 + flap);
    final right = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(22, -16, 26, 4)
      ..quadraticBezierTo(18, 14, 0, 6)
      ..close();
    canvas.drawPath(right, wingPaint);
    canvas.drawPath(right, wingStroke);
    canvas.drawLine(
      Offset.zero,
      const Offset(18, -2),
      Paint()
        ..color = ink.withValues(alpha: 0.25)
        ..strokeWidth = 1,
    );
    canvas.restore();

    // Abdomen / thorax
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 16, y + 14, 16, 20),
        const Radius.circular(8),
      ),
      Paint()..color = chalk,
    );
    // Segments
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(x + 18, y + 20.0 + i * 4),
        Offset(x + 30, y + 20.0 + i * 4),
        Paint()
          ..color = ink.withValues(alpha: 0.2)
          ..strokeWidth = 1,
      );
    }

    // Head
    canvas.drawCircle(Offset(x + 24, y + 12), 7, Paint()..color = chalk);
    // Eyes
    final blink = (frame % 100) < 4;
    if (blink) {
      canvas.drawLine(
        Offset(x + 21, y + 12),
        Offset(x + 24, y + 12),
        Paint()
          ..color = ink
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        Offset(x + 26, y + 12),
        Offset(x + 29, y + 12),
        Paint()
          ..color = ink
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawCircle(Offset(x + 22, y + 11.5), 1.6, Paint()..color = ink);
      canvas.drawCircle(Offset(x + 27, y + 11.5), 1.6, Paint()..color = ink);
    }

    // Antennae
    final ant = Paint()
      ..color = chalk
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final antWave = math.sin(frame * 0.15) * 2;
    canvas.drawLine(
      Offset(x + 22, y + 7),
      Offset(x + 16 + antWave, y - 2),
      ant,
    );
    canvas.drawLine(
      Offset(x + 26, y + 7),
      Offset(x + 32 - antWave, y - 2),
      ant,
    );
    canvas.drawCircle(
      Offset(x + 16 + antWave, y - 2),
      2,
      Paint()..color = chalk,
    );
    canvas.drawCircle(
      Offset(x + 32 - antWave, y - 2),
      2,
      Paint()..color = chalk,
    );

    // Motion streaks when fast
    if (speed > 420 && grounded) {
      final streak = Paint()
        ..color = chalk.withValues(alpha: 0.12)
        ..strokeWidth = 1.5;
      for (var i = 0; i < 3; i++) {
        final sy = y + 12.0 + i * 8;
        canvas.drawLine(
          Offset(x - 6 - i * 4.0, sy),
          Offset(x + 4 - i * 2.0, sy),
          streak,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter old) => true;
}
