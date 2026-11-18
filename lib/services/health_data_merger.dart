import 'dart:async';

import '../models/machine_models.dart';

/// Aligns FTMS metrics with wearable samples and emits the best unified view.
class HealthDataMerger {
  HealthDataMerger({
    this.maximumWearableHeartRateAge = const Duration(seconds: 15),
    this.timestampAlignmentTolerance = const Duration(seconds: 30),
  });

  final Duration maximumWearableHeartRateAge;
  final Duration timestampAlignmentTolerance;
  final StreamController<MachineMetrics> _controller =
      StreamController<MachineMetrics>.broadcast(sync: true);

  MachineMetrics _machineMetrics = const MachineMetrics();
  WearableMetrics? _wearableMetrics;
  MachineMetrics _unifiedMetrics = const MachineMetrics();
  bool _disposed = false;

  Stream<MachineMetrics> get metricsStream => _controller.stream;
  MachineMetrics get current => _unifiedMetrics;

  void addMachineMetrics(MachineMetrics metrics) {
    if (_disposed) {
      return;
    }
    _machineMetrics = metrics;
    _publish();
  }

  void addWearableMetrics(WearableMetrics metrics) {
    if (_disposed) {
      return;
    }
    _wearableMetrics = metrics;
    _publish();
  }

  MachineMetrics merge({
    required MachineMetrics machine,
    WearableMetrics? wearable,
    DateTime? referenceTime,
  }) {
    final DateTime now = referenceTime ?? DateTime.now();
    final DateTime alignmentReference = machine.receivedAt ?? now;
    final bool wearableHeartRateIsFresh =
        wearable?.hasFreshHeartRate(
          now,
          maximumAge: maximumWearableHeartRateAge,
        ) ??
        false;
    final DateTime? wearableHeartRateAt = wearable?.heartRateRecordedAt;
    final bool timestampsAlign =
        wearableHeartRateAt != null &&
        _absoluteDifference(alignmentReference, wearableHeartRateAt) <=
            timestampAlignmentTolerance;
    final bool machineHeartRateIsValid =
        machine.heartRateBpm >= 25 && machine.heartRateBpm <= 250;
    final DateTime? machineReceivedAt = machine.receivedAt;
    final bool machineDataIsFresh =
        machineReceivedAt != null &&
        !now.isBefore(machineReceivedAt) &&
        now.difference(machineReceivedAt) <= maximumWearableHeartRateAge;
    final bool useWearableHeartRate =
        wearableHeartRateIsFresh &&
        (timestampsAlign || !machineHeartRateIsValid || !machineDataIsFresh);

    final int heartRateBpm = useWearableHeartRate
        ? wearable!.heartRateBpm!
        : machineHeartRateIsValid
        ? machine.heartRateBpm
        : 0;
    final HeartRateSource heartRateSource = useWearableHeartRate
        ? HeartRateSource.wearable
        : machineHeartRateIsValid
        ? machine.isSimulated
              ? HeartRateSource.simulated
              : HeartRateSource.machine
        : HeartRateSource.none;

    return MachineMetrics(
      speedKph: machine.speedKph,
      inclinePercent: machine.inclinePercent,
      cadenceRpm: machine.cadenceRpm,
      totalDistanceMeters: machine.totalDistanceMeters,
      heartRateBpm: heartRateBpm,
      heartRateSource: heartRateSource,
      heartRateRecordedAt: useWearableHeartRate
          ? wearableHeartRateAt
          : machine.heartRateRecordedAt ?? machine.receivedAt,
      restingHeartRateBpm: wearable?.restingHeartRateBpm,
      activeEnergyCalories: wearable?.activeEnergyCalories,
      stepCount: wearable?.stepCount,
      hrvSdnnMilliseconds: wearable?.hrvSdnnMilliseconds,
      hrvRmssdMilliseconds: wearable?.hrvRmssdMilliseconds,
      wearableDataAvailable: wearable?.hasData ?? false,
      // Wearable updates must not make stale machine speed appear fresh.
      receivedAt: machine.receivedAt,
      isSimulated: machine.isSimulated,
    );
  }

  void reset() {
    if (_disposed) {
      return;
    }
    _machineMetrics = const MachineMetrics();
    _wearableMetrics = null;
    _unifiedMetrics = const MachineMetrics();
    _controller.add(_unifiedMetrics);
  }

  void _publish() {
    _unifiedMetrics = merge(
      machine: _machineMetrics,
      wearable: _wearableMetrics,
    );
    _controller.add(_unifiedMetrics);
  }

  Duration _absoluteDifference(DateTime first, DateTime second) {
    final Duration difference = first.difference(second);
    return difference.isNegative ? -difference : difference;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_controller.close());
  }
}
