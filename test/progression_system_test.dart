import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/screens/achievements_screen.dart';
import 'package:cardio_quest/services/achievement_service.dart';
import 'package:cardio_quest/services/challenge_service.dart';
import 'package:cardio_quest/services/cosmetics_service.dart';
import 'package:cardio_quest/services/player_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('summary XP uses meters, coins, combo, and obstacle clears', () {
    const GameSummary summary = GameSummary(
      duration: Duration(minutes: 12),
      distanceMeters: 1234,
      averageSpeedKph: 8,
      maxSpeedKph: 12,
      coins: 40,
      score: 1000,
      maxCombo: 5,
      obstaclesCleared: 7,
    );

    expect(summary.distanceXp, 1234);
    expect(summary.coinXp, 200);
    expect(summary.comboBonusXp, 300);
    expect(summary.obstacleClearXp, 210);
    expect(summary.earnedXp, 1944);
  });

  test(
    'level requirements grow exponentially and every level has a reward',
    () {
      int previousRequirement = 0;
      int previousStep = 0;
      for (int level = 2; level <= 20; level++) {
        final int requirement = PlayerProfile.xpForLevelStart(level);
        final int step = requirement - previousRequirement;
        expect(requirement, greaterThan(previousRequirement));
        if (level > 2) {
          expect(step, greaterThan(previousStep));
        }
        expect(PlayerProfile.rewardForLevel(level).name, isNotEmpty);
        previousRequirement = requirement;
        previousStep = step;
      }
    },
  );

  test(
    'profile awards once and achievement checks unlock matching tiers',
    () async {
      final PlayerProfile profile = PlayerProfile.instance;
      final AchievementService achievements = AchievementService.instance;
      await profile.initialize();
      await achievements.initialize();

      const GameSummary summary = GameSummary(
        duration: Duration(minutes: 15),
        distanceMeters: 1200,
        averageSpeedKph: 8,
        maxSpeedKph: 12,
        coins: 110,
        score: 1000,
        maxCombo: 3,
        obstaclesCleared: 4,
        maxHeartRateBpm: 155,
        activeEnergyCalories: 120,
        heartRateZoneDurations: <HeartRateZone, Duration>{
          HeartRateZone.tempo: Duration(minutes: 10),
        },
      );
      final ProfileWorkoutResult result = await profile.recordWorkout(
        workoutId: 'progression-test-workout',
        summary: summary,
        machineKind: MachineKind.treadmill,
        endedAt: DateTime.utc(2026, 7, 23, 7),
      );
      final ProfileWorkoutResult duplicate = await profile.recordWorkout(
        workoutId: 'progression-test-workout',
        summary: summary,
        machineKind: MachineKind.treadmill,
        endedAt: DateTime.utc(2026, 7, 23, 7),
      );
      final AchievementCheckResult checked = await achievements
          .checkAchievements(profile, now: DateTime.utc(2026, 7, 23, 7, 1));

      expect(result.xp.dailyBonus, PlayerProfile.dailyWorkoutBonusXp);
      expect(result.xp.workoutXp, summary.earnedXp);
      expect(duplicate.wasAlreadyProcessed, isTrue);
      expect(profile.totalWorkouts, 1);
      expect(
        checked.unlocked.map((AchievementUnlock item) => item.definition.id),
        containsAll(<String>[
          'distance_1k',
          'speed_10',
          'combo_3x',
          'coins_100',
          'heart_150',
          'calories_100',
          'zone_tempo_10m',
        ]),
      );
    },
  );

  test(
    'challenge service creates three daily and two weekly challenges',
    () async {
      final ChallengeService challenges = ChallengeService.instance;
      await challenges.initialize(now: DateTime.utc(2026, 7, 23, 12));

      expect(
        challenges.activeChallenges
            .where(
              (ChallengeProgress item) =>
                  item.definition.cadence == ChallengeCadence.daily,
            )
            .length,
        3,
      );
      expect(
        challenges.activeChallenges
            .where(
              (ChallengeProgress item) =>
                  item.definition.cadence == ChallengeCadence.weekly,
            )
            .length,
        2,
      );
      expect(
        CosmeticsService.definitions
            .where((CosmeticDefinition item) => item.challengeExclusive)
            .map((CosmeticDefinition item) => item.id),
        containsAll(<String>['trail_comet', 'background_aurora']),
      );
    },
  );

  testWidgets('achievement screen renders progress, filters, and challenges', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AchievementsScreen()));
    await tester.pump();

    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('ACTIVE CHALLENGES'), findsOneWidget);
    expect(find.text('First Kilometer'), findsOneWidget);
    final Object? exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? exception.toStringDeep()
          : '$exception',
    );
  });
}
