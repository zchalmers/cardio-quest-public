import 'package:flutter/foundation.dart';

enum WorkoutState {
  disconnected,
  connecting,
  connectedIdle,
  running,
  paused,
  complete,
}

enum MachineKind {
  treadmill,
  indoorBike,
  crossTrainer,
  rower,
  unknown,
  simulator,
}

enum MotionMode { walk, jog, sprint }

enum PowerUpType { magnet, shield, doubleCoins }

enum HeartRateZone { recovery, aerobic, tempo, threshold, peak, unknown }

enum HeartRateSource { none, machine, wearable, simulated }

@immutable
class MachineDevice {
  const MachineDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.kind = MachineKind.unknown,
  });

  final String id;
  final String name;
  final int rssi;
  final MachineKind kind;

  MachineDevice copyWith({String? name, int? rssi, MachineKind? kind}) {
    return MachineDevice(
      id: id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      kind: kind ?? this.kind,
    );
  }
}

@immutable
class MachineMetrics {
  const MachineMetrics({
    this.speedKph = 0,
    this.inclinePercent = 0,
    this.cadenceRpm = 0,
    this.totalDistanceMeters = 0,
    this.heartRateBpm = 0,
    this.heartRateSource = HeartRateSource.none,
    this.heartRateRecordedAt,
    this.restingHeartRateBpm,
    this.activeEnergyCalories,
    this.stepCount,
    this.hrvSdnnMilliseconds,
    this.hrvRmssdMilliseconds,
    this.wearableDataAvailable = false,
    this.receivedAt,
    this.isSimulated = false,
  });

  final double speedKph;
  final double inclinePercent;
  final double cadenceRpm;
  final double totalDistanceMeters;
  final int heartRateBpm;
  final HeartRateSource heartRateSource;
  final DateTime? heartRateRecordedAt;
  final int? restingHeartRateBpm;
  final double? activeEnergyCalories;
  final int? stepCount;
  final double? hrvSdnnMilliseconds;
  final double? hrvRmssdMilliseconds;
  final bool wearableDataAvailable;
  final DateTime? receivedAt;
  final bool isSimulated;

  bool get isFresh =>
      receivedAt != null &&
      DateTime.now().difference(receivedAt!).inSeconds < 3;

  MachineMetrics copyWith({
    double? speedKph,
    double? inclinePercent,
    double? cadenceRpm,
    double? totalDistanceMeters,
    int? heartRateBpm,
    HeartRateSource? heartRateSource,
    DateTime? heartRateRecordedAt,
    int? restingHeartRateBpm,
    double? activeEnergyCalories,
    int? stepCount,
    double? hrvSdnnMilliseconds,
    double? hrvRmssdMilliseconds,
    bool? wearableDataAvailable,
    DateTime? receivedAt,
    bool? isSimulated,
  }) {
    return MachineMetrics(
      speedKph: speedKph ?? this.speedKph,
      inclinePercent: inclinePercent ?? this.inclinePercent,
      cadenceRpm: cadenceRpm ?? this.cadenceRpm,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      heartRateSource: heartRateSource ?? this.heartRateSource,
      heartRateRecordedAt: heartRateRecordedAt ?? this.heartRateRecordedAt,
      restingHeartRateBpm: restingHeartRateBpm ?? this.restingHeartRateBpm,
      activeEnergyCalories: activeEnergyCalories ?? this.activeEnergyCalories,
      stepCount: stepCount ?? this.stepCount,
      hrvSdnnMilliseconds: hrvSdnnMilliseconds ?? this.hrvSdnnMilliseconds,
      hrvRmssdMilliseconds: hrvRmssdMilliseconds ?? this.hrvRmssdMilliseconds,
      wearableDataAvailable:
          wearableDataAvailable ?? this.wearableDataAvailable,
      receivedAt: receivedAt ?? this.receivedAt,
      isSimulated: isSimulated ?? this.isSimulated,
    );
  }
}

@immutable
class WearableMetrics {
  const WearableMetrics({
    this.heartRateBpm,
    this.heartRateRecordedAt,
    this.restingHeartRateBpm,
    this.activeEnergyCalories,
    this.stepCount,
    this.hrvSdnnMilliseconds,
    this.hrvRmssdMilliseconds,
    required this.sampledAt,
  });

  final int? heartRateBpm;
  final DateTime? heartRateRecordedAt;
  final int? restingHeartRateBpm;
  final double? activeEnergyCalories;
  final int? stepCount;
  final double? hrvSdnnMilliseconds;
  final double? hrvRmssdMilliseconds;
  final DateTime sampledAt;

  bool get hasData =>
      heartRateBpm != null ||
      restingHeartRateBpm != null ||
      activeEnergyCalories != null ||
      stepCount != null ||
      hrvSdnnMilliseconds != null ||
      hrvRmssdMilliseconds != null;

  bool hasFreshHeartRate(
    DateTime referenceTime, {
    Duration maximumAge = const Duration(seconds: 15),
  }) {
    final DateTime? recordedAt = heartRateRecordedAt;
    final int? bpm = heartRateBpm;
    if (recordedAt == null || bpm == null || bpm < 25 || bpm > 250) {
      return false;
    }
    final Duration age = referenceTime.difference(recordedAt);
    return age >= Duration.zero && age <= maximumAge;
  }
}

@immutable
class WorkoutMetricSample {
  const WorkoutMetricSample({
    required this.recordedAt,
    required this.elapsed,
    required this.speedKph,
    required this.inclinePercent,
    required this.distanceMeters,
    required this.heartRateBpm,
    required this.heartRateSource,
    this.activeEnergyCalories,
  });

  final DateTime recordedAt;
  final Duration elapsed;
  final double speedKph;
  final double inclinePercent;
  final double distanceMeters;
  final int heartRateBpm;
  final HeartRateSource heartRateSource;
  final double? activeEnergyCalories;
}

@immutable
class HeartRateVariabilityStats {
  const HeartRateVariabilityStats({
    this.sdnnMilliseconds,
    this.rmssdMilliseconds,
    this.heartRateStandardDeviationBpm,
    this.sampleCount = 0,
  });

  final double? sdnnMilliseconds;
  final double? rmssdMilliseconds;
  final double? heartRateStandardDeviationBpm;
  final int sampleCount;
}

@immutable
class HeartRateRecoveryStats {
  const HeartRateRecoveryStats({
    this.baselineBpm,
    this.oneMinuteBpm,
    this.twoMinuteBpm,
    this.currentBpm,
  });

  final int? baselineBpm;
  final int? oneMinuteBpm;
  final int? twoMinuteBpm;
  final int? currentBpm;

  int? get oneMinuteDrop => _dropTo(oneMinuteBpm);
  int? get twoMinuteDrop => _dropTo(twoMinuteBpm);
  int? get currentDrop => _dropTo(currentBpm);

  int? _dropTo(int? recoveredBpm) {
    final int? baseline = baselineBpm;
    if (baseline == null || recoveredBpm == null) {
      return null;
    }
    return baseline - recoveredBpm;
  }
}

@immutable
class GameSummary {
  const GameSummary({
    required this.duration,
    required this.distanceMeters,
    required this.averageSpeedKph,
    required this.maxSpeedKph,
    required this.coins,
    required this.score,
    required this.maxCombo,
    required this.obstaclesCleared,
    this.averageHeartRateBpm = 0,
    this.maxHeartRateBpm = 0,
    this.restingHeartRateBpm,
    this.activeEnergyCalories = 0,
    this.workoutStepCount = 0,
    this.heartRateZoneDurations = const <HeartRateZone, Duration>{},
    this.heartRateVariability = const HeartRateVariabilityStats(),
    this.heartRateRecovery = const HeartRateRecoveryStats(),
    this.usedWearableData = false,
    this.wearableHeartRateSampleCount = 0,
    this.metricSamples = const <WorkoutMetricSample>[],
  });

  final Duration duration;
  final double distanceMeters;
  final double averageSpeedKph;
  final double maxSpeedKph;
  final int coins;
  final int score;
  final double maxCombo;
  final int obstaclesCleared;
  final int averageHeartRateBpm;
  final int maxHeartRateBpm;
  final int? restingHeartRateBpm;
  final double activeEnergyCalories;
  final int workoutStepCount;
  final Map<HeartRateZone, Duration> heartRateZoneDurations;
  final HeartRateVariabilityStats heartRateVariability;
  final HeartRateRecoveryStats heartRateRecovery;
  final bool usedWearableData;
  final int wearableHeartRateSampleCount;
  final List<WorkoutMetricSample> metricSamples;

  /// Session XP is deterministic so the summary, profile, and tests always
  /// agree. The once-per-day bonus is applied by [PlayerProfile].
  int get distanceXp => distanceMeters.round();
  int get coinXp => coins * 5;
  int get comboBonusXp => ((maxCombo - 1).clamp(0, 100) * 75).round();
  int get obstacleClearXp => obstaclesCleared * 30;
  int get earnedXp => distanceXp + coinXp + comboBonusXp + obstacleClearXp;
}

MotionMode motionModeFor(double speedKph) {
  if (speedKph < 3) {
    return MotionMode.walk;
  }
  if (speedKph < 8) {
    return MotionMode.jog;
  }
  return MotionMode.sprint;
}

HeartRateZone heartRateZoneFor(int bpm, {int estimatedMax = 190}) {
  if (bpm <= 0) {
    return HeartRateZone.unknown;
  }
  final double ratio = bpm / estimatedMax;
  if (ratio < 0.6) {
    return HeartRateZone.recovery;
  }
  if (ratio < 0.7) {
    return HeartRateZone.aerobic;
  }
  if (ratio < 0.8) {
    return HeartRateZone.tempo;
  }
  if (ratio < 0.9) {
    return HeartRateZone.threshold;
  }
  return HeartRateZone.peak;
}
