import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/machine_models.dart';
import '../cardio_quest_game.dart';

class CoinComponent extends PositionComponent
    with HasGameReference<CardioQuestGame> {
  CoinComponent({
    required double x,
    required this.heightAboveGround,
    this.phase = 0,
  }) : super(
         position: Vector2(x, 0),
         size: Vector2.all(GameConstants.coinRadius * 2),
         anchor: Anchor.center,
         priority: 12,
       );

  final double heightAboveGround;
  final double phase;
  double _clock = 0;
  bool _collected = false;
  bool _magnetized = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_collected) {
      return;
    }
    _clock += dt;
    position.x -= game.worldSpeed * dt;

    final Vector2 playerTarget = Vector2(
      game.player.position.x,
      game.player.position.y - 48,
    );
    final double distance = position.distanceTo(playerTarget);
    if (game.magnetActive && distance < 240) {
      _magnetized = true;
    }

    if (_magnetized) {
      final Vector2 direction = playerTarget - position;
      final double pull = 480 + (240 - distance).clamp(0, 240).toDouble() * 3;
      if (direction.length2 > 0.01) {
        position.add(direction.normalized() * pull * dt);
      }
    } else {
      position.y =
          game.terrain.yAt(position.x) -
          heightAboveGround +
          math.sin(_clock * 4 + phase) * 6;
    }

    if (position.distanceTo(playerTarget) < 34) {
      _collected = true;
      game.collectCoin(position.clone());
      removeFromParent();
      return;
    }
    if (position.x < -60) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final double spin = math.cos(_clock * 8 + phase).abs();
    final double coinWidth = 5 + size.x * 0.8 * spin;
    final Offset center = Offset(size.x / 2, size.y / 2);

    canvas.drawCircle(
      center,
      size.x * 0.55,
      Paint()
        ..color = game.palette.accentWarm.withValues(alpha: 0.19)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final RRect coin = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: coinWidth, height: size.y * 0.9),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      coin,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF2A8),
            Color(0xFFFFC83D),
            Color(0xFFE89716),
          ],
        ).createShader(coin.outerRect),
    );
    if (coinWidth > 14) {
      canvas.drawCircle(
        center,
        size.x * 0.23,
        Paint()
          ..color = const Color(0x66FFF4B5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}

class PowerUpComponent extends PositionComponent
    with HasGameReference<CardioQuestGame> {
  PowerUpComponent({
    required double x,
    required this.type,
    this.heightAboveGround = 90,
  }) : super(
         position: Vector2(x, 0),
         size: Vector2.all(48),
         anchor: Anchor.center,
         priority: 13,
       );

  final PowerUpType type;
  final double heightAboveGround;
  double _clock = 0;
  bool _collected = false;

  Color get _color => switch (type) {
    PowerUpType.magnet => const Color(0xFF65F2D0),
    PowerUpType.shield => const Color(0xFF9BB7FF),
    PowerUpType.doubleCoins => const Color(0xFFFFD166),
  };

  @override
  void update(double dt) {
    super.update(dt);
    if (_collected) {
      return;
    }
    _clock += dt;
    position.x -= game.worldSpeed * dt;
    position.y =
        game.terrain.yAt(position.x) -
        heightAboveGround +
        math.sin(_clock * 3.4) * 8;

    final Vector2 target = Vector2(
      game.player.position.x,
      game.player.position.y - 48,
    );
    if (position.distanceTo(target) < 43) {
      _collected = true;
      game.activatePowerUp(type, position.clone());
      removeFromParent();
      return;
    }
    if (position.x < -70) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final Offset center = Offset(size.x / 2, size.y / 2);
    final double pulse = 1 + math.sin(_clock * 5) * 0.08;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulse);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(
      center,
      25,
      Paint()
        ..color = _color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = const Color(0xE6172C3C)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = _color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    switch (type) {
      case PowerUpType.magnet:
        _drawMagnet(canvas, center);
      case PowerUpType.shield:
        _drawShield(canvas, center);
      case PowerUpType.doubleCoins:
        _drawDouble(canvas, center);
    }
    canvas.restore();
  }

  void _drawMagnet(Canvas canvas, Offset center) {
    final Rect arc = Rect.fromCenter(center: center, width: 23, height: 24);
    canvas.drawArc(
      arc,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = _color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.square,
    );
    final Paint tip = Paint()..color = const Color(0xFFFF6B7A);
    canvas
      ..drawRect(
        Rect.fromCenter(
          center: center + const Offset(-11.5, 6),
          width: 6,
          height: 7,
        ),
        tip,
      )
      ..drawRect(
        Rect.fromCenter(
          center: center + const Offset(11.5, 6),
          width: 6,
          height: 7,
        ),
        tip,
      );
  }

  void _drawShield(Canvas canvas, Offset center) {
    final Path shield = Path()
      ..moveTo(center.dx, center.dy - 12)
      ..quadraticBezierTo(
        center.dx + 12,
        center.dy - 9,
        center.dx + 11,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 8,
        center.dy + 10,
        center.dx,
        center.dy + 14,
      )
      ..quadraticBezierTo(
        center.dx - 8,
        center.dy + 10,
        center.dx - 11,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - 12,
        center.dy - 9,
        center.dx,
        center.dy - 12,
      )
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = _color.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = _color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawDouble(Canvas canvas, Offset center) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '2×',
        style: TextStyle(
          color: _color,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}
