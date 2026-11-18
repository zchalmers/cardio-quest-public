import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Alignment, LinearGradient;

import '../../core/palette.dart';
import '../cardio_quest_game.dart';

class ParallaxBackgroundComponent extends Component
    with HasGameReference<CardioQuestGame> {
  ParallaxBackgroundComponent() : super(priority: -100);

  double _farOffset = 0;
  double _nearOffset = 0;
  double _treeOffset = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _farOffset = (_farOffset + game.worldSpeed * dt * 0.045) % 900;
    _nearOffset = (_nearOffset + game.worldSpeed * dt * 0.1) % 700;
    _treeOffset = (_treeOffset + game.worldSpeed * dt * 0.22) % 180;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final Size viewport = Size(game.size.x, game.size.y);
    if (viewport.isEmpty) {
      return;
    }
    final RunPalette palette = game.palette;
    final Rect bounds = Offset.zero & viewport;
    final String themeId = game.cosmeticsService.backgroundTheme.id;
    final (Color, Color) sky = _skyColors(themeId, palette);

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[sky.$1, sky.$2],
        ).createShader(bounds),
    );

    _drawAtmosphere(canvas, viewport, palette, themeId);
    _drawMountainBand(
      canvas,
      viewport,
      baseY: viewport.height * 0.52,
      amplitude: viewport.height * 0.2,
      width: 340,
      offset: _farOffset,
      color: palette.mountainFar,
    );
    _drawMountainBand(
      canvas,
      viewport,
      baseY: viewport.height * 0.64,
      amplitude: viewport.height * 0.22,
      width: 260,
      offset: _nearOffset,
      color: palette.mountainNear,
    );
    _drawThemeDetails(canvas, viewport, themeId);
    _drawTreeBand(canvas, viewport, palette);
  }

  (Color, Color) _skyColors(String themeId, RunPalette palette) {
    return switch (themeId) {
      'background_night' => (const Color(0xFF050B22), const Color(0xFF242454)),
      'background_snow' => (const Color(0xFF82ADCC), const Color(0xFFD9EFF7)),
      'background_desert' => (const Color(0xFF813A35), const Color(0xFFFFB968)),
      'background_cyberpunk' => (
        const Color(0xFF06051D),
        const Color(0xFF28104E),
      ),
      'background_aurora' => (const Color(0xFF031221), const Color(0xFF123C43)),
      _ => (palette.skyTop, palette.skyBottom),
    };
  }

  void _drawAtmosphere(
    Canvas canvas,
    Size viewport,
    RunPalette palette,
    String themeId,
  ) {
    final double speed = game.normalizedSpeed;
    final Offset sunCenter = Offset(
      viewport.width * (0.76 - speed * 0.05),
      viewport.height * 0.22,
    );
    final bool night =
        themeId == 'background_night' ||
        themeId == 'background_cyberpunk' ||
        themeId == 'background_aurora';
    final Color celestial = night ? const Color(0xFFDDE8FF) : palette.sun;
    canvas.drawCircle(
      sunCenter,
      viewport.shortestSide * 0.09,
      Paint()
        ..color = celestial.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawCircle(
      sunCenter,
      viewport.shortestSide * 0.052,
      Paint()..color = celestial.withValues(alpha: 0.92),
    );

    final Paint haze = Paint()
      ..color = celestial.withValues(alpha: night ? 0.5 : 0.18)
      ..strokeWidth = 1;
    for (int i = 0; i < 18; i++) {
      final double x = (i * 149.0 + _farOffset * 0.25) % viewport.width;
      final double y = 18 + (math.sin(i * 13.7) + 1) * viewport.height * 0.16;
      final double radius = 0.8 + (i % 3) * 0.5;
      canvas.drawCircle(Offset(x, y), radius, haze);
    }
  }

  void _drawThemeDetails(Canvas canvas, Size viewport, String themeId) {
    switch (themeId) {
      case 'background_snow':
        final Paint snow = Paint()..color = const Color(0xBFFFFFFF);
        for (int i = 0; i < 32; i++) {
          final double x = (i * 83.0 - _farOffset * 0.35) % viewport.width;
          final double y = (i * 47.0 + _nearOffset * 0.2) % viewport.height;
          canvas.drawCircle(Offset(x, y), 1.2 + i % 3, snow);
        }
      case 'background_desert':
        final Paint dune = Paint()..color = const Color(0x88CF7546);
        final Path path = Path()
          ..moveTo(0, viewport.height * 0.72)
          ..quadraticBezierTo(
            viewport.width * 0.25,
            viewport.height * 0.57,
            viewport.width * 0.5,
            viewport.height * 0.72,
          )
          ..quadraticBezierTo(
            viewport.width * 0.78,
            viewport.height * 0.58,
            viewport.width,
            viewport.height * 0.7,
          )
          ..lineTo(viewport.width, viewport.height)
          ..lineTo(0, viewport.height)
          ..close();
        canvas.drawPath(path, dune);
      case 'background_cyberpunk':
        final Paint neon = Paint()
          ..color = const Color(0x66FF4FD8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final double horizon = viewport.height * 0.66;
        for (double x = 0; x < viewport.width; x += 54) {
          final double height = 30 + ((x / 54).round() % 5) * 13;
          canvas.drawRect(Rect.fromLTWH(x, horizon - height, 38, height), neon);
        }
        for (int i = 0; i < 8; i++) {
          canvas.drawLine(
            Offset(viewport.width * 0.5, horizon),
            Offset(i * viewport.width / 7, viewport.height),
            neon,
          );
        }
      case 'background_aurora':
        for (int i = 0; i < 4; i++) {
          final Path ribbon = Path()
            ..moveTo(-40, viewport.height * (0.12 + i * 0.05));
          for (double x = 0; x <= viewport.width + 80; x += 80) {
            ribbon.lineTo(
              x,
              viewport.height * (0.15 + i * 0.055) +
                  math.sin(x * 0.012 + _farOffset * 0.006 + i) * 36,
            );
          }
          canvas.drawPath(
            ribbon,
            Paint()
              ..color = Color.lerp(
                const Color(0xFF58F2B5),
                const Color(0xFF8C67FF),
                i / 3,
              )!.withValues(alpha: 0.19)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 20
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
        }
    }
  }

  void _drawMountainBand(
    Canvas canvas,
    Size viewport, {
    required double baseY,
    required double amplitude,
    required double width,
    required double offset,
    required Color color,
  }) {
    final Path path = Path()..moveTo(0, baseY);
    final double start = -(offset % width) - width;
    for (double x = start; x < viewport.width + width; x += width) {
      path
        ..lineTo(x + width * 0.24, baseY - amplitude * 0.45)
        ..quadraticBezierTo(
          x + width * 0.42,
          baseY - amplitude * 1.1,
          x + width * 0.56,
          baseY - amplitude * 0.66,
        )
        ..lineTo(x + width * 0.73, baseY - amplitude * 0.88)
        ..lineTo(x + width, baseY);
    }
    path
      ..lineTo(viewport.width, viewport.height)
      ..lineTo(0, viewport.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);

    final Path rim = Path()
      ..moveTo(start + width * 0.28, baseY - amplitude * 0.5);
    for (double x = start; x < viewport.width + width; x += width) {
      rim
        ..moveTo(x + width * 0.28, baseY - amplitude * 0.5)
        ..lineTo(x + width * 0.42, baseY - amplitude * 1.04)
        ..lineTo(x + width * 0.5, baseY - amplitude * 0.79);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..color = paletteHighlight(color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Color paletteHighlight(Color color) {
    return Color.lerp(
      color,
      const Color(0xFFFFFFFF),
      0.12,
    )!.withValues(alpha: 0.38);
  }

  void _drawTreeBand(Canvas canvas, Size viewport, RunPalette palette) {
    final double baseY = viewport.height * 0.79;
    final Paint trunkPaint = Paint()
      ..color = Color.lerp(palette.trees, const Color(0xFF050B13), 0.35)!;
    final Paint crownPaint = Paint()..color = palette.trees;
    const double spacing = 58;
    final double start = -(_treeOffset % spacing) - spacing;

    for (double x = start; x < viewport.width + spacing; x += spacing) {
      final int index = ((x + _treeOffset) / spacing).round();
      final double scale = 0.78 + ((index.abs() * 37) % 28) / 100;
      final double height = 80 * scale;
      canvas.drawRect(
        Rect.fromLTWH(x + 24, baseY - height * 0.28, 7, height * 0.3),
        trunkPaint,
      );
      for (int tier = 0; tier < 3; tier++) {
        final double tierY = baseY - height + tier * height * 0.22;
        final double halfWidth = (26 - tier * 3) * scale;
        final Path crown = Path()
          ..moveTo(x + 27, tierY)
          ..lineTo(x + 27 - halfWidth, tierY + height * 0.42)
          ..lineTo(x + 27 + halfWidth, tierY + height * 0.42)
          ..close();
        canvas.drawPath(crown, crownPaint);
      }
    }
  }
}

class ForegroundParallaxComponent extends Component
    with HasGameReference<CardioQuestGame> {
  ForegroundParallaxComponent() : super(priority: 48);

  double _offset = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _offset = (_offset + game.worldSpeed * dt * 1.24) % 64;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.size.x <= 0 || game.size.y <= 0) {
      return;
    }
    final Paint paint = Paint()
      ..color = game.palette.foreground.withValues(alpha: 0.94)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final double bottom = game.size.y + 4;

    for (double x = -_offset; x < game.size.x + 64; x += 28) {
      final double variation = math.sin((x + _offset) * 0.21);
      final double height = 12 + (variation + 1) * 8;
      paint.strokeWidth = 3 + (variation + 1);
      canvas.drawLine(Offset(x, bottom), Offset(x - 8, bottom - height), paint);
      canvas.drawLine(
        Offset(x + 2, bottom),
        Offset(x + 12, bottom - height * 0.72),
        paint,
      );
    }
  }
}
