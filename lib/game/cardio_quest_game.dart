import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../models/machine_models.dart';
import '../services/audio_engine.dart';
import '../services/challenge_service.dart';
import '../services/cosmetics_service.dart';
import '../services/machine_service.dart';
import '../services/player_profile.dart';
import '../services/voice_coach.dart';
import 'components/coins.dart';
import 'components/hud.dart';
import 'components/obstacles.dart';
import 'components/parallax_background.dart';
import 'components/particles.dart';
import 'components/player.dart';
import 'components/terrain.dart';

class CardioQuestGame extends FlameGame {
  CardioQuestGame({
    required this.machineService,
    required this.onComplete,
    AudioEngine? audioEngine,
    VoiceCoach? voiceCoach,
    ChallengeService? challengeService,
    CosmeticsService? cosmeticsService,
  }) : audioEngine = audioEngine ?? AudioEngine.instance,
       voiceCoach = voiceCoach ?? VoiceCoach.instance,
       challengeService = challengeService ?? ChallengeService.instance,
       cosmeticsService = cosmeticsService ?? CosmeticsService.instance;

  final MachineService machineService;
  final void Function(GameSummary summary) onComplete;
  final AudioEngine audioEngine;
  final VoiceCoach voiceCoach;
  final ChallengeService challengeService;
  final CosmeticsService cosmeticsService;
  final math.Random _random = math.Random();

  late final TerrainComponent terrain;
  late final RunnerPlayer player;
  late final JuiceParticles particles;

  double smoothedSpeedKph = 0;
  double distanceMeters = 0;
  double combo = 1;
  double maxCombo = 1;
  int coins = 0;
  int obstaclesCleared = 0;

  double magnetRemaining = 0;
  double shieldRemaining = 0;
  double doubleCoinsRemaining = 0;

  double _activeSeconds = 0;
  double _maxSpeedKph = 0;
  double _stableTimer = 0;
  double _stableAnchorSpeed = 0;
  double _coinSpawnTimer = 0.35;
  double _obstacleSpawnTimer = 3.8;
  double _powerUpSpawnTimer = 11;
  double _impactSlowdown = 0;
  bool _finished = false;
  bool _audioSessionStarted = false;
  MotionMode _lastMotionMode = MotionMode.walk;
  HeartRateZone _lastHeartRateZone = HeartRateZone.unknown;

  MachineMetrics get machineMetrics => machineService.metrics;
  MotionMode get motionMode => motionModeFor(smoothedSpeedKph);
  double get normalizedSpeed => GameConstants.normalizedSpeed(smoothedSpeedKph);
  RunPalette get palette => RunPalette.forSpeed(normalizedSpeed);
  double get worldSpeed =>
      GameConstants.worldSpeedFor(smoothedSpeedKph) *
      (1 - _impactSlowdown * 0.52);
  bool get magnetActive => magnetRemaining > 0;
  bool get shieldActive => shieldRemaining > 0;
  bool get doubleCoinsActive => doubleCoinsRemaining > 0;
  bool get isFinished => _finished;
  bool get continueSceneAfterFinish => false;
  int get score => (distanceMeters * combo * coins).round();
  double get comboProgress =>
      (_stableTimer / GameConstants.comboBuildSeconds).clamp(0, 1).toDouble();

  String get paceLabel {
    if (smoothedSpeedKph < 0.2) {
      return '--:--';
    }
    final double minutes = 60 / smoothedSpeedKph;
    final int wholeMinutes = minutes.floor();
    final int seconds = ((minutes - wholeMinutes) * 60)
        .round()
        .clamp(0, 59)
        .toInt();
    return '$wholeMinutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Color backgroundColor() => AppColors.ink;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    terrain = TerrainComponent();
    particles = JuiceParticles();
    player = RunnerPlayer();
    await addAll(<Component>[
      ParallaxBackgroundComponent(),
      terrain,
      player,
      particles,
      ForegroundParallaxComponent(),
      HudComponent(),
    ]);
  }

  @override
  void update(double dt) {
    if (_finished) {
      if (continueSceneAfterFinish) {
        super.update(dt);
      }
      return;
    }
    if (!_audioSessionStarted &&
        dt > 0 &&
        machineService.state == WorkoutState.running) {
      _audioSessionStarted = true;
      unawaited(audioEngine.startWorkout());
      voiceCoach.startWorkout();
    }
    final MachineMetrics latest = machineMetrics;
    final bool metricsAvailable = latest.isSimulated || latest.isFresh;
    final double targetSpeed = metricsAvailable ? latest.speedKph : 0;
    smoothedSpeedKph +=
        (targetSpeed - smoothedSpeedKph) * (1 - math.exp(-dt * 4.8));
    if (smoothedSpeedKph < 0.02) {
      smoothedSpeedKph = 0;
    }

    _activeSeconds += dt;
    _maxSpeedKph = math.max(_maxSpeedKph, targetSpeed);
    distanceMeters += smoothedSpeedKph / 3.6 * dt;
    _impactSlowdown = math.max(0.0, _impactSlowdown - dt * 1.4);

    _updateCombo(dt, targetSpeed);
    _updatePowerUps(dt);
    _updateSpawning(dt);
    _updateAudio(dt, latest);
    challengeService.trackGameplay(
      ChallengeWorkoutSnapshot(
        distanceMeters: distanceMeters,
        maxSpeedKph: _maxSpeedKph,
        coins: coins,
        maxCombo: maxCombo,
        zoneDurations: machineService.heartRateZoneDurations,
        currentStreak: PlayerProfile.instance.currentStreak,
      ),
    );
    super.update(dt);
  }

  void _updateAudio(double dt, MachineMetrics metrics) {
    final MotionMode currentMode = motionMode;
    if (currentMode != _lastMotionMode && smoothedSpeedKph > 0.5) {
      audioEngine.playSpeedTransition(
        speedingUp:
            MotionMode.values.indexOf(currentMode) >
            MotionMode.values.indexOf(_lastMotionMode),
      );
      _lastMotionMode = currentMode;
    }

    final HeartRateZone currentZone =
        machineService.heartRateZoneEngine.currentZone;
    if (currentZone != _lastHeartRateZone) {
      _lastHeartRateZone = currentZone;
      if (currentZone != HeartRateZone.unknown) {
        audioEngine.playZoneTransition(currentZone);
        voiceCoach.announceZoneChange(
          currentZone,
          activeSeconds: _activeSeconds,
        );
      }
    }

    audioEngine.updateMusic(
      dt: dt,
      speedKph: smoothedSpeedKph,
      cadenceRpm: metrics.cadenceRpm,
      heartRateZone: currentZone,
    );
    voiceCoach.update(
      activeSeconds: _activeSeconds,
      distanceMeters: distanceMeters,
      speedKph: smoothedSpeedKph,
      heartRateBpm: metrics.heartRateBpm,
      estimatedMaxHeartRate:
          machineService.heartRateZoneEngine.estimatedMaxHeartRate,
      heartRateZone: currentZone,
    );
  }

  void jump() {
    if (!_finished && !paused) {
      player.jump();
    }
  }

  void pauseWorkout() {
    if (_finished || paused) {
      return;
    }
    machineService.pauseWorkout();
    audioEngine.pauseWorkout();
    voiceCoach.pauseWorkout();
    pauseEngine();
  }

  void resumeWorkout() {
    if (_finished || !paused) {
      return;
    }
    machineService.resumeWorkout();
    audioEngine.resumeWorkout();
    voiceCoach.resumeWorkout(_activeSeconds);
    resumeEngine();
  }

  void finishWorkout({bool pauseAfter = true}) {
    if (_finished) {
      return;
    }
    _finished = true;
    machineService.completeWorkout();
    voiceCoach.finishWorkout(
      distanceMeters: distanceMeters,
      activeSeconds: _activeSeconds,
    );
    audioEngine.endWorkout();
    final GameSummary summary = buildSummary();
    if (pauseAfter) {
      pauseEngine();
    }
    onComplete(summary);
  }

  GameSummary buildSummary() {
    final double averageSpeed = _activeSeconds <= 0
        ? 0
        : distanceMeters / _activeSeconds * 3.6;
    final Duration duration = Duration(
      milliseconds: (_activeSeconds * 1000).round(),
    );
    return GameSummary(
      duration: duration,
      distanceMeters: distanceMeters,
      averageSpeedKph: averageSpeed,
      maxSpeedKph: _maxSpeedKph,
      coins: coins,
      score: score,
      maxCombo: maxCombo,
      obstaclesCleared: obstaclesCleared,
      averageHeartRateBpm: machineService.averageHeartRateBpm,
      maxHeartRateBpm: machineService.maximumHeartRateBpm,
      restingHeartRateBpm: machineService.restingHeartRateBpm,
      activeEnergyCalories: machineService.workoutActiveEnergyCalories,
      workoutStepCount: machineService.workoutStepCount,
      heartRateZoneDurations: machineService.heartRateZoneDurations,
      heartRateVariability: machineService.heartRateVariability,
      heartRateRecovery: machineService.heartRateRecovery,
      usedWearableData: machineService.usedWearableData,
      wearableHeartRateSampleCount: machineService.wearableHeartRateSampleCount,
      metricSamples: _normalizedWorkoutSamples(
        machineService.workoutSamples,
        duration,
      ),
    );
  }

  List<WorkoutMetricSample> _normalizedWorkoutSamples(
    List<WorkoutMetricSample> samples,
    Duration duration,
  ) {
    if (samples.isEmpty) {
      return const <WorkoutMetricSample>[];
    }
    final double sampledDistance = samples.last.distanceMeters;
    return samples
        .map((WorkoutMetricSample sample) {
          final double normalizedDistance;
          if (sampledDistance > 0) {
            normalizedDistance =
                sample.distanceMeters / sampledDistance * distanceMeters;
          } else if (duration.inMilliseconds > 0) {
            normalizedDistance =
                sample.elapsed.inMilliseconds /
                duration.inMilliseconds *
                distanceMeters;
          } else {
            normalizedDistance = 0;
          }
          return WorkoutMetricSample(
            recordedAt: sample.recordedAt,
            elapsed: sample.elapsed,
            speedKph: sample.speedKph,
            inclinePercent: sample.inclinePercent,
            distanceMeters: normalizedDistance
                .clamp(0, distanceMeters)
                .toDouble(),
            heartRateBpm: sample.heartRateBpm,
            heartRateSource: sample.heartRateSource,
            activeEnergyCalories: sample.activeEnergyCalories,
          );
        })
        .toList(growable: false);
  }

  void collectCoin(Vector2 origin) {
    final int value = doubleCoinsActive ? 2 : 1;
    coins += value;
    audioEngine.playCoinPickup();
    particles.coinSparkle(origin, doubled: doubleCoinsActive);
  }

  void activatePowerUp(PowerUpType type, Vector2 origin) {
    switch (type) {
      case PowerUpType.magnet:
        magnetRemaining = math.max(magnetRemaining, 8.0);
      case PowerUpType.shield:
        shieldRemaining = math.max(shieldRemaining, 10.0);
      case PowerUpType.doubleCoins:
        doubleCoinsRemaining = math.max(doubleCoinsRemaining, 9.0);
    }
    audioEngine.playPowerUp(type);
    particles.powerUpBurst(origin, type);
  }

  void hitObstacle(Vector2 origin) {
    final bool shielded = shieldActive;
    if (shielded) {
      shieldRemaining = 0;
    } else {
      combo = 1;
      _stableTimer = 0;
      _impactSlowdown = 1;
    }
    audioEngine.playObstacleHit(shielded: shielded);
    particles.obstacleImpact(origin, shielded: shielded);
  }

  void clearObstacle() {
    obstaclesCleared++;
    _stableTimer += 0.45;
  }

  void _updatePowerUps(double dt) {
    magnetRemaining = math.max(0.0, magnetRemaining - dt);
    shieldRemaining = math.max(0.0, shieldRemaining - dt);
    doubleCoinsRemaining = math.max(0.0, doubleCoinsRemaining - dt);
  }

  void _updateCombo(double dt, double targetSpeed) {
    final double previousCombo = combo;
    if (targetSpeed < 1) {
      _stableTimer = math.max(0.0, _stableTimer - dt * 0.7);
      combo = math.max(1.0, combo - dt * 0.18);
      _stableAnchorSpeed = targetSpeed;
      return;
    }
    final double deviation = (targetSpeed - _stableAnchorSpeed).abs();
    if (deviation <= GameConstants.comboToleranceKph) {
      _stableTimer += dt;
      if (_stableTimer >= GameConstants.comboBuildSeconds) {
        _stableTimer -= GameConstants.comboBuildSeconds;
        combo = math.min(GameConstants.maximumCombo, combo + 0.5);
        maxCombo = math.max(maxCombo, combo);
      }
    } else {
      _stableTimer = math.max(0.0, _stableTimer - dt * 2.4);
      combo = math.max(1.0, combo - dt * 0.38);
      _stableAnchorSpeed +=
          (targetSpeed - _stableAnchorSpeed) * (1 - math.exp(-dt * 1.1));
    }
    if (combo > previousCombo) {
      audioEngine.playComboMilestone(combo);
    }
  }

  @override
  void onRemove() {
    if (!_finished) {
      audioEngine.endWorkout();
      voiceCoach.cancelWorkout();
    }
    super.onRemove();
  }

  void _updateSpawning(double dt) {
    if (worldSpeed <= 0 || size.x <= 0) {
      return;
    }
    _coinSpawnTimer -= dt;
    _obstacleSpawnTimer -= dt;
    _powerUpSpawnTimer -= dt;

    if (_coinSpawnTimer <= 0) {
      _spawnCoinTrail();
      _coinSpawnTimer = 2.1 - normalizedSpeed * 0.55 + _random.nextDouble();
    }
    if (_obstacleSpawnTimer <= 0 && smoothedSpeedKph > 1.2) {
      final ObstacleStyle style =
          ObstacleStyle.values[_random.nextInt(ObstacleStyle.values.length)];
      add(
        ObstacleComponent(
          x: size.x + 90 + _random.nextDouble() * 80,
          style: style,
        ),
      );
      _obstacleSpawnTimer =
          3.7 - normalizedSpeed * 1.15 + _random.nextDouble() * 1.6;
    }
    if (_powerUpSpawnTimer <= 0) {
      final PowerUpType type =
          PowerUpType.values[_random.nextInt(PowerUpType.values.length)];
      add(
        PowerUpComponent(
          x: size.x + 120,
          type: type,
          heightAboveGround: 82 + _random.nextDouble() * 38,
        ),
      );
      _powerUpSpawnTimer = 10 + _random.nextDouble() * 7;
    }
  }

  void _spawnCoinTrail() {
    final int count = 5 + _random.nextInt(4);
    final double baseHeight = 58 + _random.nextDouble() * 32;
    final double arcHeight = 35 + _random.nextDouble() * 42;
    for (int i = 0; i < count; i++) {
      final double progress = count <= 1 ? 0 : i / (count - 1);
      final double height =
          baseHeight + math.sin(progress * math.pi) * arcHeight;
      add(
        CoinComponent(
          x: size.x + 50 + i * 48,
          heightAboveGround: height,
          phase: i * 0.6,
        ),
      );
    }
  }
}
