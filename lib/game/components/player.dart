import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Alignment, LinearGradient;

import '../../core/constants.dart';
import '../../models/machine_models.dart';
import '../../services/cosmetics_service.dart';
import '../cardio_quest_game.dart';

class RunnerPlayer extends PositionComponent
    with HasGameReference<CardioQuestGame> {
  RunnerPlayer()
    : super(size: Vector2(76, 100), anchor: Anchor.bottomCenter, priority: 30);

  double verticalVelocity = 0;
  double _animationClock = 0;
  double _coyoteRemaining = 0;
  bool _grounded = true;
  bool _queuedJump = false;
  double _impactSquash = 0;
  double _footstepRemaining = 0;

  bool get isGrounded => _grounded;

  Rect get collisionRect => Rect.fromCenter(
    center: Offset(position.x, position.y - size.y * 0.44),
    width: GameConstants.playerCollisionWidth,
    height: GameConstants.playerCollisionHeight,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(
      game.size.x * GameConstants.playerScreenX,
      game.terrain.yAt(game.size.x * GameConstants.playerScreenX),
    );
  }

  void jump() {
    if (_grounded || _coyoteRemaining > 0) {
      _performJump();
    } else {
      _queuedJump = true;
    }
  }

  void _performJump() {
    verticalVelocity = GameConstants.jumpVelocity;
    _grounded = false;
    _coyoteRemaining = 0;
    _queuedJump = false;
    _impactSquash = 0;
    game.audioEngine.playJump();
    game.particles.jumpBurst(position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x = game.size.x * GameConstants.playerScreenX;
    final double groundY = game.terrain.yAt(position.x);

    final double animationRate = switch (game.motionMode) {
      MotionMode.walk => 5.2,
      MotionMode.jog => 8.6,
      MotionMode.sprint => 12.8,
    };
    _animationClock += dt * animationRate;
    _impactSquash = math.max(0.0, _impactSquash - dt * 5.5);

    if (_grounded) {
      _coyoteRemaining = GameConstants.coyoteTimeSeconds;
      position.y = groundY;
      if (game.worldSpeed > 0) {
        final double measuredCadence = game.machineMetrics.cadenceRpm;
        final double cadence = measuredCadence > 20
            ? measuredCadence
            : switch (game.motionMode) {
                MotionMode.walk => 108,
                MotionMode.jog => 154,
                MotionMode.sprint => 184,
              };
        _footstepRemaining -= dt;
        if (_footstepRemaining <= 0) {
          game.audioEngine.playFootstep(game.motionMode, cadenceRpm: cadence);
          game.particles.footstepDust(
            Vector2(position.x - 18, position.y - 2),
            game.normalizedSpeed,
          );
          _footstepRemaining += (60 / cadence).clamp(0.24, 0.8).toDouble();
        }
      } else {
        _footstepRemaining = 0;
      }
    } else {
      _coyoteRemaining = math.max(0.0, _coyoteRemaining - dt);
      verticalVelocity += GameConstants.gravity * dt;
      position.y += verticalVelocity * dt;
      if (position.y >= groundY) {
        position.y = groundY;
        verticalVelocity = 0;
        _grounded = true;
        _impactSquash = 1;
        game.particles.landingBurst(position, game.normalizedSpeed);
        if (_queuedJump) {
          _performJump();
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final MotionMode mode = game.motionMode;
    final double speedAmount = game.normalizedSpeed;
    final double cycle = math.sin(_animationClock * math.pi * 2);
    final double opposingCycle = math.sin(
      _animationClock * math.pi * 2 + math.pi,
    );
    final double bob = _grounded ? cycle.abs() * -2.5 : -1;
    final double lean = switch (mode) {
      MotionMode.walk => 0.02,
      MotionMode.jog => 0.11,
      MotionMode.sprint => 0.23,
    };
    final double stride = switch (mode) {
      MotionMode.walk => 12,
      MotionMode.jog => 20,
      MotionMode.sprint => 27,
    };

    canvas.save();
    canvas.translate(size.x * 0.5, 5 + bob);
    canvas.scale(1 + _impactSquash * 0.08, 1 - _impactSquash * 0.1);
    canvas.rotate(lean);

    final CosmeticDefinition skin = game.cosmeticsService.characterSkin;
    final CosmeticDefinition trail = game.cosmeticsService.trailEffect;
    if (trail.id != 'trail_none' && game.combo >= trail.minimumCombo) {
      _drawTrail(canvas, trail, cycle, speedAmount);
    }

    if (mode == MotionMode.sprint) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(-5, 44),
          width: 74 + speedAmount * 18,
          height: 88,
        ),
        Paint()
          ..color = game.palette.accent.withValues(alpha: 0.11)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    final Paint limbPaint = Paint()
      ..color = skin.secondary
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint skinPaint = Paint()
      ..color = const Color(0xFFFFC59D)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Paint shoePaint = Paint()
      ..color = skin.primary
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Offset hip = const Offset(0, 57);
    final Offset shoulder = Offset(2, 30 - lean * 10);
    _drawLeg(canvas, hip, cycle, stride, limbPaint, shoePaint, rear: true);
    _drawArm(
      canvas,
      shoulder,
      opposingCycle,
      stride * 0.62,
      limbPaint,
      skinPaint,
      rear: true,
    );

    final RRect torso = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 39), width: 29, height: 38),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            skin.primary,
            Color.lerp(skin.primary, const Color(0xFFFFFFFF), 0.34)!,
          ],
        ).createShader(torso.outerRect),
    );
    canvas.drawCircle(
      const Offset(-10, 29),
      5,
      Paint()..color = const Color(0xAAFFFFFF),
    );

    _drawLeg(canvas, hip, opposingCycle, stride, limbPaint, shoePaint);
    _drawArm(canvas, shoulder, cycle, stride * 0.62, limbPaint, skinPaint);

    canvas.drawCircle(
      const Offset(2, 15),
      13,
      Paint()..color = const Color(0xFFFFC59D),
    );
    final Path hair = Path()
      ..moveTo(-10, 14)
      ..quadraticBezierTo(-7, -1, 7, 3)
      ..quadraticBezierTo(16, 7, 13, 14)
      ..quadraticBezierTo(4, 8, -10, 14)
      ..close();
    canvas.drawPath(hair, Paint()..color = skin.secondary);
    canvas.drawCircle(
      const Offset(7, 14),
      1.8,
      Paint()..color = const Color(0xFF132331),
    );

    canvas.restore();
  }

  void _drawTrail(
    Canvas canvas,
    CosmeticDefinition trail,
    double cycle,
    double speedAmount,
  ) {
    final double strength = ((game.combo - trail.minimumCombo + 1) / 5)
        .clamp(0.25, 1)
        .toDouble();
    switch (trail.id) {
      case 'trail_fire':
        for (int i = 0; i < 7; i++) {
          final double x = -18 - i * (7 + speedAmount * 3);
          final double flicker = math.sin(_animationClock * 9 + i) * 5;
          final Path flame = Path()
            ..moveTo(x, 68 + flicker)
            ..quadraticBezierTo(x - 12, 57, x - 21, 69)
            ..quadraticBezierTo(x - 10, 78, x, 68)
            ..close();
          canvas.drawPath(
            flame,
            Paint()
              ..color = Color.lerp(
                trail.primary,
                trail.secondary,
                i / 7,
              )!.withValues(alpha: (1 - i / 8) * strength),
          );
        }
      case 'trail_electric':
        final Path bolt = Path()..moveTo(-12, 48);
        for (int i = 1; i < 9; i++) {
          bolt.lineTo(
            -12 - i * 10,
            48 + math.sin(_animationClock * 15 + i * 2.2) * 12,
          );
        }
        canvas.drawPath(
          bolt,
          Paint()
            ..color = trail.primary.withValues(alpha: strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      case 'trail_rainbow':
        const List<Color> colors = <Color>[
          Color(0xFFFF6B7A),
          Color(0xFFFFC857),
          Color(0xFF65F2D0),
          Color(0xFF5DAAFF),
          Color(0xFFC89BFF),
        ];
        for (int i = 0; i < colors.length; i++) {
          final Path ribbon = Path()
            ..moveTo(-10, 38 + i * 6)
            ..quadraticBezierTo(-55, 26 + i * 7 + cycle * 5, -112, 43 + i * 5);
          canvas.drawPath(
            ribbon,
            Paint()
              ..color = colors[i].withValues(alpha: 0.75 * strength)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          );
        }
      case 'trail_ghost':
        for (int i = 1; i <= 4; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(-i * 21.0, 48 + cycle * i),
              width: 23,
              height: 56,
            ),
            Paint()
              ..color = trail.primary.withValues(
                alpha: (0.2 - i * 0.03) * strength,
              ),
          );
        }
      case 'trail_comet':
        final Rect comet = Rect.fromLTWH(-118, 37 + cycle * 2, 108, 20);
        canvas.drawRRect(
          RRect.fromRectAndRadius(comet, const Radius.circular(10)),
          Paint()
            ..shader = LinearGradient(
              colors: <Color>[
                trail.secondary.withValues(alpha: 0),
                trail.primary.withValues(alpha: 0.9 * strength),
              ],
            ).createShader(comet)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
    }
  }

  void _drawLeg(
    Canvas canvas,
    Offset hip,
    double phase,
    double stride,
    Paint limbPaint,
    Paint shoePaint, {
    bool rear = false,
  }) {
    final double depth = rear ? 0.76 : 1;
    final Offset knee = Offset(
      hip.dx + phase * stride * 0.48,
      hip.dy + 17 - phase.abs() * 4,
    );
    final Offset foot = Offset(
      hip.dx + phase * stride,
      hip.dy + 35 - math.max(0.0, phase) * 7,
    );
    final Paint leg = Paint()
      ..color = limbPaint.color.withValues(alpha: depth)
      ..strokeWidth = limbPaint.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(hip, knee, leg)
      ..drawLine(knee, foot, leg);
    final Paint shoe = Paint()
      ..color = shoePaint.color.withValues(alpha: depth)
      ..strokeWidth = shoePaint.strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(foot, foot + const Offset(8, 0), shoe);
  }

  void _drawArm(
    Canvas canvas,
    Offset shoulder,
    double phase,
    double range,
    Paint sleevePaint,
    Paint skinPaint, {
    bool rear = false,
  }) {
    final double depth = rear ? 0.62 : 1;
    final Offset elbow = Offset(
      shoulder.dx - phase * range * 0.55,
      shoulder.dy + 12,
    );
    final Offset hand = Offset(
      shoulder.dx - phase * range,
      shoulder.dy + 19 - phase.abs() * 2,
    );
    final Paint sleeve = Paint()
      ..color = sleevePaint.color.withValues(alpha: depth)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final Paint skin = Paint()
      ..color = skinPaint.color.withValues(alpha: depth)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(shoulder, elbow, sleeve)
      ..drawLine(elbow, hand, skin);
  }
}
