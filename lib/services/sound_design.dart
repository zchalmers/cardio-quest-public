import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine_models.dart';

enum SynthWaveform { sine, square, triangle, sawtooth }

enum AudioBus { music, sfx, voice }

enum MusicLayer { ambient, percussion, bass, melody }

enum CoachFrequency { off, seconds30, minute1, minutes2 }

enum CoachVoiceGender { female, male }

enum IntervalWorkoutPreset { off, beginnerIntervals, tempoBuilder }

extension CoachFrequencyLabel on CoachFrequency {
  String get label => switch (this) {
    CoachFrequency.off => 'Periodic prompts off',
    CoachFrequency.seconds30 => 'Every 30 seconds',
    CoachFrequency.minute1 => 'Every 60 seconds',
    CoachFrequency.minutes2 => 'Every 2 minutes',
  };

  Duration? get duration => switch (this) {
    CoachFrequency.off => null,
    CoachFrequency.seconds30 => const Duration(seconds: 30),
    CoachFrequency.minute1 => const Duration(minutes: 1),
    CoachFrequency.minutes2 => const Duration(minutes: 2),
  };
}

extension CoachVoiceGenderLabel on CoachVoiceGender {
  String get label => switch (this) {
    CoachVoiceGender.female => 'Female',
    CoachVoiceGender.male => 'Male',
  };
}

extension IntervalWorkoutPresetLabel on IntervalWorkoutPreset {
  String get label => switch (this) {
    IntervalWorkoutPreset.off => 'Open workout',
    IntervalWorkoutPreset.beginnerIntervals => 'Beginner intervals · 25 min',
    IntervalWorkoutPreset.tempoBuilder => 'Tempo builder · 26 min',
  };
}

@immutable
class AdsrEnvelope {
  const AdsrEnvelope({
    this.attack = 0.01,
    this.decay = 0.05,
    this.sustain = 0.72,
    this.release = 0.08,
  });

  final double attack;
  final double decay;
  final double sustain;
  final double release;

  double gain(double time, double duration) {
    if (time < 0 || time >= duration) {
      return 0;
    }
    final double safeAttack = math.min(attack, duration * 0.35);
    final double safeDecay = math.min(decay, duration * 0.35);
    final double safeRelease = math.min(release, duration * 0.45);
    if (safeAttack > 0 && time < safeAttack) {
      return time / safeAttack;
    }
    if (safeDecay > 0 && time < safeAttack + safeDecay) {
      final double progress = (time - safeAttack) / safeDecay;
      return 1 - (1 - sustain) * progress;
    }
    final double releaseStart = duration - safeRelease;
    if (safeRelease > 0 && time > releaseStart) {
      return sustain * ((duration - time) / safeRelease).clamp(0, 1);
    }
    return sustain;
  }
}

/// Runtime synthesizer, DSP processor, cache, and persisted audio mixer.
///
/// Every byte passed to SoLoud is generated below; the app contains no audio
/// assets. Short effects and loop layers are rendered once and then kept as
/// in-memory [AudioSource] objects for low-latency reuse.
class SoundDesign extends ChangeNotifier {
  SoundDesign._();

  static final SoundDesign instance = SoundDesign._();

  static const int sampleRate = 22050;
  static const String _keyPrefix = 'cardio_quest_audio_';

  final Map<String, Future<AudioSource?>> _soundCache =
      <String, Future<AudioSource?>>{};
  SharedPreferences? _preferences;
  Future<void>? _initializing;
  bool _initialized = false;
  bool _audioAvailable = false;

  double _masterVolume = 0.85;
  double _musicVolume = 0.62;
  double _sfxVolume = 0.82;
  double _voiceVolume = 0.9;
  bool _voiceCoachEnabled = true;
  CoachFrequency _coachFrequency = CoachFrequency.minute1;
  bool _heartRateAlertsEnabled = true;
  double _heartRateAlertThreshold = 0.9;
  CoachVoiceGender _coachVoiceGender = CoachVoiceGender.female;
  double _coachPitch = 1;
  double _coachSpeechRate = 0.5;
  IntervalWorkoutPreset _intervalPreset = IntervalWorkoutPreset.off;

  bool get isInitialized => _initialized;
  bool get audioAvailable => _audioAvailable;
  double get masterVolume => _masterVolume;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  double get voiceVolume => _voiceVolume;
  bool get voiceCoachEnabled => _voiceCoachEnabled;
  CoachFrequency get coachFrequency => _coachFrequency;
  bool get heartRateAlertsEnabled => _heartRateAlertsEnabled;
  double get heartRateAlertThreshold => _heartRateAlertThreshold;
  CoachVoiceGender get coachVoiceGender => _coachVoiceGender;
  double get coachPitch => _coachPitch;
  double get coachSpeechRate => _coachSpeechRate;
  IntervalWorkoutPreset get intervalPreset => _intervalPreset;

  double volumeFor(AudioBus bus) => switch (bus) {
    AudioBus.music => _musicVolume,
    AudioBus.sfx => _sfxVolume,
    AudioBus.voice => _voiceVolume,
  };

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      _restoreSettings();
    } on Object catch (error) {
      debugPrint('Audio settings could not be restored: $error');
    }
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          sampleRate: sampleRate,
          bufferSize: 1024,
          channels: Channels.stereo,
        );
      }
      _audioAvailable = true;
      SoLoud.instance.setGlobalVolume(_masterVolume);
    } on Object catch (error) {
      _audioAvailable = false;
      debugPrint('Procedural audio is unavailable on this platform: $error');
    }
    _initialized = true;
    notifyListeners();
  }

  void _restoreSettings() {
    final SharedPreferences? preferences = _preferences;
    if (preferences == null) {
      return;
    }
    _masterVolume =
        preferences.getDouble('${_keyPrefix}master') ?? _masterVolume;
    _musicVolume = preferences.getDouble('${_keyPrefix}music') ?? _musicVolume;
    _sfxVolume = preferences.getDouble('${_keyPrefix}sfx') ?? _sfxVolume;
    _voiceVolume = preferences.getDouble('${_keyPrefix}voice') ?? _voiceVolume;
    _voiceCoachEnabled =
        preferences.getBool('${_keyPrefix}coach_enabled') ?? _voiceCoachEnabled;
    _coachFrequency = _enumValue(
      CoachFrequency.values,
      preferences.getString('${_keyPrefix}coach_frequency'),
      _coachFrequency,
    );
    _heartRateAlertsEnabled =
        preferences.getBool('${_keyPrefix}hr_alerts') ??
        _heartRateAlertsEnabled;
    _heartRateAlertThreshold =
        preferences.getDouble('${_keyPrefix}hr_threshold') ??
        _heartRateAlertThreshold;
    _coachVoiceGender = _enumValue(
      CoachVoiceGender.values,
      preferences.getString('${_keyPrefix}voice_gender'),
      _coachVoiceGender,
    );
    _coachPitch =
        preferences.getDouble('${_keyPrefix}coach_pitch') ?? _coachPitch;
    _coachSpeechRate =
        preferences.getDouble('${_keyPrefix}coach_rate') ?? _coachSpeechRate;
    _intervalPreset = _enumValue(
      IntervalWorkoutPreset.values,
      preferences.getString('${_keyPrefix}interval'),
      _intervalPreset,
    );
  }

  T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) {
      return fallback;
    }
    return values.firstWhere(
      (T value) => value.name == name,
      orElse: () => fallback,
    );
  }

  void setMasterVolume(double value) {
    final double next = value.clamp(0, 1).toDouble();
    if (next == _masterVolume) {
      return;
    }
    _masterVolume = next;
    if (_audioAvailable) {
      SoLoud.instance.setGlobalVolume(next);
    }
    _persistDouble('master', next);
    notifyListeners();
  }

  void setMusicVolume(double value) {
    final double next = value.clamp(0, 1).toDouble();
    if (next == _musicVolume) {
      return;
    }
    _musicVolume = next;
    _persistDouble('music', next);
    notifyListeners();
  }

  void setSfxVolume(double value) {
    final double next = value.clamp(0, 1).toDouble();
    if (next == _sfxVolume) {
      return;
    }
    _sfxVolume = next;
    _persistDouble('sfx', next);
    notifyListeners();
  }

  void setVoiceVolume(double value) {
    final double next = value.clamp(0, 1).toDouble();
    if (next == _voiceVolume) {
      return;
    }
    _voiceVolume = next;
    _persistDouble('voice', next);
    notifyListeners();
  }

  void setVoiceCoachEnabled(bool value) {
    if (value == _voiceCoachEnabled) {
      return;
    }
    _voiceCoachEnabled = value;
    _persistBool('coach_enabled', value);
    notifyListeners();
  }

  void setCoachFrequency(CoachFrequency value) {
    if (value == _coachFrequency) {
      return;
    }
    _coachFrequency = value;
    _persistString('coach_frequency', value.name);
    notifyListeners();
  }

  void setHeartRateAlertsEnabled(bool value) {
    if (value == _heartRateAlertsEnabled) {
      return;
    }
    _heartRateAlertsEnabled = value;
    _persistBool('hr_alerts', value);
    notifyListeners();
  }

  void setHeartRateAlertThreshold(double value) {
    final double next = value.clamp(0.7, 1).toDouble();
    if (next == _heartRateAlertThreshold) {
      return;
    }
    _heartRateAlertThreshold = next;
    _persistDouble('hr_threshold', next);
    notifyListeners();
  }

  void setCoachVoiceGender(CoachVoiceGender value) {
    if (value == _coachVoiceGender) {
      return;
    }
    _coachVoiceGender = value;
    _persistString('voice_gender', value.name);
    notifyListeners();
  }

  void setCoachPitch(double value) {
    final double next = value.clamp(0.7, 1.3).toDouble();
    if (next == _coachPitch) {
      return;
    }
    _coachPitch = next;
    _persistDouble('coach_pitch', next);
    notifyListeners();
  }

  void setCoachSpeechRate(double value) {
    final double next = value.clamp(0.3, 0.7).toDouble();
    if (next == _coachSpeechRate) {
      return;
    }
    _coachSpeechRate = next;
    _persistDouble('coach_rate', next);
    notifyListeners();
  }

  void setIntervalPreset(IntervalWorkoutPreset value) {
    if (value == _intervalPreset) {
      return;
    }
    _intervalPreset = value;
    _persistString('interval', value.name);
    notifyListeners();
  }

  void _persistDouble(String key, double value) {
    final SharedPreferences? preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setDouble('$_keyPrefix$key', value));
    }
  }

  void _persistBool(String key, bool value) {
    final SharedPreferences? preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setBool('$_keyPrefix$key', value));
    }
  }

  void _persistString(String key, String value) {
    final SharedPreferences? preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setString('$_keyPrefix$key', value));
    }
  }

  Future<AudioSource?> loadFootstep(MotionMode mode) =>
      _cachedSource('footstep_${mode.name}', () => renderFootstep(mode));

  Future<AudioSource?> loadCoin() => _cachedSource('coin', renderCoinPickup);

  Future<AudioSource?> loadJump() => _cachedSource('jump', renderJump);

  Future<AudioSource?> loadObstacleHit({required bool shielded}) =>
      _cachedSource(
        shielded ? 'obstacle_shielded' : 'obstacle_hit',
        () => renderObstacleHit(shielded: shielded),
      );

  Future<AudioSource?> loadPowerUp(PowerUpType type) =>
      _cachedSource('power_up_${type.name}', () => renderPowerUp(type));

  Future<AudioSource?> loadSpeedTransition({required bool speedingUp}) =>
      _cachedSource(
        speedingUp ? 'speed_up' : 'speed_down',
        () => renderSpeedTransition(speedingUp: speedingUp),
      );

  Future<AudioSource?> loadComboMilestone(int milestone) =>
      _cachedSource('combo_$milestone', () => renderComboMilestone(milestone));

  Future<AudioSource?> loadZoneTransition(HeartRateZone zone) =>
      _cachedSource('zone_${zone.name}', () => renderZoneTransition(zone));

  Future<AudioSource?> loadMusicLayer(MusicLayer layer) =>
      _cachedSource('music_${layer.name}', () => renderMusicLayer(layer));

  Future<AudioSource?> _cachedSource(String key, Uint8List Function() render) {
    return _soundCache.putIfAbsent(key, () async {
      await initialize();
      if (!_audioAvailable) {
        return null;
      }
      try {
        final Uint8List bytes = render();
        return await SoLoud.instance.loadMem('cardio_quest_$key.wav', bytes);
      } on Object catch (error) {
        _soundCache.remove(key);
        debugPrint('Could not synthesize $key: $error');
        return null;
      }
    });
  }

  double variedPitch(math.Random random, {double amount = 0.045}) =>
      1 + (random.nextDouble() * 2 - 1) * amount;

  Uint8List renderFootstep(MotionMode mode) {
    final (double pitch, double noise, double duration) = switch (mode) {
      MotionMode.walk => (92, 0.11, 0.17),
      MotionMode.jog => (132, 0.14, 0.135),
      MotionMode.sprint => (178, 0.18, 0.105),
    };
    return _render(
      duration: duration,
      tones: <_ToneEvent>[
        _ToneEvent(
          frequency: pitch,
          endFrequency: pitch * 0.54,
          duration: duration,
          amplitude: 0.72,
          waveform: SynthWaveform.triangle,
          envelope: const AdsrEnvelope(
            attack: 0.002,
            decay: 0.035,
            sustain: 0.2,
            release: 0.07,
          ),
        ),
      ],
      noiseAmount: noise,
      noiseEnvelope: const AdsrEnvelope(
        attack: 0.001,
        decay: 0.025,
        sustain: 0.12,
        release: 0.055,
      ),
      delaySeconds: 0.032,
      delayDecay: 0.1,
    );
  }

  Uint8List renderCoinPickup() {
    return _render(
      duration: 0.34,
      tones: const <_ToneEvent>[
        _ToneEvent(
          frequency: 1318.51,
          duration: 0.13,
          amplitude: 0.6,
          waveform: SynthWaveform.sine,
        ),
        _ToneEvent(
          start: 0.085,
          frequency: 1760,
          duration: 0.19,
          amplitude: 0.72,
          waveform: SynthWaveform.triangle,
        ),
      ],
      delaySeconds: 0.075,
      delayDecay: 0.26,
      reverbAmount: 0.18,
    );
  }

  Uint8List renderJump() {
    return _render(
      duration: 0.38,
      tones: const <_ToneEvent>[
        _ToneEvent(
          frequency: 170,
          endFrequency: 920,
          duration: 0.31,
          amplitude: 0.42,
          waveform: SynthWaveform.sine,
          envelope: AdsrEnvelope(
            attack: 0.025,
            decay: 0.08,
            sustain: 0.52,
            release: 0.12,
          ),
        ),
      ],
      noiseAmount: 0.12,
      noiseEnvelope: const AdsrEnvelope(
        attack: 0.03,
        decay: 0.06,
        sustain: 0.3,
        release: 0.16,
      ),
      reverbAmount: 0.12,
    );
  }

  Uint8List renderObstacleHit({required bool shielded}) {
    if (shielded) {
      return _render(
        duration: 0.45,
        tones: const <_ToneEvent>[
          _ToneEvent(
            frequency: 310,
            endFrequency: 620,
            duration: 0.2,
            amplitude: 0.55,
            waveform: SynthWaveform.triangle,
          ),
          _ToneEvent(
            start: 0.06,
            frequency: 930,
            endFrequency: 540,
            duration: 0.28,
            amplitude: 0.34,
            waveform: SynthWaveform.sine,
          ),
        ],
        delaySeconds: 0.055,
        delayDecay: 0.28,
        reverbAmount: 0.24,
      );
    }
    return _render(
      duration: 0.42,
      tones: const <_ToneEvent>[
        _ToneEvent(
          frequency: 88,
          endFrequency: 42,
          duration: 0.34,
          amplitude: 0.88,
          waveform: SynthWaveform.triangle,
          envelope: AdsrEnvelope(
            attack: 0.002,
            decay: 0.07,
            sustain: 0.35,
            release: 0.16,
          ),
        ),
      ],
      noiseAmount: 0.16,
      noiseEnvelope: const AdsrEnvelope(
        attack: 0.001,
        decay: 0.04,
        sustain: 0.08,
        release: 0.1,
      ),
      reverbAmount: 0.1,
    );
  }

  Uint8List renderPowerUp(PowerUpType type) {
    final List<double> notes = switch (type) {
      PowerUpType.magnet => <double>[392, 493.88, 659.25, 783.99],
      PowerUpType.shield => <double>[261.63, 392, 523.25, 783.99],
      PowerUpType.doubleCoins => <double>[440, 554.37, 659.25, 880],
    };
    return _renderArpeggio(notes, step: 0.082, noteLength: 0.24);
  }

  Uint8List renderSpeedTransition({required bool speedingUp}) {
    final List<double> notes = speedingUp
        ? <double>[329.63, 440, 554.37]
        : <double>[554.37, 440, 329.63];
    return _renderArpeggio(notes, step: 0.07, noteLength: 0.16);
  }

  Uint8List renderComboMilestone(int milestone) {
    final double root = switch (milestone) {
      2 => 261.63,
      3 => 329.63,
      5 => 392,
      10 => 523.25,
      _ => 261.63,
    };
    final List<double> ratios = milestone >= 5
        ? <double>[1, 1.25, 1.5, 2]
        : <double>[1, 1.25, 1.5];
    return _render(
      duration: milestone >= 5 ? 0.72 : 0.52,
      tones: ratios
          .map(
            (double ratio) => _ToneEvent(
              frequency: root * ratio,
              duration: milestone >= 5 ? 0.58 : 0.4,
              amplitude: 0.3,
              waveform: SynthWaveform.triangle,
            ),
          )
          .toList(growable: false),
      delaySeconds: 0.11,
      delayDecay: 0.3,
      reverbAmount: 0.28,
    );
  }

  Uint8List renderZoneTransition(HeartRateZone zone) {
    final double root = switch (zone) {
      HeartRateZone.recovery => 220,
      HeartRateZone.aerobic => 293.66,
      HeartRateZone.tempo => 369.99,
      HeartRateZone.threshold => 440,
      HeartRateZone.peak => 523.25,
      HeartRateZone.unknown => 196,
    };
    return _renderArpeggio(
      <double>[root, root * 1.25],
      step: 0.09,
      noteLength: 0.2,
    );
  }

  Uint8List _renderArpeggio(
    List<double> notes, {
    required double step,
    required double noteLength,
  }) {
    return _render(
      duration: step * (notes.length - 1) + noteLength + 0.18,
      tones: <_ToneEvent>[
        for (int index = 0; index < notes.length; index++)
          _ToneEvent(
            start: index * step,
            frequency: notes[index],
            duration: noteLength,
            amplitude: 0.44,
            waveform: SynthWaveform.triangle,
          ),
      ],
      delaySeconds: 0.085,
      delayDecay: 0.24,
      reverbAmount: 0.2,
    );
  }

  Uint8List renderMusicLayer(MusicLayer layer) => switch (layer) {
    MusicLayer.ambient => _renderAmbientLoop(),
    MusicLayer.percussion => _renderPercussionLoop(),
    MusicLayer.bass => _renderBassLoop(),
    MusicLayer.melody => _renderMelodyLoop(),
  };

  Uint8List _renderAmbientLoop() {
    return _render(
      duration: 8,
      tones: const <_ToneEvent>[
        _ToneEvent(
          frequency: 110,
          duration: 8,
          amplitude: 0.24,
          waveform: SynthWaveform.sine,
          envelope: AdsrEnvelope(
            attack: 0.22,
            decay: 0.4,
            sustain: 0.78,
            release: 0.22,
          ),
        ),
        _ToneEvent(
          frequency: 164.81,
          duration: 8,
          amplitude: 0.16,
          waveform: SynthWaveform.triangle,
          envelope: AdsrEnvelope(
            attack: 0.28,
            decay: 0.4,
            sustain: 0.72,
            release: 0.28,
          ),
        ),
        _ToneEvent(
          frequency: 220,
          duration: 8,
          amplitude: 0.1,
          waveform: SynthWaveform.sine,
          envelope: AdsrEnvelope(
            attack: 0.34,
            decay: 0.4,
            sustain: 0.7,
            release: 0.34,
          ),
        ),
      ],
      delaySeconds: 0.29,
      delayDecay: 0.18,
      reverbAmount: 0.32,
    );
  }

  Uint8List _renderPercussionLoop() {
    final List<_ToneEvent> tones = <_ToneEvent>[];
    for (int beat = 0; beat < 8; beat++) {
      final double start = beat * 0.5;
      tones.add(
        _ToneEvent(
          start: start,
          frequency: beat.isEven ? 76 : 105,
          endFrequency: 42,
          duration: beat.isEven ? 0.18 : 0.1,
          amplitude: beat.isEven ? 0.75 : 0.38,
          waveform: SynthWaveform.triangle,
          envelope: const AdsrEnvelope(
            attack: 0.001,
            decay: 0.035,
            sustain: 0.12,
            release: 0.07,
          ),
        ),
      );
      tones.add(
        _ToneEvent(
          start: start + 0.25,
          frequency: 2300,
          endFrequency: 1500,
          duration: 0.045,
          amplitude: 0.11,
          waveform: SynthWaveform.square,
        ),
      );
    }
    return _render(
      duration: 4,
      tones: tones,
      noiseAmount: 0.025,
      noiseEnvelope: const AdsrEnvelope(
        attack: 0.001,
        decay: 0.01,
        sustain: 0.02,
        release: 0.02,
      ),
      reverbAmount: 0.08,
    );
  }

  Uint8List _renderBassLoop() {
    const List<double> notes = <double>[
      55,
      55,
      65.41,
      73.42,
      55,
      82.41,
      73.42,
      65.41,
    ];
    return _render(
      duration: 4,
      tones: <_ToneEvent>[
        for (int index = 0; index < notes.length; index++)
          _ToneEvent(
            start: index * 0.5,
            frequency: notes[index],
            duration: 0.42,
            amplitude: 0.46,
            waveform: SynthWaveform.sawtooth,
            envelope: const AdsrEnvelope(
              attack: 0.012,
              decay: 0.08,
              sustain: 0.52,
              release: 0.12,
            ),
          ),
      ],
      reverbAmount: 0.05,
    );
  }

  Uint8List _renderMelodyLoop() {
    const List<double> notes = <double>[
      440,
      493.88,
      659.25,
      554.37,
      493.88,
      440,
      369.99,
      493.88,
    ];
    return _render(
      duration: 8,
      tones: <_ToneEvent>[
        for (int index = 0; index < notes.length; index++)
          _ToneEvent(
            start: index.toDouble(),
            frequency: notes[index],
            duration: 0.62,
            amplitude: 0.27,
            waveform: SynthWaveform.triangle,
            envelope: const AdsrEnvelope(
              attack: 0.035,
              decay: 0.1,
              sustain: 0.48,
              release: 0.22,
            ),
          ),
      ],
      delaySeconds: 0.24,
      delayDecay: 0.27,
      reverbAmount: 0.24,
    );
  }

  Uint8List _render({
    required double duration,
    required List<_ToneEvent> tones,
    double noiseAmount = 0,
    AdsrEnvelope noiseEnvelope = const AdsrEnvelope(),
    double delaySeconds = 0,
    double delayDecay = 0,
    double reverbAmount = 0,
  }) {
    final int frameCount = math.max(1, (duration * sampleRate).round());
    final Float64List samples = Float64List(frameCount);
    final math.Random random = math.Random(0xC4D10);
    double smoothedNoise = 0;

    for (int frame = 0; frame < frameCount; frame++) {
      final double time = frame / sampleRate;
      double sample = 0;
      for (final _ToneEvent tone in tones) {
        final double localTime = time - tone.start;
        if (localTime < 0 || localTime >= tone.duration) {
          continue;
        }
        final double frequencyDelta =
            (tone.endFrequency ?? tone.frequency) - tone.frequency;
        final double cycles =
            tone.frequency * localTime +
            0.5 * frequencyDelta * localTime * localTime / tone.duration;
        final double phase = cycles - cycles.floorToDouble();
        sample +=
            _wave(phase, tone.waveform) *
            tone.amplitude *
            tone.envelope.gain(localTime, tone.duration);
      }
      if (noiseAmount > 0) {
        final double rawNoise = random.nextDouble() * 2 - 1;
        smoothedNoise = smoothedNoise * 0.72 + rawNoise * 0.28;
        sample +=
            smoothedNoise * noiseAmount * noiseEnvelope.gain(time, duration);
      }
      samples[frame] = sample;
    }

    if (delaySeconds > 0 && delayDecay > 0) {
      _applyDelay(samples, delaySeconds, delayDecay);
    }
    if (reverbAmount > 0) {
      _applyReverb(samples, reverbAmount);
    }
    _normalize(samples);
    return _encodeMonoWav(samples);
  }

  double _wave(double phase, SynthWaveform waveform) => switch (waveform) {
    SynthWaveform.sine => math.sin(phase * math.pi * 2),
    SynthWaveform.square => phase < 0.5 ? 1 : -1,
    SynthWaveform.triangle => 1 - 4 * (phase - 0.5).abs(),
    SynthWaveform.sawtooth => phase * 2 - 1,
  };

  void _applyDelay(Float64List samples, double seconds, double decay) {
    final int delayFrames = math.max(1, (seconds * sampleRate).round());
    for (int frame = delayFrames; frame < samples.length; frame++) {
      samples[frame] += samples[frame - delayFrames] * decay;
    }
  }

  void _applyReverb(Float64List samples, double amount) {
    const List<double> taps = <double>[0.029, 0.037, 0.043, 0.061];
    final Float64List dry = Float64List.fromList(samples);
    for (int tapIndex = 0; tapIndex < taps.length; tapIndex++) {
      final int delayFrames = (taps[tapIndex] * sampleRate).round();
      final double gain = amount * (0.34 - tapIndex * 0.055);
      for (int frame = delayFrames; frame < samples.length; frame++) {
        samples[frame] += dry[frame - delayFrames] * gain;
      }
    }
  }

  void _normalize(Float64List samples) {
    double peak = 0;
    for (final double sample in samples) {
      peak = math.max(peak, sample.abs());
    }
    final double scale = peak > 0.94 ? 0.94 / peak : 1;
    for (int index = 0; index < samples.length; index++) {
      samples[index] *= scale;
    }
  }

  Uint8List _encodeMonoWav(Float64List samples) {
    const int headerLength = 44;
    const int bytesPerSample = 2;
    final int dataLength = samples.length * bytesPerSample;
    final ByteData data = ByteData(headerLength + dataLength);
    _writeAscii(data, 0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    _writeAscii(data, 8, 'WAVE');
    _writeAscii(data, 12, 'fmt ');
    data
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * bytesPerSample, Endian.little)
      ..setUint16(32, bytesPerSample, Endian.little)
      ..setUint16(34, 16, Endian.little);
    _writeAscii(data, 36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    for (int index = 0; index < samples.length; index++) {
      final int pcm = (samples[index].clamp(-1, 1) * 32767).round();
      data.setInt16(headerLength + index * bytesPerSample, pcm, Endian.little);
    }
    return data.buffer.asUint8List();
  }

  void _writeAscii(ByteData data, int offset, String value) {
    for (int index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  Future<void> shutdown() async {
    _soundCache.clear();
    if (_audioAvailable && SoLoud.instance.isInitialized) {
      SoLoud.instance.deinit();
    }
    _audioAvailable = false;
    _initialized = false;
    _initializing = null;
  }
}

@immutable
class _ToneEvent {
  const _ToneEvent({
    required this.frequency,
    required this.duration,
    this.start = 0,
    this.endFrequency,
    this.amplitude = 0.5,
    this.waveform = SynthWaveform.sine,
    this.envelope = const AdsrEnvelope(),
  });

  final double start;
  final double frequency;
  final double? endFrequency;
  final double duration;
  final double amplitude;
  final SynthWaveform waveform;
  final AdsrEnvelope envelope;
}
