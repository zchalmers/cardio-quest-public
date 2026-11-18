import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../models/machine_models.dart';
import '../cardio_quest_game.dart';

class HudComponent extends Component with HasGameReference<CardioQuestGame> {
  HudComponent() : super(priority: 90);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.size.x <= 0 || game.size.y <= 0) {
      return;
    }
    final double compactScale = game.size.x < 760 ? 0.82 : 1;
    canvas.save();
    canvas.scale(compactScale);

    _drawSpeedGauge(canvas);
    _drawMetricPill(
      canvas,
      x: 202,
      width: 150,
      label: 'DISTANCE',
      value: game.distanceMeters < 1000
          ? '${game.distanceMeters.round()} m'
          : '${(game.distanceMeters / 1000).toStringAsFixed(2)} km',
      icon: Icons.route_rounded,
      color: game.palette.accent,
    );
    _drawHeartRate(canvas, x: 362);
    _drawMetricPill(
      canvas,
      x: 522,
      width: 126,
      label: 'COINS',
      value: '${game.coins}',
      icon: Icons.monetization_on_rounded,
      color: AppColors.gold,
    );
    _drawCombo(canvas, x: 658);
    canvas.restore();

    _drawPowerUps(canvas);
    _drawModeLabel(canvas);
  }

  void _drawSpeedGauge(Canvas canvas) {
    const Rect panel = Rect.fromLTWH(16, 14, 176, 92);
    _drawGlassPanel(canvas, panel);
    const Rect arcRect = Rect.fromLTWH(31, 25, 78, 70);
    const double start = math.pi * 0.82;
    const double sweep = math.pi * 1.36;
    canvas.drawArc(
      arcRect,
      start,
      sweep,
      false,
      Paint()
        ..color = const Color(0x26FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      arcRect,
      start,
      sweep * game.normalizedSpeed,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: <Color>[
            game.cosmeticsService.hudTheme.primary,
            game.palette.accentWarm,
          ],
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    _text(
      canvas,
      game.smoothedSpeedKph.toStringAsFixed(1),
      const Offset(70, 55),
      fontSize: 25,
      weight: FontWeight.w900,
      anchor: _TextAnchor.center,
    );
    _text(
      canvas,
      'KM/H',
      const Offset(70, 77),
      fontSize: 9,
      color: AppColors.textMuted,
      weight: FontWeight.w800,
      letterSpacing: 1.4,
      anchor: _TextAnchor.center,
    );
    _text(
      canvas,
      'PACE',
      const Offset(126, 34),
      fontSize: 9,
      color: AppColors.textMuted,
      weight: FontWeight.w800,
      letterSpacing: 1.2,
    );
    _text(
      canvas,
      game.paceLabel,
      const Offset(126, 53),
      fontSize: 16,
      weight: FontWeight.w800,
    );
    _text(
      canvas,
      game.motionMode.name.toUpperCase(),
      const Offset(126, 78),
      fontSize: 10,
      color: game.palette.accent,
      weight: FontWeight.w900,
      letterSpacing: 1,
    );
  }

  void _drawMetricPill(
    Canvas canvas, {
    required double x,
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final Rect panel = Rect.fromLTWH(x, 14, width, 72);
    _drawGlassPanel(canvas, panel);
    _icon(canvas, icon, Offset(x + 19, 32), 17, color);
    _text(
      canvas,
      label,
      Offset(x + 38, 25),
      fontSize: 9,
      color: AppColors.textMuted,
      weight: FontWeight.w800,
      letterSpacing: 1.1,
    );
    _text(
      canvas,
      value,
      Offset(x + 18, 49),
      fontSize: 20,
      weight: FontWeight.w900,
    );
  }

  void _drawHeartRate(Canvas canvas, {required double x}) {
    final HeartRateZone zone = heartRateZoneFor(
      game.machineMetrics.heartRateBpm,
    );
    final Color color = switch (zone) {
      HeartRateZone.recovery => AppColors.mint,
      HeartRateZone.aerobic => AppColors.success,
      HeartRateZone.tempo => AppColors.gold,
      HeartRateZone.threshold => AppColors.warning,
      HeartRateZone.peak => AppColors.danger,
      HeartRateZone.unknown => AppColors.textMuted,
    };
    _drawMetricPill(
      canvas,
      x: x,
      width: 150,
      label: zone == HeartRateZone.unknown
          ? 'HEART RATE'
          : zone.name.toUpperCase(),
      value: game.machineMetrics.heartRateBpm <= 0
          ? '-- bpm'
          : '${game.machineMetrics.heartRateBpm} bpm',
      icon: Icons.favorite_rounded,
      color: color,
    );
  }

  void _drawCombo(Canvas canvas, {required double x}) {
    final double availableWidth =
        game.size.x / (game.size.x < 760 ? 0.82 : 1) - x - 78;
    final double width = availableWidth.clamp(112, 154).toDouble();
    final Rect panel = Rect.fromLTWH(x, 14, width, 72);
    _drawGlassPanel(canvas, panel);
    _text(
      canvas,
      'COMBO',
      Offset(x + 16, 26),
      fontSize: 9,
      color: AppColors.textMuted,
      weight: FontWeight.w800,
      letterSpacing: 1.1,
    );
    _text(
      canvas,
      '×${game.combo.toStringAsFixed(1)}',
      Offset(x + 16, 45),
      fontSize: 24,
      color: game.combo > 2 ? game.palette.accentWarm : AppColors.text,
      weight: FontWeight.w900,
    );
    final Rect track = Rect.fromLTWH(x + 16, 75, width - 32, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(2)),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          track.left,
          track.top,
          track.width * game.comboProgress,
          track.height,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = game.cosmeticsService.hudTheme.primary,
    );
  }

  void _drawPowerUps(Canvas canvas) {
    final List<(PowerUpType, double)> active = <(PowerUpType, double)>[
      if (game.magnetRemaining > 0) (PowerUpType.magnet, game.magnetRemaining),
      if (game.shieldRemaining > 0) (PowerUpType.shield, game.shieldRemaining),
      if (game.doubleCoinsRemaining > 0)
        (PowerUpType.doubleCoins, game.doubleCoinsRemaining),
    ];
    double x = 18;
    final double y = game.size.y - 50;
    for (final (PowerUpType type, double remaining) in active) {
      final Color color = switch (type) {
        PowerUpType.magnet => AppColors.mint,
        PowerUpType.shield => const Color(0xFF9BB7FF),
        PowerUpType.doubleCoins => AppColors.gold,
      };
      final IconData icon = switch (type) {
        PowerUpType.magnet => Icons.u_turn_left_rounded,
        PowerUpType.shield => Icons.shield_rounded,
        PowerUpType.doubleCoins => Icons.looks_two_rounded,
      };
      final Rect pill = Rect.fromLTWH(x, y, 104, 34);
      _drawGlassPanel(canvas, pill, radius: 17);
      _icon(canvas, icon, Offset(x + 17, y + 17), 16, color);
      _text(
        canvas,
        '${remaining.ceil()}s',
        Offset(x + 35, y + 9),
        fontSize: 12,
        weight: FontWeight.w900,
      );
      x += 112;
    }
  }

  void _drawModeLabel(Canvas canvas) {
    if (game.smoothedSpeedKph > 0.25) {
      return;
    }
    final Offset center = Offset(game.size.x * 0.5, game.size.y * 0.34);
    _text(
      canvas,
      'START MOVING',
      center,
      fontSize: 22,
      color: AppColors.text.withValues(alpha: 0.88),
      weight: FontWeight.w900,
      letterSpacing: 3,
      anchor: _TextAnchor.center,
    );
    _text(
      canvas,
      'Your machine speed powers the trail',
      center + const Offset(0, 30),
      fontSize: 12,
      color: AppColors.textMuted,
      weight: FontWeight.w600,
      anchor: _TextAnchor.center,
    );
  }

  void _drawGlassPanel(Canvas canvas, Rect rect, {double radius = 18}) {
    final RRect panel = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      panel,
      Paint()
        ..color = game.cosmeticsService.hudTheme.secondary
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..color = const Color(0x2AFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _icon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset position, {
    required double fontSize,
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 0,
    _TextAnchor anchor = _TextAnchor.topLeft,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset paintAt = switch (anchor) {
      _TextAnchor.topLeft => position,
      _TextAnchor.center =>
        position - Offset(painter.width / 2, painter.height / 2),
    };
    painter.paint(canvas, paintAt);
  }
}

enum _TextAnchor { topLeft, center }
