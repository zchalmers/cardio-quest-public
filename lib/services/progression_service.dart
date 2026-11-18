import 'package:flutter/foundation.dart';

import '../models/machine_models.dart';
import 'achievement_service.dart';
import 'challenge_service.dart';
import 'cosmetics_service.dart';
import 'player_profile.dart';

@immutable
class SessionProgressionResult {
  const SessionProgressionResult({
    required this.profile,
    required this.achievements,
    required this.completedChallenges,
    required this.unlockedCosmetics,
  });

  final ProfileWorkoutResult profile;
  final AchievementCheckResult achievements;
  final List<ChallengeCompletion> completedChallenges;
  final List<CosmeticDefinition> unlockedCosmetics;

  int get challengeXp => completedChallenges.fold<int>(
    0,
    (int total, ChallengeCompletion completion) =>
        total +
        completion.definition.rewards
            .where(
              (ChallengeReward reward) =>
                  reward.type == ChallengeRewardType.bonusXp,
            )
            .fold<int>(
              0,
              (int subtotal, ChallengeReward reward) =>
                  subtotal + reward.amount,
            ),
  );
}

/// Coordinates the write order for a completed workout.
///
/// Profile totals update first, then challenges resolve, achievement conditions
/// run against the new totals, and finally cosmetic rewards are synchronized.
class ProgressionService {
  ProgressionService._();

  static final ProgressionService instance = ProgressionService._();

  final Map<String, SessionProgressionResult> _completedSessions =
      <String, SessionProgressionResult>{};

  Future<void> beginWorkout(String workoutId) =>
      ChallengeService.instance.beginWorkout(workoutId);

  Future<SessionProgressionResult> completeWorkout({
    required String workoutId,
    required GameSummary summary,
    required MachineKind machineKind,
    required DateTime endedAt,
    bool multiplayerWin = false,
  }) async {
    final SessionProgressionResult? cached = _completedSessions[workoutId];
    if (cached != null) {
      return cached;
    }

    final PlayerProfile profile = PlayerProfile.instance;
    final ProfileWorkoutResult profileResult = await profile.recordWorkout(
      workoutId: workoutId,
      summary: summary,
      machineKind: machineKind,
      endedAt: endedAt,
      multiplayerWin: multiplayerWin,
    );
    final List<ChallengeCompletion> challenges =
        profileResult.wasAlreadyProcessed
        ? const <ChallengeCompletion>[]
        : await ChallengeService.instance.finishWorkout(
            ChallengeWorkoutSnapshot(
              distanceMeters: summary.distanceMeters,
              maxSpeedKph: summary.maxSpeedKph,
              coins: summary.coins,
              maxCombo: summary.maxCombo,
              zoneDurations: summary.heartRateZoneDurations,
              currentStreak: profile.currentStreak,
            ),
          );
    final AchievementCheckResult achievementResult = await AchievementService
        .instance
        .checkAchievements(profile, now: endedAt);
    final List<CosmeticDefinition> cosmetics = await CosmeticsService.instance
        .syncUnlocks(profile, AchievementService.instance);
    final SessionProgressionResult result = SessionProgressionResult(
      profile: profileResult,
      achievements: achievementResult,
      completedChallenges: challenges,
      unlockedCosmetics: cosmetics,
    );
    _completedSessions[workoutId] = result;
    if (_completedSessions.length > 20) {
      _completedSessions.remove(_completedSessions.keys.first);
    }
    return result;
  }
}
