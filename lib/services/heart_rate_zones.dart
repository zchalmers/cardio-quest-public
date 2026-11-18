import 'dart:async';
import 'dart:math' as math;

import '../models/machine_models.dart';

enum MaxHeartRateFormula { fox, tanaka, gulati }

enum HeartRateProfileSex { female, male, unspecified }

class HeartRateProfile {
  const HeartRateProfile({
    required this.age,
    this.sex = HeartRateProfileSex.unspecified,
    this.formula,
  });

  final int age;
  final HeartRateProfileSex sex;
  final MaxHeartRateFormula? formula;

  MaxHeartRateFormula get effectiveFormula =>
      formula ??
      (sex == HeartRateProfileSex.female
          ? MaxHeartRateFormula.gulati
          : MaxHeartRateFormula.tanaka);

  int get estimatedMaxHeartRate => HeartRateZoneEngine.calculateMaxHeartRate(
    age: age,
    formula: effectiveFormula,
  );
}

class HeartRateZoneTransition {
  const HeartRateZoneTransition({
    required this.occurredAt,
    required this.enteredZone,
    this.leftZone,
  });

  final DateTime occurredAt;
  final HeartRateZone enteredZone;
  final HeartRateZone? leftZone;
}

/// Stateful five-zone tracker for a single workout.
///
/// Call [start], [pause]/[resume], and [finish] with workout lifecycle events.
/// Samples should be timestamped by the source where possible.
class HeartRateZoneEngine {
  HeartRateZoneEngine({
    required int estimatedMaxHeartRate,
    this.maximumSampleGap = const Duration(seconds: 30),
  }) : estimatedMaxHeartRate = _validatedMax(estimatedMaxHeartRate);

  HeartRateZoneEngine.fromProfile(
    HeartRateProfile profile, {
    Duration maximumSampleGap = const Duration(seconds: 30),
  }) : this(
         estimatedMaxHeartRate: profile.estimatedMaxHeartRate,
         maximumSampleGap: maximumSampleGap,
       );

  final int estimatedMaxHeartRate;
  final Duration maximumSampleGap;
  final StreamController<HeartRateZoneTransition> _transitionController =
      StreamController<HeartRateZoneTransition>.broadcast(sync: true);

  final Map<HeartRateZone, Duration> _zoneDurations = <HeartRateZone, Duration>{
    HeartRateZone.recovery: Duration.zero,
    HeartRateZone.aerobic: Duration.zero,
    HeartRateZone.tempo: Duration.zero,
    HeartRateZone.threshold: Duration.zero,
    HeartRateZone.peak: Duration.zero,
  };
  final List<double> _heartRates = <double>[];
  final List<double> _rrIntervalsMilliseconds = <double>[];
  final List<double> _reportedSdnnMilliseconds = <double>[];
  final List<double> _reportedRmssdMilliseconds = <double>[];

  DateTime? _lastSampleAt;
  HeartRateZone _currentZone = HeartRateZone.unknown;
  bool _isActive = false;
  int? _latestHeartRate;
  int _maximumObservedHeartRate = 0;

  DateTime? _recoveryStartedAt;
  int? _recoveryBaselineBpm;
  int? _recoveryOneMinuteBpm;
  int? _recoveryTwoMinuteBpm;
  int? _recoveryCurrentBpm;

  Stream<HeartRateZoneTransition> get transitions =>
      _transitionController.stream;
  HeartRateZone get currentZone => _currentZone;
  bool get isActive => _isActive;
  int get maximumObservedHeartRate => _maximumObservedHeartRate;

  Map<HeartRateZone, Duration> get zoneDurations =>
      Map<HeartRateZone, Duration>.unmodifiable(_zoneDurations);

  static int calculateMaxHeartRate({
    required int age,
    MaxHeartRateFormula formula = MaxHeartRateFormula.tanaka,
  }) {
    if (age <= 0 || age > 120) {
      throw RangeError.range(age, 1, 120, 'age');
    }
    final double estimate = switch (formula) {
      MaxHeartRateFormula.fox => 220 - age.toDouble(),
      MaxHeartRateFormula.tanaka => 208 - (0.7 * age),
      MaxHeartRateFormula.gulati => 206 - (0.88 * age),
    };
    return estimate.round();
  }

  static HeartRateZone zoneFor(int bpm, {required int maxHeartRate}) {
    if (bpm <= 0 || maxHeartRate <= 0) {
      return HeartRateZone.unknown;
    }
    final double percentage = bpm / maxHeartRate;
    if (percentage < 0.60) {
      return HeartRateZone.recovery;
    }
    if (percentage < 0.70) {
      return HeartRateZone.aerobic;
    }
    if (percentage < 0.80) {
      return HeartRateZone.tempo;
    }
    if (percentage < 0.90) {
      return HeartRateZone.threshold;
    }
    return HeartRateZone.peak;
  }

  HeartRateZone zoneForBpm(int bpm) =>
      zoneFor(bpm, maxHeartRate: estimatedMaxHeartRate);

  void start({DateTime? at}) {
    reset();
    _isActive = true;
    _lastSampleAt = at ?? DateTime.now();
  }

  void addSample(int bpm, {DateTime? at}) {
    if (bpm < 25 || bpm > 250) {
      return;
    }
    final DateTime timestamp = at ?? DateTime.now();
    _recordRecoverySample(bpm, timestamp);
    _latestHeartRate = bpm;
    _maximumObservedHeartRate = math.max(_maximumObservedHeartRate, bpm);
    _heartRates.add(bpm.toDouble());

    if (!_isActive) {
      return;
    }
    final DateTime? previousAt = _lastSampleAt;
    if (previousAt != null && timestamp.isBefore(previousAt)) {
      return;
    }
    if (previousAt != null) {
      _accumulateCurrentZone(timestamp.difference(previousAt));
    }

    final HeartRateZone nextZone = zoneForBpm(bpm);
    if (nextZone != _currentZone) {
      _transitionController.add(
        HeartRateZoneTransition(
          occurredAt: timestamp,
          enteredZone: nextZone,
          leftZone: _currentZone == HeartRateZone.unknown ? null : _currentZone,
        ),
      );
      _currentZone = nextZone;
    }
    _lastSampleAt = timestamp;
  }

  /// Adds an R-R interval from a chest strap or another beat-level source.
  void addRrInterval(double milliseconds) {
    if (milliseconds >= 250 && milliseconds <= 2500) {
      _rrIntervalsMilliseconds.add(milliseconds);
    }
  }

  /// Adds a device-computed SDNN sample, such as HealthKit HRV data.
  void addHrvSample(double sdnnMilliseconds) {
    if (sdnnMilliseconds > 0 && sdnnMilliseconds < 1000) {
      _reportedSdnnMilliseconds.add(sdnnMilliseconds);
    }
  }

  /// Adds a device-computed RMSSD sample, such as Health Connect HRV data.
  void addRmssdSample(double rmssdMilliseconds) {
    if (rmssdMilliseconds > 0 && rmssdMilliseconds < 1000) {
      _reportedRmssdMilliseconds.add(rmssdMilliseconds);
    }
  }

  void pause({DateTime? at}) {
    if (!_isActive) {
      return;
    }
    final DateTime timestamp = at ?? DateTime.now();
    final DateTime? previousAt = _lastSampleAt;
    if (previousAt != null && !timestamp.isBefore(previousAt)) {
      _accumulateCurrentZone(timestamp.difference(previousAt));
    }
    _lastSampleAt = null;
    _isActive = false;
  }

  void resume({DateTime? at}) {
    if (_isActive) {
      return;
    }
    _isActive = true;
    _lastSampleAt = at ?? DateTime.now();
  }

  void finish({DateTime? at}) {
    pause(at: at);
  }

  void beginRecovery({DateTime? at, int? baselineBpm}) {
    _recoveryStartedAt = at ?? DateTime.now();
    _recoveryBaselineBpm =
        baselineBpm ?? _latestHeartRate ?? _maximumObservedHeartRate;
    _recoveryOneMinuteBpm = null;
    _recoveryTwoMinuteBpm = null;
    _recoveryCurrentBpm = _recoveryBaselineBpm;
  }

  HeartRateVariabilityStats get variability {
    final double? heartRateStandardDeviation = _standardDeviation(_heartRates);
    final double? intervalSdnn = _standardDeviation(_rrIntervalsMilliseconds);
    final double? reportedSdnn = _mean(_reportedSdnnMilliseconds);
    double? intervalRmssd;
    if (_rrIntervalsMilliseconds.length >= 2) {
      double squaredDifferences = 0;
      for (int index = 1; index < _rrIntervalsMilliseconds.length; index++) {
        final double difference =
            _rrIntervalsMilliseconds[index] -
            _rrIntervalsMilliseconds[index - 1];
        squaredDifferences += difference * difference;
      }
      intervalRmssd = math.sqrt(
        squaredDifferences / (_rrIntervalsMilliseconds.length - 1),
      );
    }
    return HeartRateVariabilityStats(
      sdnnMilliseconds: intervalSdnn ?? reportedSdnn,
      rmssdMilliseconds: intervalRmssd ?? _mean(_reportedRmssdMilliseconds),
      heartRateStandardDeviationBpm: heartRateStandardDeviation,
      sampleCount: math.max(
        _heartRates.length,
        math.max(
          _rrIntervalsMilliseconds.length,
          math.max(
            _reportedSdnnMilliseconds.length,
            _reportedRmssdMilliseconds.length,
          ),
        ),
      ),
    );
  }

  HeartRateRecoveryStats get recovery => HeartRateRecoveryStats(
    baselineBpm: _recoveryBaselineBpm,
    oneMinuteBpm: _recoveryOneMinuteBpm,
    twoMinuteBpm: _recoveryTwoMinuteBpm,
    currentBpm: _recoveryCurrentBpm,
  );

  void reset() {
    for (final HeartRateZone zone in _zoneDurations.keys) {
      _zoneDurations[zone] = Duration.zero;
    }
    _heartRates.clear();
    _rrIntervalsMilliseconds.clear();
    _reportedSdnnMilliseconds.clear();
    _reportedRmssdMilliseconds.clear();
    _lastSampleAt = null;
    _currentZone = HeartRateZone.unknown;
    _isActive = false;
    _latestHeartRate = null;
    _maximumObservedHeartRate = 0;
    _recoveryStartedAt = null;
    _recoveryBaselineBpm = null;
    _recoveryOneMinuteBpm = null;
    _recoveryTwoMinuteBpm = null;
    _recoveryCurrentBpm = null;
  }

  void dispose() {
    unawaited(_transitionController.close());
  }

  void _accumulateCurrentZone(Duration elapsed) {
    if (_currentZone == HeartRateZone.unknown || elapsed <= Duration.zero) {
      return;
    }
    final Duration credited = elapsed > maximumSampleGap
        ? maximumSampleGap
        : elapsed;
    _zoneDurations[_currentZone] =
        (_zoneDurations[_currentZone] ?? Duration.zero) + credited;
  }

  void _recordRecoverySample(int bpm, DateTime timestamp) {
    final DateTime? startedAt = _recoveryStartedAt;
    if (startedAt == null || timestamp.isBefore(startedAt)) {
      return;
    }
    _recoveryCurrentBpm = bpm;
    final Duration elapsed = timestamp.difference(startedAt);
    if (elapsed >= const Duration(minutes: 1) &&
        _recoveryOneMinuteBpm == null) {
      _recoveryOneMinuteBpm = bpm;
    }
    if (elapsed >= const Duration(minutes: 2) &&
        _recoveryTwoMinuteBpm == null) {
      _recoveryTwoMinuteBpm = bpm;
    }
  }

  static double? _mean(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  static double? _standardDeviation(List<double> values) {
    if (values.length < 2) {
      return null;
    }
    final double mean = _mean(values)!;
    double squaredDifferences = 0;
    for (final double value in values) {
      final double difference = value - mean;
      squaredDifferences += difference * difference;
    }
    return math.sqrt(squaredDifferences / (values.length - 1));
  }

  static int _validatedMax(int value) {
    if (value < 100 || value > 240) {
      throw RangeError.range(value, 100, 240, 'estimatedMaxHeartRate');
    }
    return value;
  }
}
