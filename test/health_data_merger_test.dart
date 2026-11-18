import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/services/health_data_merger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 1, 1, 12);

  test('prefers fresh aligned wearable heart rate', () {
    final HealthDataMerger merger = HealthDataMerger();
    final MachineMetrics result = merger.merge(
      machine: MachineMetrics(speedKph: 8, heartRateBpm: 121, receivedAt: now),
      wearable: WearableMetrics(
        heartRateBpm: 146,
        heartRateRecordedAt: now.subtract(const Duration(seconds: 1)),
        restingHeartRateBpm: 58,
        activeEnergyCalories: 320,
        stepCount: 4500,
        sampledAt: now,
      ),
      referenceTime: now,
    );

    expect(result.speedKph, 8);
    expect(result.heartRateBpm, 146);
    expect(result.heartRateSource, HeartRateSource.wearable);
    expect(result.restingHeartRateBpm, 58);
    expect(result.wearableDataAvailable, isTrue);
    merger.dispose();
  });

  test('falls back to FTMS when wearable heart rate is stale', () {
    final HealthDataMerger merger = HealthDataMerger();
    final MachineMetrics result = merger.merge(
      machine: MachineMetrics(heartRateBpm: 128, receivedAt: now),
      wearable: WearableMetrics(
        heartRateBpm: 150,
        heartRateRecordedAt: now.subtract(const Duration(minutes: 1)),
        sampledAt: now,
      ),
      referenceTime: now,
    );

    expect(result.heartRateBpm, 128);
    expect(result.heartRateSource, HeartRateSource.machine);
    merger.dispose();
  });

  test('wearable updates do not make machine motion data fresh', () {
    final HealthDataMerger merger = HealthDataMerger();
    final DateTime oldMachineTime = now.subtract(const Duration(minutes: 1));
    final MachineMetrics result = merger.merge(
      machine: MachineMetrics(speedKph: 7, receivedAt: oldMachineTime),
      wearable: WearableMetrics(
        heartRateBpm: 140,
        heartRateRecordedAt: now,
        sampledAt: now,
      ),
      referenceTime: now,
    );

    expect(result.receivedAt, oldMachineTime);
    expect(result.isFresh, isFalse);
    merger.dispose();
  });

  test('fresh wearable heart rate replaces stale machine heart rate', () {
    final HealthDataMerger merger = HealthDataMerger();
    final DateTime oldMachineTime = now.subtract(const Duration(minutes: 1));
    final MachineMetrics result = merger.merge(
      machine: MachineMetrics(heartRateBpm: 120, receivedAt: oldMachineTime),
      wearable: WearableMetrics(
        heartRateBpm: 141,
        heartRateRecordedAt: now,
        sampledAt: now,
      ),
      referenceTime: now,
    );

    expect(result.heartRateBpm, 141);
    expect(result.heartRateSource, HeartRateSource.wearable);
    merger.dispose();
  });
}
