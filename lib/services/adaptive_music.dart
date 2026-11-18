import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../core/constants.dart';
import '../models/machine_models.dart';
import 'sound_design.dart';

/// Four synchronized procedural loops whose mix follows workout intensity.
class AdaptiveMusic {
  AdaptiveMusic._() {
    _soundDesign.addListener(_handleSettingsChanged);
  }

  static final AdaptiveMusic instance = AdaptiveMusic._();

  final SoundDesign _soundDesign = SoundDesign.instance;
  final Map<MusicLayer, AudioSource> _sources = <MusicLayer, AudioSource>{};
  final Map<MusicLayer, SoundHandle> _handles = <MusicLayer, SoundHandle>{};

  Future<void>? _starting;
  bool _running = false;
  bool _ducked = false;
  bool _paused = false;
  double _mixClock = 0;
  double _speedKph = 0;
  double _cadenceRpm = 0;
  HeartRateZone _heartRateZone = HeartRateZone.unknown;
  double _lastBassSpeed = 1;
  int _sessionGeneration = 0;

  bool get isRunning => _running;
  bool get isDucked => _ducked;

  Future<void> initialize() => _soundDesign.initialize();

  Future<void> start() {
    if (_running) {
      return _starting ?? Future<void>.value();
    }
    _running = true;
    _paused = false;
    _ducked = false;
    _mixClock = 0;
    final int generation = ++_sessionGeneration;
    return _starting = _start(generation).whenComplete(() {
      _starting = null;
    });
  }

  Future<void> _start(int generation) async {
    await initialize();
    if (!_soundDesign.audioAvailable ||
        !_running ||
        generation != _sessionGeneration) {
      return;
    }
    final List<AudioSource?> loaded = await Future.wait<AudioSource?>(
      MusicLayer.values.map(_soundDesign.loadMusicLayer),
    );
    if (!_running || generation != _sessionGeneration) {
      return;
    }
    for (int index = 0; index < MusicLayer.values.length; index++) {
      final AudioSource? source = loaded[index];
      if (source == null) {
        continue;
      }
      final MusicLayer layer = MusicLayer.values[index];
      _sources[layer] = source;
      try {
        final SoundHandle handle = await SoLoud.instance.play(
          source,
          volume: 0,
          looping: true,
        );
        SoLoud.instance.setProtectVoice(handle, true);
        _handles[layer] = handle;
      } on Object catch (error) {
        debugPrint('Could not start ${layer.name} music layer: $error');
      }
    }
    _applyMix(immediate: false);
  }

  void update({
    required double dt,
    required double speedKph,
    required double cadenceRpm,
    required HeartRateZone heartRateZone,
  }) {
    if (!_running || !_soundDesign.audioAvailable) {
      return;
    }
    _speedKph = speedKph;
    _cadenceRpm = cadenceRpm;
    _heartRateZone = heartRateZone;
    _mixClock += dt;
    if (_mixClock < 0.35) {
      return;
    }
    _mixClock = 0;
    _applyBassCadence();
    _applyMix(immediate: false);
  }

  void _applyBassCadence() {
    final SoundHandle? handle = _handles[MusicLayer.bass];
    if (handle == null || _cadenceRpm <= 0) {
      return;
    }
    // The source loop is authored at 120 BPM; following step cadence keeps
    // bass attacks aligned with the athlete without regenerating the source.
    final double playSpeed = (_cadenceRpm / 120).clamp(0.62, 1.55).toDouble();
    if ((playSpeed - _lastBassSpeed).abs() < 0.025) {
      return;
    }
    _lastBassSpeed = playSpeed;
    try {
      SoLoud.instance.setRelativePlaySpeed(handle, playSpeed);
    } on Object catch (error) {
      debugPrint('Could not update cadence-following bass: $error');
    }
  }

  void setDucked(bool value) {
    if (_ducked == value) {
      return;
    }
    _ducked = value;
    _applyMix(immediate: false);
  }

  void pause() {
    if (_paused) {
      return;
    }
    _paused = true;
    _applyMix(immediate: false);
  }

  void resume() {
    if (!_paused) {
      return;
    }
    _paused = false;
    _applyMix(immediate: false);
  }

  void _handleSettingsChanged() {
    if (_running) {
      _applyMix(immediate: false);
    }
  }

  void _applyMix({required bool immediate}) {
    if (!_soundDesign.audioAvailable || !SoLoud.instance.isInitialized) {
      return;
    }
    final double speedAmount = GameConstants.normalizedSpeed(_speedKph);
    final double percussionIntensity = ((_speedKph - 2) / 9)
        .clamp(0, 1)
        .toDouble();
    final double bassIntensity = ((_speedKph - 3.5) / 8.5)
        .clamp(0, 1)
        .toDouble();
    final double zoneIntensity = switch (_heartRateZone) {
      HeartRateZone.unknown => speedAmount * 0.25,
      HeartRateZone.recovery => 0.08,
      HeartRateZone.aerobic => 0.28,
      HeartRateZone.tempo => 0.56,
      HeartRateZone.threshold => 0.8,
      HeartRateZone.peak => 1,
    };
    final double sessionGain = _paused ? 0 : (_ducked ? 0.24 : 1);
    final double musicGain =
        _soundDesign.volumeFor(AudioBus.music) * sessionGain;
    final Map<MusicLayer, double> targets = <MusicLayer, double>{
      MusicLayer.ambient: 0.38 * musicGain,
      MusicLayer.percussion: 0.38 * percussionIntensity * musicGain,
      MusicLayer.bass: 0.31 * bassIntensity * musicGain,
      MusicLayer.melody:
          0.28 * zoneIntensity * math.max(0.28, speedAmount) * musicGain,
    };
    final Duration fadeDuration = immediate
        ? Duration.zero
        : const Duration(milliseconds: 720);
    for (final MapEntry<MusicLayer, double> entry in targets.entries) {
      final SoundHandle? handle = _handles[entry.key];
      if (handle == null) {
        continue;
      }
      try {
        if (immediate) {
          SoLoud.instance.setVolume(handle, entry.value);
        } else {
          SoLoud.instance.fadeVolume(handle, entry.value, fadeDuration);
        }
      } on Object catch (error) {
        debugPrint('Could not crossfade ${entry.key.name}: $error');
      }
    }
  }

  Future<void> stop() async {
    if (!_running && _handles.isEmpty) {
      return;
    }
    _running = false;
    ++_sessionGeneration;
    final List<SoundHandle> handles = _handles.values.toList(growable: false);
    _handles.clear();
    _sources.clear();
    if (_soundDesign.audioAvailable && SoLoud.instance.isInitialized) {
      for (final SoundHandle handle in handles) {
        try {
          SoLoud.instance.fadeVolume(
            handle,
            0,
            const Duration(milliseconds: 260),
          );
        } on Object catch (_) {
          // A loop may already have been invalidated during app shutdown.
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 280));
      for (final SoundHandle handle in handles) {
        try {
          await SoLoud.instance.stop(handle);
        } on Object catch (_) {
          // Stopping an already-ended voice is harmless.
        }
      }
    }
    _ducked = false;
    _paused = false;
  }

  Future<void> shutdown() async {
    await stop();
    _soundDesign.removeListener(_handleSettingsChanged);
  }
}
