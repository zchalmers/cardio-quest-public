import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../cardio_quest_game.dart';

enum ObstacleStyle { hurdle, rock, log }

class ObstacleComponent extends PositionComponent
    with HasGameReference<CardioQuestGame> {
  ObstacleComponent({required double x, required this.style})
    : super(
        position: Vector2(x, 0),
        size: switch (style) {
          ObstacleStyle.hurdle => Vector2(52, 58),
          ObstacleStyle.rock => Vector2(58, 42),
          ObstacleStyle.log => Vector2(72, 35),
        },
        anchor: Anchor.bottomCenter,
        priority: 14,
      );

  final ObstacleStyle style;
  bool _collided = false;
  bool _countedAsCleared = false;

  Rect get collisionRect => Rect.fromLTWH(
    position.x - size.x * 0.38,
    position.y - size.y * 0.82,
    size.x * 0.76,
    size.y * 0.76,
  );

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= game.worldSpeed * dt;
    position.y = game.terrain.yAt(position.x);

    if (!_collided && game.player.collisionRect.overlaps(collisionRect)) {
      _collided = true;
      game.hitObstacle(Vector2(position.x, position.y - size.y * 0.5));
    }
    if (!_countedAsCleared &&
        !_collided &&
        position.x + size.x * 0.5 < game.player.position.x) {
      _countedAsCleared = true;
      game.clearObstacle();
    }
    if (position.x < -size.x - 30) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    switch (style) {
      case ObstacleStyle.hurdle:
        _drawHurdle(canvas);
      case ObstacleStyle.rock:
        _drawRock(canvas);
      case ObstacleStyle.log:
        _drawLog(canvas);
    }
  }

  void _drawHurdle(Canvas canvas) {
    final Paint legPaint = Paint()
      ..color = const Color(0xFFB8C7D1)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(size.x * 0.2, size.y),
        Offset(size.x * 0.3, 12),
        legPaint,
      )
      ..drawLine(
        Offset(size.x * 0.8, size.y),
        Offset(size.x * 0.7, 12),
        legPaint,
      );
    final RRect bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 6, size.x - 2, 14),
      const Radius.circular(5),
    );
    canvas.drawRRect(bar, Paint()..color = const Color(0xFFFF6B7A));
    for (double x = 7; x < size.x - 4; x += 15) {
      canvas.drawRect(
        Rect.fromLTWH(x, 6, 7, 14),
        Paint()..color = const Color(0xFFFFE1A8),
      );
    }
  }

  void _drawRock(Canvas canvas) {
    final Path rock = Path()
      ..moveTo(2, size.y)
      ..quadraticBezierTo(5, 13, 19, 11)
      ..quadraticBezierTo(30, -1, 42, 10)
      ..quadraticBezierTo(56, 15, size.x - 2, size.y)
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF7F91A0), Color(0xFF354B5B)],
        ).createShader(Offset.zero & Size(size.x, size.y)),
    );
    canvas.drawLine(
      const Offset(18, 14),
      const Offset(26, 26),
      Paint()
        ..color = const Color(0x669FC0CE)
        ..strokeWidth = 2,
    );
  }

  void _drawLog(Canvas canvas) {
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 7, size.x - 4, size.y - 9),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFF8B5636), Color(0xFF4D3026)],
        ).createShader(body.outerRect),
    );
    canvas.drawCircle(
      Offset(size.x - 8, size.y * 0.6),
      10,
      Paint()..color = const Color(0xFFB8794E),
    );
    canvas.drawCircle(
      Offset(size.x - 8, size.y * 0.6),
      5,
      Paint()
        ..color = const Color(0xFF6F432D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final Paint twig = Paint()
      ..color = const Color(0xFF5C3828)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.x * 0.34, 10), Offset(size.x * 0.25, 1), twig);
  }
}
