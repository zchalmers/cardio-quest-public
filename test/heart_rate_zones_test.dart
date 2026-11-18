import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/services/heart_rate_zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('maximum heart rate formulas', () {
    test('calculates Fox, Tanaka, and Gulati estimates', () {
      expect(
        HeartRateZoneEngine.calculateMaxHeartRate(
          age: 40,
          formula: MaxHeartRateFormula.fox,
        ),
        180,
      );
      expect(
        HeartRateZoneEngine.calculateMaxHeartRate(
          age: 40,
          formula: MaxHeartRateFormula.tanaka,
        ),
        180,
      );
      expect(
        HeartRateZoneEngine.calculateMaxHeartRate(
          age: 40,
          formula: MaxHeartRateFormula.gulati,
        ),
        171,
      );
    });

    test('uses Gulati by default for a female profile', () {
      const HeartRateProfile profile = HeartRateProfile(
        age: 40,
        sex: HeartRateProfileSex.female,
      );

      expect(profile.effectiveFormula, MaxHeartRateFormula.gulati);
      expect(profile.estimatedMaxHeartRate, 171);
    });
  });

  test('tracks zones and emits transitions', () async {
    final HeartRateZoneEngine engine = HeartRateZoneEngine(
      estimatedMaxHeartRate: 200,
    );
    final List<HeartRateZoneTransition> transitions =
        <HeartRateZoneTransition>[];
    final subscription = engine.transitions.listen(transitions.add);
    final DateTime start = DateTime.utc(2026, 1, 1, 12);

    engine.start(at: start);
    engine
      ..addSample(100, at: start)
      ..addSample(130, at: start.add(const Duration(seconds: 10)))
      ..addSample(150, at: start.add(const Duration(seconds: 30)))
      ..finish(at: start.add(const Duration(seconds: 40)));

    expect(
      engine.zoneDurations[HeartRateZone.recovery],
      const Duration(seconds: 10),
    );
    expect(
      engine.zoneDurations[HeartRateZone.aerobic],
      const Duration(seconds: 20),
    );
    expect(
      engine.zoneDurations[HeartRateZone.tempo],
      const Duration(seconds: 10),
    );
    expect(
      transitions.map((HeartRateZoneTransition event) => event.enteredZone),
      <HeartRateZone>[
        HeartRateZone.recovery,
        HeartRateZone.aerobic,
        HeartRateZone.tempo,
      ],
    );
    expect(transitions[1].leftZone, HeartRateZone.recovery);

    await subscription.cancel();
    engine.dispose();
  });

  test('tracks beat-level variability and recovery', () {
    final HeartRateZoneEngine engine = HeartRateZoneEngine(
      estimatedMaxHeartRate: 190,
    );
    final DateTime start = DateTime.utc(2026, 1, 1, 12);

    engine.start(at: start);
    engine
      ..addSample(170, at: start)
      ..addRrInterval(800)
      ..addRrInterval(820)
      ..addRrInterval(790)
      ..beginRecovery(at: start, baselineBpm: 170)
      ..addSample(145, at: start.add(const Duration(minutes: 1)))
      ..addSample(130, at: start.add(const Duration(minutes: 2)));

    expect(engine.variability.rmssdMilliseconds, isNotNull);
    expect(engine.variability.sdnnMilliseconds, isNotNull);
    expect(engine.recovery.oneMinuteDrop, 25);
    expect(engine.recovery.twoMinuteDrop, 40);

    engine.dispose();
  });
}
