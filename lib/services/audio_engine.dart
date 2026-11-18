import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../models/machine_models.dart';
import 'adaptive_music.dart';
import 'sound_design.dart';

/// Low-latency game audio facade used by Flame components and workout events.
class AudioEngine {
  AudioEngine._();

  static final AudioEngine instance = AudioEngine._();

  final SoundDesign _soundDesign = SoundDesign.instance;
  final AdaptiveMusic adaptiveMusic = AdaptiveMusic.instance;
  final math.Random _random = math.Random();
  final Set<int> _playedComboMilestones = <int>{};

  bool _sessionActive = false;
  bool _paused = false;
  int _sessionGeneration = 0;
  bool _leftFoot = false;

  bool get isSessionActive => _sessionActive;

  Future<void> initialize() async {
    await _soundDesign.initialize();
    await adaptiveMusic.initialize();
  }

  Future<void> startWorkout() async {
    _sessionActive = true;
    _paused = false;
    _playedComboMilestones.clear();
    ++_sessionGeneration;
    await initialize();
    if (_sessionActive) {
      await adaptiveMusic.start();
    }
  }

  void updateMusic({
    required double dt,
    required double speedKph,
    required double cadenceRpm,
    required HeartRateZone heartRateZone,
  }) {
    if (!_sessionActive || _paused) {
      return;
    }
    adaptiveMusic.update(
      dt: dt,
      speedKph: speedKph,
      cadenceRpm: cadenceRpm,
      heartRateZone: heartRateZone,
    );
  }

  void playFootstep(MotionMode mode, {required double cadenceRpm}) {
    _leftFoot = !_leftFoot;
    final double cadencePitch = (1 + (cadenceRpm - 140) / 1100)
        .clamp(0.94, 1.08)
        .toDouble();
    unawaited(
      _play(
        _soundDesign.loadFootstep(mode),
        volume: 0.34,
        pan: _leftFoot ? -0.12 : 0.12,
        pitch: cadencePitch * _soundDesign.variedPitch(_random, amount: 0.035),
      ),
    );
  }

  void playCoinPickup() {
    unawaited(
      _play(
        _soundDesign.loadCoin(),
        volume: 0.68,
        pan: (_random.nextDouble() * 0.24) - 0.12,
        pitch: _soundDesign.variedPitch(_random, amount: 0.025),
      ),
    );
  }

  void playJump() {
    unawaited(_play(_soundDesign.loadJump(), volume: 0.52));
  }

  void playObstacleHit({required bool shielded}) {
    unawaited(
      _play(
        _soundDesign.loadObstacleHit(shielded: shielded),
        volume: shielded ? 0.72 : 0.86,
        pitch: _soundDesign.variedPitch(_random, amount: 0.022),
      ),
    );
  }

  void playPowerUp(PowerUpType type) {
    unawaited(_play(_soundDesign.loadPowerUp(type), volume: 0.72));
  }

  void playSpeedTransition({required bool speedingUp}) {
    unawaited(
      _play(
        _soundDesign.loadSpeedTransition(speedingUp: speedingUp),
        volume: 0.48,
      ),
    );
  }

  void playZoneTransition(HeartRateZone zone) {
    if (zone == HeartRateZone.unknown) {
      return;
    }
    unawaited(_play(_soundDesign.loadZoneTransition(zone), volume: 0.4));
  }

  void playComboMilestone(double combo) {
    const List<int> milestones = <int>[2, 3, 5, 10];
    for (final int milestone in milestones) {
      if (combo >= milestone && _playedComboMilestones.add(milestone)) {
        unawaited(
          _play(
            _soundDesign.loadComboMilestone(milestone),
            volume: milestone >= 5 ? 0.82 : 0.66,
          ),
        );
      }
    }
  }

  Future<void> _play(
    Future<AudioSource?> sourceFuture, {
    required double volume,
    double pan = 0,
    double pitch = 1,
  }) async {
    if (!_sessionActive ||
        _paused ||
        _soundDesign.volumeFor(AudioBus.sfx) <= 0) {
      return;
    }
    final int generation = _sessionGeneration;
    final AudioSource? source = await sourceFuture;
    if (source == null ||
        !_sessionActive ||
        _paused ||
        generation != _sessionGeneration ||
        !_soundDesign.audioAvailable) {
      return;
    }
    try {
      final SoundHandle handle = await SoLoud.instance.play(
        source,
        volume: volume * _soundDesign.volumeFor(AudioBus.sfx),
        pan: pan,
      );
      if ((pitch - 1).abs() > 0.001) {
        SoLoud.instance.setRelativePlaySpeed(handle, pitch);
      }
    } on Object catch (error) {
      debugPrint('Could not play procedural SFX: $error');
    }
  }

  void pauseWorkout() {
    if (!_sessionActive || _paused) {
      return;
    }
    _paused = true;
    adaptiveMusic.pause();
  }

  void resumeWorkout() {
    if (!_sessionActive || !_paused) {
      return;
    }
    _paused = false;
    adaptiveMusic.resume();
  }

  void endWorkout() {
    if (!_sessionActive) {
      return;
    }
    _sessionActive = false;
    _paused = false;
    ++_sessionGeneration;
    unawaited(adaptiveMusic.stop());
  }

  Future<void> shutdown() async {
    _sessionActive = false;
    ++_sessionGeneration;
    await adaptiveMusic.shutdown();
    await _soundDesign.shutdown();
  }
}
