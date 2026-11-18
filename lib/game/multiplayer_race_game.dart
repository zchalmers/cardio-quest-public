import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../models/machine_models.dart';
import '../models/multiplayer_models.dart';
import '../services/multiplayer_service.dart';
import 'cardio_quest_game.dart';

class MultiplayerRaceGame extends CardioQuestGame {
  MultiplayerRaceGame({
    required super.machineService,
    required this.multiplayerService,
    required this.goalMeters,
    required void Function(GameSummary summary) onRaceFinished,
  }) : super(onComplete: onRaceFinished);

  final MultiplayerService multiplayerService;
  final double goalMeters;
  final Map<String, OpponentGhost> _ghosts = <String, OpponentGhost>{};
  final Set<String> _fadedRacers = <String>{};
  bool _raceStarted = false;

  bool get raceStarted => _raceStarted;
  double get raceProgress =>
      (distanceMeters / goalMeters).clamp(0, 1).toDouble();

  @override
  bool get continueSceneAfterFinish => true;

  void startRace() {
    _raceStarted = true;
  }

  @override
  void update(double dt) {
    _syncGhosts();
    if (!_raceStarted) {
      super.update(0);
      return;
    }
    super.update(dt);
    if (!isFinished && distanceMeters >= goalMeters) {
      distanceMeters = math.max(distanceMeters, goalMeters);
      finishWorkout(pauseAfter: false);
    }
  }

  void _syncGhosts() {
    final Set<String> currentIds = <String>{};
    for (final MultiplayerRacer racer in multiplayerService.opponents) {
      currentIds.add(racer.id);
      final bool telemetryFresh =
          DateTime.now().difference(racer.lastTelemetryAt) <
          const Duration(seconds: 3);
      if (racer.connected && telemetryFresh) {
        _fadedRacers.remove(racer.id);
      }
      if (!_ghosts.containsKey(racer.id) && !_fadedRacers.contains(racer.id)) {
        final OpponentGhost ghost = OpponentGhost(
          racerId: racer.id,
          multiplayerService: multiplayerService,
          onFaded: _retireGhost,
        );
        _ghosts[racer.id] = ghost;
        add(ghost);
      }
    }
    for (final String id in _ghosts.keys.toList(growable: false)) {
      if (!currentIds.contains(id)) {
        _ghosts[id]?.beginFade();
      }
    }
  }

  void _retireGhost(String racerId) {
    _ghosts.remove(racerId);
    _fadedRacers.add(racerId);
  }
}

class OpponentGhost extends PositionComponent
    with HasGameReference<MultiplayerRaceGame> {
  OpponentGhost({
    required this.racerId,
    required this.multiplayerService,
    required this.onFaded,
  }) : super(size: Vector2(68, 94), anchor: Anchor.bottomCenter, priority: 24);

  final String racerId;
  final MultiplayerService multiplayerService;
  final void Function(String racerId) onFaded;

  double _opacity = 0;
  double _animationClock = 0;
  bool _forceFade = false;

  MultiplayerRacer? get _racer {
    for (final MultiplayerRacer racer in multiplayerService.opponents) {
      if (racer.id == racerId) {
        return racer;
      }
    }
    return null;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    position = Vector2(
      game.size.x * GameConstants.playerScreenX,
      game.terrain.yAt(game.size.x * GameConstants.playerScreenX),
    );
  }

  void beginFade() {
    _forceFade = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final MultiplayerRacer? racer = _racer;
    final bool telemetryFresh =
        racer != null &&
        DateTime.now().difference(racer.lastTelemetryAt) <
            const Duration(seconds: 3);
    final bool visible =
        !_forceFade && racer != null && racer.connected && telemetryFresh;
    final double targetOpacity = visible ? 0.58 : 0;
    _opacity = ui.lerpDouble(
      _opacity,
      targetOpacity,
      1 - math.exp(-dt * (visible ? 5 : 2.2)),
    )!;

    if (racer != null) {
      final double gapMeters = racer.distanceMeters - game.distanceMeters;
      final double targetX =
          game.size.x * GameConstants.playerScreenX + gapMeters * 7.5;
      final double maximumX = math.max(34, game.size.x - 34);
      position.x = ui.lerpDouble(
        position.x,
        targetX.clamp(34, maximumX).toDouble(),
        1 - math.exp(-dt * 7),
      )!;
      position.y = ui.lerpDouble(
        position.y,
        game.terrain.yAt(position.x),
        1 - math.exp(-dt * 10),
      )!;
      _animationClock +=
          dt * (4.5 + racer.speedKph.clamp(0, 24).toDouble() * 0.55);
    }

    if (!visible && _opacity < 0.012) {
      onFaded(racerId);
      removeFromParent();
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final MultiplayerRacer? racer = _racer;
    if (racer == null || _opacity <= 0.01) {
      return;
    }
    final Color ghostColor = AppColors.lavender.withValues(alpha: _opacity);
    final Color glowColor = AppColors.mint.withValues(alpha: _opacity * 0.28);
    final double stride = math.sin(_animationClock) * 13;

    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(size.x * 0.5, size.y - 3),
        width: 54,
        height: 11,
      ),
      ui.Paint()
        ..color = glowColor
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );

    final ui.Paint limbPaint = ui.Paint()
      ..color = ghostColor
      ..strokeWidth = 7
      ..strokeCap = ui.StrokeCap.round;
    final ui.Offset hip = ui.Offset(size.x * 0.5, 55);
    final ui.Offset shoulder = ui.Offset(size.x * 0.5, 31);
    canvas
      ..drawLine(
        hip,
        ui.Offset(hip.dx + stride, 86 - math.max(0, stride) * 0.18),
        limbPaint,
      )
      ..drawLine(
        hip,
        ui.Offset(hip.dx - stride, 86 - math.max(0, -stride) * 0.18),
        limbPaint,
      )
      ..drawLine(shoulder, ui.Offset(shoulder.dx - stride * 0.7, 53), limbPaint)
      ..drawLine(
        shoulder,
        ui.Offset(shoulder.dx + stride * 0.7, 53),
        limbPaint,
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromCenter(
          center: ui.Offset(size.x * 0.5, 43),
          width: 25,
          height: 35,
        ),
        const ui.Radius.circular(10),
      ),
      ui.Paint()..color = ghostColor,
    );
    canvas.drawCircle(
      ui.Offset(size.x * 0.5, 17),
      11,
      ui.Paint()..color = ghostColor,
    );

    _drawLabel(canvas, racer);
  }

  void _drawLabel(ui.Canvas canvas, MultiplayerRacer racer) {
    final String status = racer.finished
        ? '#${racer.finishPlace ?? '—'} • FINISHED'
        : '${racer.speedKph.toStringAsFixed(1)} km/h • '
              '${racer.distanceMeters.round()} m';
    final TextPainter namePainter = TextPainter(
      text: TextSpan(
        text: racer.name,
        style: TextStyle(
          color: Colors.white.withValues(alpha: _opacity.clamp(0.2, 1)),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final TextPainter statPainter = TextPainter(
      text: TextSpan(
        text: status,
        style: TextStyle(
          color: AppColors.mint.withValues(alpha: _opacity.clamp(0.2, 1)),
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double width = math.max(namePainter.width, statPainter.width) + 16;
    final ui.Rect bubble = ui.Rect.fromLTWH(
      size.x * 0.5 - width * 0.5,
      -24,
      width,
      31,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(bubble, const ui.Radius.circular(9)),
      ui.Paint()..color = AppColors.ink.withValues(alpha: _opacity * 0.9),
    );
    namePainter.paint(
      canvas,
      ui.Offset(size.x * 0.5 - namePainter.width * 0.5, -21),
    );
    statPainter.paint(
      canvas,
      ui.Offset(size.x * 0.5 - statPainter.width * 0.5, -8),
    );
  }
}
