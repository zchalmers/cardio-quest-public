import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine_models.dart';
import 'adaptive_music.dart';
import 'sound_design.dart';

enum _CoachPriority { routine, event, urgent }

@immutable
class _IntervalPhase {
  const _IntervalPhase(this.seconds, this.callout);

  final int seconds;
  final String callout;
}

/// Event-driven and timer-driven spoken workout coach.
class VoiceCoach {
  VoiceCoach._() {
    _soundDesign.addListener(_handleSettingsChanged);
    _configureHandlers();
  }

  static final VoiceCoach instance = VoiceCoach._();

  static const String _personalBestDistanceKey =
      'cardio_quest_personal_best_distance_meters';

  final SoundDesign _soundDesign = SoundDesign.instance;
  final AdaptiveMusic _adaptiveMusic = AdaptiveMusic.instance;
  final FlutterTts _tts = FlutterTts();
  final math.Random _random = math.Random();

  Future<void>? _initializing;
  SharedPreferences? _preferences;
  bool _initialized = false;
  bool _available = true;
  bool _disposed = false;
  bool _workoutActive = false;
  bool _paused = false;
  bool _speaking = false;
  _CoachPriority _currentPriority = _CoachPriority.routine;
  int _utteranceGeneration = 0;
  double _lastSpeechAtSeconds = -100;
  double _nextPromptAtSeconds = double.infinity;
  double _lastUpdateAtSeconds = 0;
  double _paceReferenceKph = 0;
  int _nextKilometer = 1;
  int _lastIntervalPhase = -1;
  bool _fiveMinuteCalloutPlayed = false;
  double _personalBestDistanceMeters = 0;
  double _lastHeartRateAlertAtSeconds = -1000;

  static const List<String> _encouragement = <String>[
    'Strong work. Keep that rhythm.',
    'Smooth and steady. You are doing great.',
    'Stay tall, breathe easy, and keep moving.',
    'Excellent consistency. Keep it going.',
    'You have more in the tank. Nice work.',
    'Relax your shoulders and trust your pace.',
  ];

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    await _soundDesign.initialize();
    try {
      _preferences = await SharedPreferences.getInstance();
      _personalBestDistanceMeters =
          _preferences?.getDouble(_personalBestDistanceKey) ?? 0;
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      await _applyVoiceConfiguration();
    } on Object catch (error) {
      _available = false;
      debugPrint('Voice coaching is unavailable on this platform: $error');
    }
    _initialized = true;
  }

  void _configureHandlers() {
    _tts
      ..setStartHandler(() {
        _speaking = true;
        _adaptiveMusic.setDucked(true);
      })
      ..setCompletionHandler(_speechEnded)
      ..setCancelHandler(_speechEnded)
      ..setErrorHandler((dynamic _) => _speechEnded());
  }

  void _speechEnded() {
    _speaking = false;
    _adaptiveMusic.setDucked(false);
  }

  void _handleSettingsChanged() {
    if (_initialized && _available && !_disposed) {
      unawaited(_applyVoiceConfiguration());
    }
    if (!_soundDesign.voiceCoachEnabled && _speaking) {
      unawaited(_stopSpeaking());
    }
    final Duration? frequency = _soundDesign.coachFrequency.duration;
    if (_workoutActive && frequency == null) {
      _nextPromptAtSeconds = double.infinity;
    }
  }

  Future<void> _applyVoiceConfiguration() async {
    if (_disposed) {
      return;
    }
    try {
      final bool selectedVoice = await _selectRequestedVoice();
      final double genderFallback = selectedVoice
          ? 1
          : _soundDesign.coachVoiceGender == CoachVoiceGender.male
          ? 0.9
          : 1.06;
      await _tts.setPitch(
        (_soundDesign.coachPitch * genderFallback).clamp(0.5, 2).toDouble(),
      );
      await _tts.setSpeechRate(_soundDesign.coachSpeechRate);
      await _tts.setVolume(
        (_soundDesign.masterVolume * _soundDesign.voiceVolume)
            .clamp(0, 1)
            .toDouble(),
      );
    } on Object catch (error) {
      debugPrint('Could not apply coach voice options: $error');
    }
  }

  Future<bool> _selectRequestedVoice() async {
    final dynamic rawVoices = await _tts.getVoices;
    if (rawVoices is! List<dynamic>) {
      return false;
    }
    final CoachVoiceGender requested = _soundDesign.coachVoiceGender;
    Map<String, String>? fallback;
    for (final dynamic item in rawVoices) {
      if (item is! Map<dynamic, dynamic>) {
        continue;
      }
      final String name = item['name']?.toString() ?? '';
      final String locale = item['locale']?.toString() ?? '';
      if (name.isEmpty || !locale.toLowerCase().startsWith('en')) {
        continue;
      }
      final Map<String, String> candidate = <String, String>{
        'name': name,
        'locale': locale,
      };
      fallback ??= candidate;
      if (_voiceMatchesGender(item, requested)) {
        await _tts.setVoice(candidate);
        return true;
      }
    }
    if (fallback != null) {
      await _tts.setVoice(fallback);
      // Android voices often omit gender metadata. Keep an English voice but
      // use the pitch fallback so the user's male/female choice remains clear.
      return false;
    }
    return false;
  }

  bool _voiceMatchesGender(
    Map<dynamic, dynamic> voice,
    CoachVoiceGender requested,
  ) {
    final String gender = voice['gender']?.toString().toLowerCase() ?? '';
    if (gender.contains(requested.name)) {
      return true;
    }
    // AVSpeechSynthesisVoiceGender uses 1 for male and 2 for female.
    if ((requested == CoachVoiceGender.male && gender == '1') ||
        (requested == CoachVoiceGender.female && gender == '2')) {
      return true;
    }
    final String name = voice['name']?.toString().toLowerCase() ?? '';
    const Set<String> commonlyFemale = <String>{
      'samantha',
      'karen',
      'victoria',
      'moira',
      'tessa',
      'ava',
      'allison',
      'susan',
      'zira',
    };
    const Set<String> commonlyMale = <String>{
      'daniel',
      'alex',
      'fred',
      'aaron',
      'tom',
      'gordon',
      'david',
      'mark',
    };
    final Set<String> names = requested == CoachVoiceGender.female
        ? commonlyFemale
        : commonlyMale;
    return names.any(name.contains);
  }

  void startWorkout() {
    _workoutActive = true;
    _paused = false;
    _paceReferenceKph = 0;
    _nextKilometer = 1;
    _lastIntervalPhase = -1;
    _fiveMinuteCalloutPlayed = false;
    _lastHeartRateAlertAtSeconds = -1000;
    _lastSpeechAtSeconds = -100;
    _lastUpdateAtSeconds = 0;
    _scheduleNextPrompt(0);
    unawaited(initialize());
  }

  void update({
    required double activeSeconds,
    required double distanceMeters,
    required double speedKph,
    required int heartRateBpm,
    required int estimatedMaxHeartRate,
    required HeartRateZone heartRateZone,
  }) {
    if (!_workoutActive || _paused || !_soundDesign.voiceCoachEnabled) {
      return;
    }
    final double dt = math.max(0, activeSeconds - _lastUpdateAtSeconds);
    _lastUpdateAtSeconds = activeSeconds;
    if (speedKph > 1) {
      if (_paceReferenceKph <= 0) {
        _paceReferenceKph = speedKph;
      } else {
        final double blend = 1 - math.exp(-dt / 45);
        _paceReferenceKph += (speedKph - _paceReferenceKph) * blend;
      }
    }

    _checkDistanceMilestone(activeSeconds, distanceMeters);
    _checkInterval(activeSeconds);
    _checkHeartRate(activeSeconds, heartRateBpm, estimatedMaxHeartRate);

    if (activeSeconds >= _nextPromptAtSeconds) {
      _speakPacePrompt(activeSeconds, speedKph, heartRateZone);
      _scheduleNextPrompt(activeSeconds);
    }
  }

  void _checkDistanceMilestone(double activeSeconds, double distanceMeters) {
    while (distanceMeters >= _nextKilometer * 1000) {
      final int milestone = _nextKilometer;
      _nextKilometer++;
      unawaited(
        _speak(
          milestone == 1
              ? 'One kilometer down. Great start.'
              : '$milestone kilometers complete. Strong work.',
          activeSeconds: activeSeconds,
          priority: _CoachPriority.event,
        ),
      );
    }
  }

  void _checkInterval(double activeSeconds) {
    final List<_IntervalPhase> phases = _intervalPhases;
    if (phases.isEmpty) {
      return;
    }
    int elapsed = activeSeconds.floor();
    int phaseIndex = 0;
    final int totalSeconds = phases.fold<int>(
      0,
      (int total, _IntervalPhase phase) => total + phase.seconds,
    );
    for (int index = 0; index < phases.length; index++) {
      if (elapsed < phases[index].seconds) {
        phaseIndex = index;
        break;
      }
      elapsed -= phases[index].seconds;
      phaseIndex = math.min(index + 1, phases.length - 1);
    }
    if (phaseIndex != _lastIntervalPhase && activeSeconds < totalSeconds) {
      _lastIntervalPhase = phaseIndex;
      unawaited(
        _speak(
          phases[phaseIndex].callout,
          activeSeconds: activeSeconds,
          priority: _CoachPriority.event,
        ),
      );
    }
    final double remaining = totalSeconds - activeSeconds;
    if (!_fiveMinuteCalloutPlayed &&
        remaining <= const Duration(minutes: 5).inSeconds &&
        remaining > 0) {
      _fiveMinuteCalloutPlayed = true;
      unawaited(
        _speak(
          'Five minutes remaining. Finish this quest strong.',
          activeSeconds: activeSeconds,
          priority: _CoachPriority.event,
        ),
      );
    }
  }

  void _checkHeartRate(
    double activeSeconds,
    int heartRateBpm,
    int estimatedMaxHeartRate,
  ) {
    if (!_soundDesign.heartRateAlertsEnabled ||
        heartRateBpm <= 0 ||
        estimatedMaxHeartRate <= 0 ||
        activeSeconds - _lastHeartRateAlertAtSeconds < 60) {
      return;
    }
    final double ratio = heartRateBpm / estimatedMaxHeartRate;
    if (ratio >= _soundDesign.heartRateAlertThreshold) {
      _lastHeartRateAlertAtSeconds = activeSeconds;
      unawaited(
        _speak(
          'Heart rate alert. You are near your maximum. Ease back and recover.',
          activeSeconds: activeSeconds,
          priority: _CoachPriority.urgent,
        ),
      );
    }
  }

  void _speakPacePrompt(
    double activeSeconds,
    double speedKph,
    HeartRateZone zone,
  ) {
    final String prompt;
    if (_paceReferenceKph > 1 && speedKph < _paceReferenceKph * 0.9) {
      prompt = 'Add a little speed when you are ready.';
    } else if (zone == HeartRateZone.peak) {
      prompt = 'Controlled effort. Keep your breathing smooth.';
    } else if (_paceReferenceKph > 1 && speedKph > _paceReferenceKph * 1.07) {
      prompt = 'Great pace. You have lifted the tempo.';
    } else if (_random.nextDouble() < 0.48) {
      prompt = 'Hold steady. This pace looks good.';
    } else {
      prompt = _encouragement[_random.nextInt(_encouragement.length)];
    }
    unawaited(
      _speak(
        prompt,
        activeSeconds: activeSeconds,
        priority: _CoachPriority.routine,
      ),
    );
  }

  void announceZoneChange(HeartRateZone zone, {required double activeSeconds}) {
    if (zone == HeartRateZone.unknown) {
      return;
    }
    final String message = switch (zone) {
      HeartRateZone.recovery => 'Back to the recovery zone. Breathe easy.',
      HeartRateZone.aerobic => 'Entered the aerobic zone. Smooth and steady.',
      HeartRateZone.tempo => 'Entered the tempo zone. Hold this rhythm.',
      HeartRateZone.threshold =>
        'Threshold zone. Stay controlled and keep your form.',
      HeartRateZone.peak => 'Peak zone. Strong effort. Watch your breathing.',
      HeartRateZone.unknown => '',
    };
    unawaited(
      _speak(
        message,
        activeSeconds: activeSeconds,
        priority: zone == HeartRateZone.peak
            ? _CoachPriority.urgent
            : _CoachPriority.event,
      ),
    );
  }

  void pauseWorkout() {
    _paused = true;
    unawaited(_stopSpeaking());
  }

  void resumeWorkout(double activeSeconds) {
    _paused = false;
    _scheduleNextPrompt(activeSeconds);
  }

  void finishWorkout({
    required double distanceMeters,
    required double activeSeconds,
  }) {
    if (!_workoutActive) {
      return;
    }
    _workoutActive = false;
    final bool isPersonalBest =
        activeSeconds >= const Duration(minutes: 5).inSeconds &&
        distanceMeters > _personalBestDistanceMeters;
    if (isPersonalBest) {
      _personalBestDistanceMeters = distanceMeters;
      final SharedPreferences? preferences = _preferences;
      if (preferences != null) {
        unawaited(
          preferences.setDouble(_personalBestDistanceKey, distanceMeters),
        );
      }
      unawaited(
        _speak(
          'New personal best. Outstanding work.',
          activeSeconds: activeSeconds,
          priority: _CoachPriority.event,
          allowAfterWorkout: true,
        ),
      );
    }
  }

  void cancelWorkout() {
    _workoutActive = false;
    _paused = false;
    unawaited(_stopSpeaking());
  }

  void _scheduleNextPrompt(double activeSeconds) {
    final Duration? frequency = _soundDesign.coachFrequency.duration;
    _nextPromptAtSeconds = frequency == null
        ? double.infinity
        : activeSeconds + frequency.inSeconds;
  }

  List<_IntervalPhase> get _intervalPhases {
    switch (_soundDesign.intervalPreset) {
      case IntervalWorkoutPreset.off:
        return const <_IntervalPhase>[];
      case IntervalWorkoutPreset.beginnerIntervals:
        return const <_IntervalPhase>[
          _IntervalPhase(300, 'Begin with five minutes of easy warm-up.'),
          _IntervalPhase(60, 'Brisk interval. Lift your pace for one minute.'),
          _IntervalPhase(90, 'Easy recovery. Let your breathing settle.'),
          _IntervalPhase(60, 'Brisk interval. Smooth speed, strong form.'),
          _IntervalPhase(90, 'Recovery interval. Ease back now.'),
          _IntervalPhase(60, 'Brisk interval. One focused minute.'),
          _IntervalPhase(90, 'Easy recovery. Stay loose.'),
          _IntervalPhase(60, 'Brisk interval. Bring the energy up.'),
          _IntervalPhase(90, 'Recovery interval. Find an easy rhythm.'),
          _IntervalPhase(60, 'Brisk interval. Keep it controlled.'),
          _IntervalPhase(90, 'Easy recovery. You are doing well.'),
          _IntervalPhase(60, 'Final brisk interval. Finish it strong.'),
          _IntervalPhase(90, 'Final recovery. Let the effort come down.'),
          _IntervalPhase(300, 'Cool down for five minutes at an easy pace.'),
        ];
      case IntervalWorkoutPreset.tempoBuilder:
        return const <_IntervalPhase>[
          _IntervalPhase(240, 'Warm up for four minutes. Build gradually.'),
          _IntervalPhase(240, 'Tempo block one. Hold a comfortably hard pace.'),
          _IntervalPhase(120, 'Two minutes recovery. Breathe and reset.'),
          _IntervalPhase(240, 'Tempo block two. Return to your strong pace.'),
          _IntervalPhase(120, 'Recovery. Keep moving and stay relaxed.'),
          _IntervalPhase(240, 'Final tempo block. Strong and controlled.'),
          _IntervalPhase(120, 'Tempo work complete. Ease the pace.'),
          _IntervalPhase(240, 'Cool down for four minutes. Great session.'),
        ];
    }
  }

  Future<void> _speak(
    String text, {
    required double activeSeconds,
    required _CoachPriority priority,
    bool allowAfterWorkout = false,
  }) async {
    if (_disposed ||
        !_soundDesign.voiceCoachEnabled ||
        (!_workoutActive && !allowAfterWorkout) ||
        text.isEmpty) {
      return;
    }
    await initialize();
    if (!_available || _disposed) {
      return;
    }
    if (_speaking) {
      if (priority.index <= _currentPriority.index) {
        return;
      }
      try {
        await _tts.stop();
      } on Object catch (_) {
        // The next utterance can still be attempted.
      }
    } else if (activeSeconds - _lastSpeechAtSeconds < 3.5 &&
        priority != _CoachPriority.urgent) {
      return;
    }
    _speaking = true;
    _currentPriority = priority;
    _lastSpeechAtSeconds = activeSeconds;
    final int generation = ++_utteranceGeneration;
    _adaptiveMusic.setDucked(true);
    try {
      await _applyVoiceConfiguration();
      await _tts.speak(text);
    } on Object catch (error) {
      debugPrint('Voice coach callout failed: $error');
    } finally {
      if (generation == _utteranceGeneration) {
        _speaking = false;
        _adaptiveMusic.setDucked(false);
      }
    }
  }

  Future<void> _stopSpeaking() async {
    ++_utteranceGeneration;
    _speaking = false;
    _adaptiveMusic.setDucked(false);
    if (!_initialized || !_available) {
      return;
    }
    try {
      await _tts.stop();
    } on Object catch (_) {
      // Missing TTS backends are already handled during initialization.
    }
  }

  Future<void> shutdown() async {
    _disposed = true;
    _workoutActive = false;
    _soundDesign.removeListener(_handleSettingsChanged);
    await _stopSpeaking();
  }
}
