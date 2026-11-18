import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine_models.dart';
import 'player_profile.dart';

enum AchievementCategory {
  distance,
  speed,
  combo,
  zones,
  consistency,
  coins,
  multiplayer,
  heartRate,
  calories,
  variety,
  lifestyle,
}

enum AchievementTier { bronze, silver, gold, platinum, legendary }

enum AchievementMetric {
  totalDistanceMeters,
  bestSpeedKph,
  bestCombo,
  tempoSeconds,
  thresholdSeconds,
  peakSeconds,
  longestStreak,
  totalCoins,
  multiplayerWins,
  maximumHeartRate,
  totalCalories,
  machineVariety,
  earlyWorkouts,
  lateWorkouts,
  longestSessionMeters,
}

@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.category,
    required this.tier,
    required this.metric,
    required this.target,
    required this.unit,
  });

  final String id;
  final IconData icon;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final AchievementMetric metric;
  final double target;
  final String unit;
}

@immutable
class AchievementProgress {
  const AchievementProgress({
    required this.definition,
    required this.value,
    required this.unlockedAt,
  });

  final AchievementDefinition definition;
  final double value;
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;
  double get fraction => (value / definition.target).clamp(0, 1).toDouble();
  double get remaining => math.max(0, definition.target - value);
}

@immutable
class AchievementUnlock {
  const AchievementUnlock({required this.definition, required this.unlockedAt});

  final AchievementDefinition definition;
  final DateTime unlockedAt;
}

@immutable
class NearlyCompleteAchievement {
  const NearlyCompleteAchievement({required this.progress});

  final AchievementProgress progress;
}

@immutable
class AchievementCheckResult {
  const AchievementCheckResult({
    this.unlocked = const <AchievementUnlock>[],
    this.nearlyComplete = const <NearlyCompleteAchievement>[],
  });

  final List<AchievementUnlock> unlocked;
  final List<NearlyCompleteAchievement> nearlyComplete;
}

class AchievementService extends ChangeNotifier {
  AchievementService._();

  static final AchievementService instance = AchievementService._();
  static const String _storageKey = 'cardio_quest.achievements.v1';

  SharedPreferences? _preferences;
  bool _initialized = false;
  final Map<String, DateTime> _unlockedAt = <String, DateTime>{};
  final Set<String> _nearCompletionNotified = <String>{};
  final Map<AchievementCategory, double> _categoryBoosts =
      <AchievementCategory, double>{};

  static const List<AchievementDefinition> definitions =
      <AchievementDefinition>[
        AchievementDefinition(
          id: 'distance_1k',
          icon: Icons.route_rounded,
          name: 'First Kilometer',
          description: 'Travel 1 km across all quests',
          category: AchievementCategory.distance,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.totalDistanceMeters,
          target: 1000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_5k',
          icon: Icons.signpost_rounded,
          name: 'Trail Taster',
          description: 'Travel 5 km across all quests',
          category: AchievementCategory.distance,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.totalDistanceMeters,
          target: 5000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_10k',
          icon: Icons.landscape_rounded,
          name: 'Ten K Trekker',
          description: 'Travel 10 km across all quests',
          category: AchievementCategory.distance,
          tier: AchievementTier.silver,
          metric: AchievementMetric.totalDistanceMeters,
          target: 10000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_21k',
          icon: Icons.terrain_rounded,
          name: 'Halfway Hero',
          description: 'Travel a cumulative half marathon',
          category: AchievementCategory.distance,
          tier: AchievementTier.silver,
          metric: AchievementMetric.totalDistanceMeters,
          target: 21000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_42k',
          icon: Icons.emoji_events_rounded,
          name: 'Marathon Spirit',
          description: 'Travel a cumulative marathon',
          category: AchievementCategory.distance,
          tier: AchievementTier.gold,
          metric: AchievementMetric.totalDistanceMeters,
          target: 42000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_100k',
          icon: Icons.map_rounded,
          name: 'Century Voyager',
          description: 'Travel 100 km across all quests',
          category: AchievementCategory.distance,
          tier: AchievementTier.gold,
          metric: AchievementMetric.totalDistanceMeters,
          target: 100000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_500k',
          icon: Icons.public_rounded,
          name: 'World Walker',
          description: 'Travel 500 km across all quests',
          category: AchievementCategory.distance,
          tier: AchievementTier.platinum,
          metric: AchievementMetric.totalDistanceMeters,
          target: 500000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'distance_1000k',
          icon: Icons.auto_awesome_rounded,
          name: 'Million Meter Legend',
          description: 'Travel 1,000 km across all quests',
          category: AchievementCategory.distance,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.totalDistanceMeters,
          target: 1000000,
          unit: 'm',
        ),
        AchievementDefinition(
          id: 'speed_10',
          icon: Icons.speed_rounded,
          name: 'Quick Step',
          description: 'Hit 10 km/h in a workout',
          category: AchievementCategory.speed,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.bestSpeedKph,
          target: 10,
          unit: 'km/h',
        ),
        AchievementDefinition(
          id: 'speed_15',
          icon: Icons.bolt_rounded,
          name: 'Velocity',
          description: 'Hit 15 km/h in a workout',
          category: AchievementCategory.speed,
          tier: AchievementTier.gold,
          metric: AchievementMetric.bestSpeedKph,
          target: 15,
          unit: 'km/h',
        ),
        AchievementDefinition(
          id: 'speed_20',
          icon: Icons.rocket_launch_rounded,
          name: 'Mach Cardio',
          description: 'Hit 20 km/h in a workout',
          category: AchievementCategory.speed,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.bestSpeedKph,
          target: 20,
          unit: 'km/h',
        ),
        AchievementDefinition(
          id: 'combo_3x',
          icon: Icons.local_fire_department_rounded,
          name: 'Rhythm Found',
          description: 'Reach a 3× combo',
          category: AchievementCategory.combo,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.bestCombo,
          target: 3,
          unit: '×',
        ),
        AchievementDefinition(
          id: 'combo_5x',
          icon: Icons.whatshot_rounded,
          name: 'Combo Master',
          description: 'Reach a 5× combo',
          category: AchievementCategory.combo,
          tier: AchievementTier.silver,
          metric: AchievementMetric.bestCombo,
          target: 5,
          unit: '×',
        ),
        AchievementDefinition(
          id: 'combo_10x',
          icon: Icons.flash_on_rounded,
          name: 'Unbroken Flow',
          description: 'Reach a 10× combo',
          category: AchievementCategory.combo,
          tier: AchievementTier.gold,
          metric: AchievementMetric.bestCombo,
          target: 10,
          unit: '×',
        ),
        AchievementDefinition(
          id: 'combo_20x',
          icon: Icons.all_inclusive_rounded,
          name: 'Perfect Momentum',
          description: 'Reach the legendary 20× combo',
          category: AchievementCategory.combo,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.bestCombo,
          target: 20,
          unit: '×',
        ),
        AchievementDefinition(
          id: 'zone_tempo_10m',
          icon: Icons.favorite_rounded,
          name: 'Tempo Warrior',
          description: 'Spend 10 total minutes in the tempo zone',
          category: AchievementCategory.zones,
          tier: AchievementTier.silver,
          metric: AchievementMetric.tempoSeconds,
          target: 600,
          unit: 'sec',
        ),
        AchievementDefinition(
          id: 'zone_threshold_5m',
          icon: Icons.monitor_heart_rounded,
          name: 'Threshold Warrior',
          description: 'Spend 5 total minutes in the threshold zone',
          category: AchievementCategory.zones,
          tier: AchievementTier.gold,
          metric: AchievementMetric.thresholdSeconds,
          target: 300,
          unit: 'sec',
        ),
        AchievementDefinition(
          id: 'zone_peak_2m',
          icon: Icons.favorite_border_rounded,
          name: 'Peak Warrior',
          description: 'Spend 2 total minutes in the peak zone',
          category: AchievementCategory.zones,
          tier: AchievementTier.platinum,
          metric: AchievementMetric.peakSeconds,
          target: 120,
          unit: 'sec',
        ),
        AchievementDefinition(
          id: 'streak_3',
          icon: Icons.calendar_today_rounded,
          name: 'Three in a Row',
          description: 'Build a 3-day workout streak',
          category: AchievementCategory.consistency,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.longestStreak,
          target: 3,
          unit: 'days',
        ),
        AchievementDefinition(
          id: 'streak_7',
          icon: Icons.date_range_rounded,
          name: 'Unstoppable Week',
          description: 'Build a 7-day workout streak',
          category: AchievementCategory.consistency,
          tier: AchievementTier.gold,
          metric: AchievementMetric.longestStreak,
          target: 7,
          unit: 'days',
        ),
        AchievementDefinition(
          id: 'streak_30',
          icon: Icons.event_available_rounded,
          name: 'Monthly Momentum',
          description: 'Build a 30-day workout streak',
          category: AchievementCategory.consistency,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.longestStreak,
          target: 30,
          unit: 'days',
        ),
        AchievementDefinition(
          id: 'coins_100',
          icon: Icons.monetization_on_rounded,
          name: 'Pocket Change',
          description: 'Collect 100 coins',
          category: AchievementCategory.coins,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.totalCoins,
          target: 100,
          unit: 'coins',
        ),
        AchievementDefinition(
          id: 'coins_500',
          icon: Icons.savings_rounded,
          name: 'Quest Saver',
          description: 'Collect 500 coins',
          category: AchievementCategory.coins,
          tier: AchievementTier.silver,
          metric: AchievementMetric.totalCoins,
          target: 500,
          unit: 'coins',
        ),
        AchievementDefinition(
          id: 'coins_2000',
          icon: Icons.account_balance_rounded,
          name: 'Treasure Keeper',
          description: 'Collect 2,000 coins',
          category: AchievementCategory.coins,
          tier: AchievementTier.gold,
          metric: AchievementMetric.totalCoins,
          target: 2000,
          unit: 'coins',
        ),
        AchievementDefinition(
          id: 'coins_10000',
          icon: Icons.diamond_rounded,
          name: 'Golden Hoard',
          description: 'Collect 10,000 coins',
          category: AchievementCategory.coins,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.totalCoins,
          target: 10000,
          unit: 'coins',
        ),
        AchievementDefinition(
          id: 'wins_1',
          icon: Icons.emoji_events_rounded,
          name: 'First Victory',
          description: 'Win a multiplayer race',
          category: AchievementCategory.multiplayer,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.multiplayerWins,
          target: 1,
          unit: 'wins',
        ),
        AchievementDefinition(
          id: 'wins_5',
          icon: Icons.military_tech_rounded,
          name: 'Race Regular',
          description: 'Win 5 multiplayer races',
          category: AchievementCategory.multiplayer,
          tier: AchievementTier.silver,
          metric: AchievementMetric.multiplayerWins,
          target: 5,
          unit: 'wins',
        ),
        AchievementDefinition(
          id: 'wins_25',
          icon: Icons.workspace_premium_rounded,
          name: 'Podium Fixture',
          description: 'Win 25 multiplayer races',
          category: AchievementCategory.multiplayer,
          tier: AchievementTier.gold,
          metric: AchievementMetric.multiplayerWins,
          target: 25,
          unit: 'wins',
        ),
        AchievementDefinition(
          id: 'wins_100',
          icon: Icons.stars_rounded,
          name: 'Arena Legend',
          description: 'Win 100 multiplayer races',
          category: AchievementCategory.multiplayer,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.multiplayerWins,
          target: 100,
          unit: 'wins',
        ),
        AchievementDefinition(
          id: 'heart_150',
          icon: Icons.favorite_rounded,
          name: 'Heart Awake',
          description: 'Record a heart rate of 150 bpm',
          category: AchievementCategory.heartRate,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.maximumHeartRate,
          target: 150,
          unit: 'bpm',
        ),
        AchievementDefinition(
          id: 'heart_170',
          icon: Icons.monitor_heart_rounded,
          name: 'Redline Ready',
          description: 'Record a heart rate of 170 bpm',
          category: AchievementCategory.heartRate,
          tier: AchievementTier.gold,
          metric: AchievementMetric.maximumHeartRate,
          target: 170,
          unit: 'bpm',
        ),
        AchievementDefinition(
          id: 'heart_190',
          icon: Icons.health_and_safety_rounded,
          name: 'Peak Pulse',
          description: 'Record a heart rate of 190 bpm',
          category: AchievementCategory.heartRate,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.maximumHeartRate,
          target: 190,
          unit: 'bpm',
        ),
        AchievementDefinition(
          id: 'calories_100',
          icon: Icons.local_fire_department_rounded,
          name: 'Spark Burner',
          description: 'Burn 100 total active calories',
          category: AchievementCategory.calories,
          tier: AchievementTier.bronze,
          metric: AchievementMetric.totalCalories,
          target: 100,
          unit: 'kcal',
        ),
        AchievementDefinition(
          id: 'calories_500',
          icon: Icons.whatshot_rounded,
          name: 'Furnace',
          description: 'Burn 500 total active calories',
          category: AchievementCategory.calories,
          tier: AchievementTier.silver,
          metric: AchievementMetric.totalCalories,
          target: 500,
          unit: 'kcal',
        ),
        AchievementDefinition(
          id: 'calories_2000',
          icon: Icons.outdoor_grill_rounded,
          name: 'Inferno Engine',
          description: 'Burn 2,000 total active calories',
          category: AchievementCategory.calories,
          tier: AchievementTier.gold,
          metric: AchievementMetric.totalCalories,
          target: 2000,
          unit: 'kcal',
        ),
        AchievementDefinition(
          id: 'calories_10000',
          icon: Icons.wb_sunny_rounded,
          name: 'Solar Core',
          description: 'Burn 10,000 total active calories',
          category: AchievementCategory.calories,
          tier: AchievementTier.legendary,
          metric: AchievementMetric.totalCalories,
          target: 10000,
          unit: 'kcal',
        ),
        AchievementDefinition(
          id: 'variety_all',
          icon: Icons.fitness_center_rounded,
          name: 'Triple Threat',
          description: 'Use a treadmill, bike, and rower',
          category: AchievementCategory.variety,
          tier: AchievementTier.gold,
          metric: AchievementMetric.machineVariety,
          target: 3,
          unit: 'machines',
        ),
        AchievementDefinition(
          id: 'early_bird_5',
          icon: Icons.wb_twilight_rounded,
          name: 'Early Bird',
          description: 'Finish 5 workouts before 8 AM',
          category: AchievementCategory.lifestyle,
          tier: AchievementTier.silver,
          metric: AchievementMetric.earlyWorkouts,
          target: 5,
          unit: 'workouts',
        ),
        AchievementDefinition(
          id: 'night_owl_5',
          icon: Icons.nights_stay_rounded,
          name: 'Night Owl',
          description: 'Finish 5 workouts after 10 PM',
          category: AchievementCategory.lifestyle,
          tier: AchievementTier.silver,
          metric: AchievementMetric.lateWorkouts,
          target: 5,
          unit: 'workouts',
        ),
        AchievementDefinition(
          id: 'explorer_10k',
          icon: Icons.explore_rounded,
          name: 'Deep Explorer',
          description: 'Travel 10 km in one session',
          category: AchievementCategory.distance,
          tier: AchievementTier.platinum,
          metric: AchievementMetric.longestSessionMeters,
          target: 10000,
          unit: 'm',
        ),
      ];

  bool get isInitialized => _initialized;
  int get unlockedCount => _unlockedAt.length;
  double get completionFraction =>
      definitions.isEmpty ? 0 : unlockedCount / definitions.length;

  List<AchievementProgress> progressFor(PlayerProfile profile) => definitions
      .map((AchievementDefinition definition) {
        return AchievementProgress(
          definition: definition,
          value: _progressValue(definition, profile),
          unlockedAt: _unlockedAt[definition.id],
        );
      })
      .toList(growable: false);

  List<AchievementProgress> recentFor(PlayerProfile profile, {int limit = 6}) {
    final List<AchievementProgress> unlocked =
        progressFor(profile)
            .where((AchievementProgress progress) => progress.isUnlocked)
            .toList()
          ..sort(
            (AchievementProgress a, AchievementProgress b) =>
                b.unlockedAt!.compareTo(a.unlockedAt!),
          );
    return unlocked.take(limit).toList(growable: false);
  }

  bool isUnlocked(String id) => _unlockedAt.containsKey(id);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _preferences = await SharedPreferences.getInstance();
    final String? encoded = _preferences!.getString(_storageKey);
    if (encoded != null) {
      try {
        final Map<String, dynamic> json =
            jsonDecode(encoded) as Map<String, dynamic>;
        final Map<String, dynamic> unlocked =
            (json['unlocked'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        for (final MapEntry<String, dynamic> entry in unlocked.entries) {
          final DateTime? date = DateTime.tryParse(entry.value.toString());
          if (date != null) {
            _unlockedAt[entry.key] = date;
          }
        }
        _nearCompletionNotified.addAll(
          (json['nearNotified'] as List?)?.whereType<String>() ??
              const <String>[],
        );
        final Map<String, dynamic> boosts =
            (json['categoryBoosts'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        for (final AchievementCategory category in AchievementCategory.values) {
          final Object? value = boosts[category.name];
          if (value is num && value > 0) {
            _categoryBoosts[category] = value.toDouble();
          }
        }
      } on Object {
        // Ignore damaged achievement data and rebuild it from the profile.
      }
    }
    _initialized = true;
  }

  Future<AchievementCheckResult> checkAchievements(
    PlayerProfile profile, {
    DateTime? now,
  }) async {
    await initialize();
    final DateTime timestamp = now ?? DateTime.now();
    final List<AchievementUnlock> unlocked = <AchievementUnlock>[];
    final List<NearlyCompleteAchievement> nearly =
        <NearlyCompleteAchievement>[];

    for (final AchievementProgress progress in progressFor(profile)) {
      final String id = progress.definition.id;
      if (!progress.isUnlocked && progress.fraction >= 1) {
        _unlockedAt[id] = timestamp;
        unlocked.add(
          AchievementUnlock(
            definition: progress.definition,
            unlockedAt: timestamp,
          ),
        );
        _nearCompletionNotified.remove(id);
      } else if (!progress.isUnlocked &&
          progress.fraction >= 0.8 &&
          _nearCompletionNotified.add(id)) {
        nearly.add(NearlyCompleteAchievement(progress: progress));
      }
    }

    if (unlocked.isNotEmpty || nearly.isNotEmpty) {
      await _persist();
      notifyListeners();
    }
    return AchievementCheckResult(unlocked: unlocked, nearlyComplete: nearly);
  }

  Future<void> addProgressBoost(
    AchievementCategory category, {
    double fraction = 0.05,
  }) async {
    if (fraction <= 0) {
      return;
    }
    await initialize();
    _categoryBoosts[category] = math.min(
      0.25,
      (_categoryBoosts[category] ?? 0) + fraction,
    );
    await _persist();
    notifyListeners();
  }

  double _progressValue(
    AchievementDefinition definition,
    PlayerProfile profile,
  ) {
    final double raw = switch (definition.metric) {
      AchievementMetric.totalDistanceMeters => profile.totalDistanceMeters,
      AchievementMetric.bestSpeedKph => profile.bestSpeedKph,
      AchievementMetric.bestCombo => profile.bestCombo,
      AchievementMetric.tempoSeconds =>
        (profile.zoneSeconds[HeartRateZone.tempo] ?? 0).toDouble(),
      AchievementMetric.thresholdSeconds =>
        (profile.zoneSeconds[HeartRateZone.threshold] ?? 0).toDouble(),
      AchievementMetric.peakSeconds =>
        (profile.zoneSeconds[HeartRateZone.peak] ?? 0).toDouble(),
      AchievementMetric.longestStreak => profile.longestStreak.toDouble(),
      AchievementMetric.totalCoins => profile.totalCoins.toDouble(),
      AchievementMetric.multiplayerWins => profile.multiplayerWins.toDouble(),
      AchievementMetric.maximumHeartRate =>
        profile.maximumHeartRateBpm.toDouble(),
      AchievementMetric.totalCalories => profile.totalCalories,
      AchievementMetric.machineVariety => _machineVariety(profile).toDouble(),
      AchievementMetric.earlyWorkouts => profile.earlyBirdWorkouts.toDouble(),
      AchievementMetric.lateWorkouts => profile.nightOwlWorkouts.toDouble(),
      AchievementMetric.longestSessionMeters =>
        profile.longestSessionDistanceMeters,
    };
    final double boost = _categoryBoosts[definition.category] ?? 0;
    return raw + definition.target * boost;
  }

  int _machineVariety(PlayerProfile profile) {
    return <MachineKind>{
      MachineKind.treadmill,
      MachineKind.indoorBike,
      MachineKind.rower,
    }.where(profile.machineKindsUsed.contains).length;
  }

  Future<void> _persist() async {
    await _preferences?.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'unlocked': <String, String>{
          for (final MapEntry<String, DateTime> entry in _unlockedAt.entries)
            entry.key: entry.value.toIso8601String(),
        },
        'nearNotified': _nearCompletionNotified.toList(growable: false),
        'categoryBoosts': <String, double>{
          for (final MapEntry<AchievementCategory, double> entry
              in _categoryBoosts.entries)
            entry.key.name: entry.value,
        },
      }),
    );
  }
}
