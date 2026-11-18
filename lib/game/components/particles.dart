import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../models/machine_models.dart';
import '../cardio_quest_game.dart';

enum _ParticleKind { dust, sparkle, speedLine, heart, shard }

class _JuiceParticle {
  _JuiceParticle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.size,
    required this.color,
    required this.kind,
    this.gravity = 0,
    this.rotation = 0,
    this.spin = 0,
  }) : initialLife = life;

  final Vector2 position;
  final Vector2 velocity;
  final double initialLife;
  final double size;
  final Color color;
  final _ParticleKind kind;
  final double gravity;
  double life;
  double rotation;
  double spin;
}

class JuiceParticles extends Component with HasGameReference<CardioQuestGame> {
  JuiceParticles() : super(priority: 55);

  final math.Random _random = math.Random(731);
  final List<_JuiceParticle> _particles = <_JuiceParticle>[];
  double _speedLineTimer = 0;
  double _flash = 0;
  Color _flashColor = const Color(0xFFFFFFFF);

  void footstepDust(Vector2 origin, double intensity) {
    if (_particles.length > 180) {
      return;
    }
    final int count = 1 + (intensity * 2).round();
    for (int i = 0; i < count; i++) {
      _particles.add(
        _JuiceParticle(
          position: origin.clone(),
          velocity: Vector2(
            -30 - _random.nextDouble() * 75,
            -12 - _random.nextDouble() * 24,
          ),
          life: 0.32 + _random.nextDouble() * 0.22,
          size: 4 + _random.nextDouble() * 7,
          color: game.palette.groundEdge.withValues(alpha: 0.56),
          kind: _ParticleKind.dust,
          gravity: 90,
        ),
      );
    }
  }

  void landingBurst(Vector2 origin, double intensity) {
    for (int i = 0; i < 9; i++) {
      final double angle = math.pi + _random.nextDouble() * math.pi;
      final double speed = 35 + _random.nextDouble() * (90 + intensity * 80);
      _particles.add(
        _JuiceParticle(
          position: Vector2(origin.x, origin.y - 2),
          velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
          life: 0.38 + _random.nextDouble() * 0.28,
          size: 4 + _random.nextDouble() * 8,
          color: game.palette.groundEdge.withValues(alpha: 0.6),
          kind: _ParticleKind.dust,
          gravity: 150,
        ),
      );
    }
  }

  void jumpBurst(Vector2 origin) {
    for (int i = 0; i < 5; i++) {
      _particles.add(
        _JuiceParticle(
          position: Vector2(origin.x - 10, origin.y - 4),
          velocity: Vector2(
            -40 - _random.nextDouble() * 55,
            -20 + _random.nextDouble() * 30,
          ),
          life: 0.28 + _random.nextDouble() * 0.18,
          size: 4 + _random.nextDouble() * 5,
          color: game.palette.groundEdge.withValues(alpha: 0.5),
          kind: _ParticleKind.dust,
          gravity: 100,
        ),
      );
    }
  }

  void coinSparkle(Vector2 origin, {bool doubled = false}) {
    for (int i = 0; i < 14; i++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      final double speed = 60 + _random.nextDouble() * 130;
      _particles.add(
        _JuiceParticle(
          position: origin.clone(),
          velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
          life: 0.42 + _random.nextDouble() * 0.35,
          size: 2.5 + _random.nextDouble() * 4,
          color: doubled ? const Color(0xFFFFFFFF) : game.palette.accentWarm,
          kind: _ParticleKind.sparkle,
          gravity: 80,
          rotation: angle,
          spin: -5 + _random.nextDouble() * 10,
        ),
      );
    }
  }

  void powerUpBurst(Vector2 origin, PowerUpType type) {
    final Color color = switch (type) {
      PowerUpType.magnet => const Color(0xFF65F2D0),
      PowerUpType.shield => const Color(0xFF9BB7FF),
      PowerUpType.doubleCoins => const Color(0xFFFFD166),
    };
    for (int i = 0; i < 22; i++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      final double speed = 55 + _random.nextDouble() * 160;
      _particles.add(
        _JuiceParticle(
          position: origin.clone(),
          velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
          life: 0.5 + _random.nextDouble() * 0.45,
          size: 3 + _random.nextDouble() * 5,
          color: color,
          kind: _ParticleKind.shard,
          gravity: 65,
          rotation: angle,
          spin: -7 + _random.nextDouble() * 14,
        ),
      );
    }
    _flashScreen(color, 0.18);
  }

  void obstacleImpact(Vector2 origin, {required bool shielded}) {
    final Color color = shielded
        ? const Color(0xFF9BB7FF)
        : const Color(0xFFFF5572);
    for (int i = 0; i < 18; i++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      _particles.add(
        _JuiceParticle(
          position: origin.clone(),
          velocity: Vector2(
            math.cos(angle) * (80 + _random.nextDouble() * 160),
            math.sin(angle) * (80 + _random.nextDouble() * 160),
          ),
          life: 0.34 + _random.nextDouble() * 0.4,
          size: 3 + _random.nextDouble() * 5,
          color: color,
          kind: _ParticleKind.shard,
          gravity: 120,
          rotation: angle,
          spin: -8 + _random.nextDouble() * 16,
        ),
      );
    }
    _flashScreen(color, shielded ? 0.12 : 0.24);
  }

  void _flashScreen(Color color, double amount) {
    _flashColor = color;
    _flash = math.max(_flash, amount);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flash = math.max(0.0, _flash - dt * 1.8);
    _speedLineTimer -= dt;
    if (game.motionMode == MotionMode.sprint &&
        game.worldSpeed > 0 &&
        _speedLineTimer <= 0) {
      _speedLineTimer = 0.035 + _random.nextDouble() * 0.055;
      _particles.add(
        _JuiceParticle(
          position: Vector2(
            game.size.x * (0.46 + _random.nextDouble() * 0.54),
            game.size.y * (0.18 + _random.nextDouble() * 0.54),
          ),
          velocity: Vector2(-620 - _random.nextDouble() * 320, 0),
          life: 0.18 + _random.nextDouble() * 0.16,
          size: 1.4 + _random.nextDouble() * 2.2,
          color: const Color(0xFFFFFFFF),
          kind: _ParticleKind.speedLine,
        ),
      );
    }

    for (final _JuiceParticle particle in _particles) {
      particle.life -= dt;
      particle.velocity.y += particle.gravity * dt;
      particle.position.add(particle.velocity * dt);
      particle.rotation += particle.spin * dt;
    }
    _particles.removeWhere(
      (_JuiceParticle particle) =>
          particle.life <= 0 ||
          particle.position.y > game.size.y + 80 ||
          particle.position.x < -180,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final _JuiceParticle particle in _particles) {
      final double progress = (particle.life / particle.initialLife)
          .clamp(0, 1)
          .toDouble();
      final Paint paint = Paint()
        ..color = particle.color.withValues(alpha: progress * 0.82);
      switch (particle.kind) {
        case _ParticleKind.dust:
          canvas.drawCircle(
            particle.position.toOffset(),
            particle.size * (1.25 - progress * 0.25),
            paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        case _ParticleKind.speedLine:
          canvas.drawLine(
            particle.position.toOffset(),
            Offset(
              particle.position.x + particle.size * 28,
              particle.position.y,
            ),
            paint
              ..strokeWidth = particle.size
              ..strokeCap = StrokeCap.round,
          );
        case _ParticleKind.sparkle:
          _drawSparkle(canvas, particle, paint);
        case _ParticleKind.shard:
          canvas.save();
          canvas.translate(particle.position.x, particle.position.y);
          canvas.rotate(particle.rotation);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: particle.size * 2.1,
                height: particle.size,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
          canvas.restore();
        case _ParticleKind.heart:
          canvas.drawCircle(particle.position.toOffset(), particle.size, paint);
      }
    }

    if (_flash > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, game.size.x, game.size.y),
        Paint()..color = _flashColor.withValues(alpha: _flash),
      );
    }
  }

  void _drawSparkle(Canvas canvas, _JuiceParticle particle, Paint paint) {
    canvas.save();
    canvas.translate(particle.position.x, particle.position.y);
    canvas.rotate(particle.rotation);
    final Path star = Path()
      ..moveTo(0, -particle.size * 1.8)
      ..lineTo(particle.size * 0.45, -particle.size * 0.42)
      ..lineTo(particle.size * 1.8, 0)
      ..lineTo(particle.size * 0.45, particle.size * 0.42)
      ..lineTo(0, particle.size * 1.8)
      ..lineTo(-particle.size * 0.45, particle.size * 0.42)
      ..lineTo(-particle.size * 1.8, 0)
      ..lineTo(-particle.size * 0.45, -particle.size * 0.42)
      ..close();
    canvas.drawPath(star, paint);
    canvas.restore();
  }
}
