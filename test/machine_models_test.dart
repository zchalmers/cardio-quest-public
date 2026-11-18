import 'package:cardio_quest/models/machine_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('motionModeFor', () {
    test('uses the requested walk, jog, and sprint boundaries', () {
      expect(motionModeFor(0), MotionMode.walk);
      expect(motionModeFor(2.99), MotionMode.walk);
      expect(motionModeFor(3), MotionMode.jog);
      expect(motionModeFor(7.99), MotionMode.jog);
      expect(motionModeFor(8), MotionMode.sprint);
      expect(motionModeFor(15), MotionMode.sprint);
    });
  });

  group('heartRateZoneFor', () {
    test('handles missing and progressive zones', () {
      expect(heartRateZoneFor(0), HeartRateZone.unknown);
      expect(heartRateZoneFor(100, estimatedMax: 200), HeartRateZone.recovery);
      expect(heartRateZoneFor(130, estimatedMax: 200), HeartRateZone.aerobic);
      expect(heartRateZoneFor(150, estimatedMax: 200), HeartRateZone.tempo);
      expect(heartRateZoneFor(170, estimatedMax: 200), HeartRateZone.threshold);
      expect(heartRateZoneFor(190, estimatedMax: 200), HeartRateZone.peak);
    });
  });

  test('machine metrics copyWith preserves untouched data', () {
    const MachineMetrics original = MachineMetrics(
      speedKph: 7.2,
      inclinePercent: 3,
      totalDistanceMeters: 420,
      heartRateBpm: 142,
    );

    final MachineMetrics changed = original.copyWith(speedKph: 8.1);

    expect(changed.speedKph, 8.1);
    expect(changed.inclinePercent, 3);
    expect(changed.totalDistanceMeters, 420);
    expect(changed.heartRateBpm, 142);
  });
}
