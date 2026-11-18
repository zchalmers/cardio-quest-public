import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Alignment, LinearGradient;

import '../cardio_quest_game.dart';

class TerrainComponent extends Component
    with HasGameReference<CardioQuestGame> {
  TerrainComponent() : super(priority: -5);

  double _scroll = 0;
  double _smoothedIncline = 0;

  double get smoothedIncline => _smoothedIncline;

  @override
  void update(double dt) {
    super.update(dt);
    _scroll += game.worldSpeed * dt;
    _smoothedIncline +=
        (game.machineMetrics.inclinePercent - _smoothedIncline) *
        (1 - math.exp(-dt * 1.7));
  }

  double yAt(double x) {
    if (game.size.y <= 0) {
      return 0;
    }
    final double base = game.size.y * 0.79;
    final double broadWave =
        math.sin((_scroll + x) * 0.0042) * game.size.y * 0.025;
    final double detailWave =
        math.sin((_scroll + x) * 0.012 + 1.7) * game.size.y * 0.009;
    final double playerX = game.size.x * 0.22;
    final double inclineDelta =
        -(x - playerX) * (_smoothedIncline.clamp(-10, 20).toDouble() / 100);
    return (base + broadWave + detailWave + inclineDelta)
        .clamp(game.size.y * 0.48, game.size.y * 0.91)
        .toDouble();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.size.x <= 0 || game.size.y <= 0) {
      return;
    }
    final Path ground = Path()..moveTo(0, yAt(0));
    final Path rim = Path()..moveTo(0, yAt(0));
    for (double x = 18; x <= game.size.x + 18; x += 18) {
      final double y = yAt(x);
      ground.lineTo(x, y);
      rim.lineTo(x, y);
    }
    ground
      ..lineTo(game.size.x + 18, game.size.y + 20)
      ..lineTo(0, game.size.y + 20)
      ..close();

    final Rect shaderBounds = Rect.fromLTWH(
      0,
      game.size.y * 0.55,
      game.size.x,
      game.size.y * 0.45,
    );
    canvas.drawPath(
      ground,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            game.palette.ground,
            Color.lerp(game.palette.ground, game.palette.foreground, 0.75)!,
          ],
        ).createShader(shaderBounds),
    );
    canvas.drawPath(
      rim,
      Paint()
        ..color = game.palette.groundEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      rim,
      Paint()
        ..color = game.palette.groundEdge.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    _drawTrailMarks(canvas);
  }

  void _drawTrailMarks(Canvas canvas) {
    final Paint markPaint = Paint()
      ..color = game.palette.groundEdge.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    const double spacing = 86;
    final double offset = _scroll % spacing;
    for (double x = -offset; x < game.size.x + spacing; x += spacing) {
      final double y = yAt(x) + 18;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 28, yAt(x + 28) + 18),
        markPaint,
      );
    }
  }
}
