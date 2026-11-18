import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine_models.dart';

@immutable
class XpBreakdown {
  const XpBreakdown({
    required this.distance,
    required this.coins,
    required this.combo,
    required this.obstacles,
    required this.dailyBonus,
  });

  final int distance;
  final int coins;
  final int combo;
  final int obstacles;
  final int dailyBonus;

  int get workoutXp => distance + coins + combo + obstacles;
  int get total => workoutXp + dailyBonus;
}

@immutable
class LevelReward {
  const LevelReward({
    required this.level,
    required this.name,
    required this.description,
  });

  final int level;
  final String name;
  final String description;
}

@immutable
class ProfileWorkoutResult {
  const ProfileWorkoutResult({
    required this.xp,
    required this.previousLevel,
    required this.currentLevel,
    required this.currentStreak,
    required this.isFirstWorkoutToday,
    required this.levelRewards,
    this.wasAlreadyProcessed = false,
  });

  final XpBreakdown xp;
  final int previousLevel;
  final int currentLevel;
  final int currentStreak;
  final bool isFirstWorkoutToday;
  final List<LevelReward> levelRewards;
  final bool wasAlreadyProcessed;

  bool get leveledUp => currentLevel > previousLevel;
}

/// The single, persisted source of truth for a Cardio Quest player.
class PlayerProfile extends ChangeNotifier {
  PlayerProfile._();

  static final PlayerProfile instance = PlayerProfile._();
  static const String _storageKey = 'cardio_quest.player_profile.v1';
  static const int dailyWorkoutBonusXp = 500;

  SharedPreferences? _preferences;
  Future<void> _writeChain = Future<void>.value();
  bool _initialized = false;

  int totalXp = 0;
  double totalDistanceMeters = 0;
  int totalWorkouts = 0;
  int totalPlaytimeSeconds = 0;
  double bestCombo = 1;
  double bestSpeedKph = 0;
  int currentStreak = 0;
  int longestStreak = 0;

  int totalCoins = 0;
  int totalObstaclesCleared = 0;
  int multiplayerWins = 0;
  double totalCalories = 0;
  int earlyBirdWorkouts = 0;
  int nightOwlWorkouts = 0;
  double longestSessionDistanceMeters = 0;
  int maximumHeartRateBpm = 0;

  final Map<HeartRateZone, int> zoneSeconds = <HeartRateZone, int>{
    HeartRateZone.recovery: 0,
    HeartRateZone.aerobic: 0,
    HeartRateZone.tempo: 0,
    HeartRateZone.threshold: 0,
    HeartRateZone.peak: 0,
  };
  final Set<MachineKind> machineKindsUsed = <MachineKind>{};
  final Set<String> _processedWorkoutIds = <String>{};

  String? _lastWorkoutDayUtc;
  String? _lastDailyBonusDayUtc;

  bool get isInitialized => _initialized;
  int get level => levelForXp(totalXp);
  int get xpAtLevelStart => xpForLevelStart(level);
  int get xpForNextLevel => xpForLevelStart(level + 1);
  int get xpIntoLevel => totalXp - xpAtLevelStart;
  int get xpNeededThisLevel => xpForNextLevel - xpAtLevelStart;
  double get levelProgress =>
      xpNeededThisLevel <= 0 ? 1 : xpIntoLevel / xpNeededThisLevel;
  String get rankTitle => titleForLevel(level);
  DateTime? get lastWorkoutDayUtc => _parseDay(_lastWorkoutDayUtc);

  static int xpForLevelStart(int targetLevel) {
    if (targetLevel <= 1) {
      return 0;
    }
    int total = 0;
    for (int level = 1; level < targetLevel; level++) {
      total += (1000 * math.pow(1.28, level - 1)).round();
    }
    return total;
  }

  static int levelForXp(int xp) {
    int level = 1;
    while (level < 500 && xp >= xpForLevelStart(level + 1)) {
      level++;
    }
    return level;
  }

  static String titleForLevel(int level) {
    const List<String> titles = <String>[
      'Trail Starter',
      'Pace Scout',
      'Momentum Rider',
      'Zone Seeker',
      'Combo Strider',
      'Summit Chaser',
      'Endurance Knight',
      'Tempo Vanguard',
      'Quest Champion',
      'Cardio Legend',
    ];
    final int titleIndex = (level - 1).clamp(0, titles.length - 1);
    if (level <= titles.length) {
      return titles[titleIndex];
    }
    return '${titles.last} ${level - titles.length + 1}';
  }

  static LevelReward rewardForLevel(int level) {
    const Map<int, (String, String)> featured = <int, (String, String)>{
      2: ('Ember skin', 'A fiery new runner look'),
      3: ('Night background', 'Run beneath a moonlit sky'),
      4: ('Neon HUD', 'A bright cyan dashboard theme'),
      5: ('Volt skin', 'An electric character style'),
      8: ('Ghost trail', 'A spectral trail for big combos'),
      10: ('Cyberpunk background', 'A neon city on the horizon'),
      12: ('Phantom skin', 'A rare shadow runner style'),
      15: ('Prismatic HUD', 'A legendary rainbow dashboard'),
    };
    final (String, String)? special = featured[level];
    if (special != null) {
      return LevelReward(
        level: level,
        name: special.$1,
        description: special.$2,
      );
    }
    return LevelReward(
      level: level,
      name: titleForLevel(level),
      description: 'A new profile title for reaching level $level',
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _preferences = await SharedPreferences.getInstance();
    final String? encoded = _preferences!.getString(_storageKey);
    if (encoded != null) {
      try {
        _restore(jsonDecode(encoded) as Map<String, dynamic>);
      } on Object {
        // A damaged local profile should never prevent the game from starting.
      }
    }
    _initialized = true;
    await checkStreakOnLaunch();
  }

  /// Expires a streak only after the player has missed an entire UTC day.
  Future<void> checkStreakOnLaunch({DateTime? now}) async {
    final DateTime today = _utcDay(now ?? DateTime.now());
    final DateTime? last = lastWorkoutDayUtc;
    if (last != null && today.difference(last).inDays > 1) {
      currentStreak = 0;
      await _persist();
      notifyListeners();
    }
  }

  Future<ProfileWorkoutResult> recordWorkout({
    required String workoutId,
    required GameSummary summary,
    required MachineKind machineKind,
    required DateTime endedAt,
    bool multiplayerWin = false,
  }) async {
    await initialize();
    if (_processedWorkoutIds.contains(workoutId)) {
      return ProfileWorkoutResult(
        xp: const XpBreakdown(
          distance: 0,
          coins: 0,
          combo: 0,
          obstacles: 0,
          dailyBonus: 0,
        ),
        previousLevel: level,
        currentLevel: level,
        currentStreak: currentStreak,
        isFirstWorkoutToday: false,
        levelRewards: const <LevelReward>[],
        wasAlreadyProcessed: true,
      );
    }

    final DateTime workoutDay = _utcDay(endedAt);
    final String workoutDayKey = _dayKey(workoutDay);
    final DateTime? lastDay = lastWorkoutDayUtc;
    final bool firstToday = _lastDailyBonusDayUtc != workoutDayKey;
    final int oldLevel = level;

    if (lastDay == null) {
      currentStreak = 1;
    } else {
      final int gap = workoutDay.difference(lastDay).inDays;
      if (gap == 1) {
        currentStreak++;
      } else if (gap > 1 || gap < 0) {
        currentStreak = 1;
      }
    }
    longestStreak = math.max(longestStreak, currentStreak);
    _lastWorkoutDayUtc = workoutDayKey;
    if (firstToday) {
      _lastDailyBonusDayUtc = workoutDayKey;
    }

    final XpBreakdown xp = XpBreakdown(
      distance: summary.distanceXp,
      coins: summary.coinXp,
      combo: summary.comboBonusXp,
      obstacles: summary.obstacleClearXp,
      dailyBonus: firstToday ? dailyWorkoutBonusXp : 0,
    );
    totalXp += xp.total;
    totalDistanceMeters += summary.distanceMeters;
    totalWorkouts++;
    totalPlaytimeSeconds += summary.duration.inSeconds;
    bestCombo = math.max(bestCombo, summary.maxCombo);
    bestSpeedKph = math.max(bestSpeedKph, summary.maxSpeedKph);
    totalCoins += summary.coins;
    totalObstaclesCleared += summary.obstaclesCleared;
    totalCalories += summary.activeEnergyCalories;
    longestSessionDistanceMeters = math.max(
      longestSessionDistanceMeters,
      summary.distanceMeters,
    );
    maximumHeartRateBpm = math.max(
      maximumHeartRateBpm,
      summary.maxHeartRateBpm,
    );
    if (multiplayerWin) {
      multiplayerWins++;
    }

    for (final MapEntry<HeartRateZone, Duration> entry
        in summary.heartRateZoneDurations.entries) {
      zoneSeconds[entry.key] =
          (zoneSeconds[entry.key] ?? 0) + entry.value.inSeconds;
    }
    if (machineKind != MachineKind.unknown &&
        machineKind != MachineKind.simulator) {
      machineKindsUsed.add(machineKind);
    }
    final DateTime localEnd = endedAt.toLocal();
    if (localEnd.hour < 8) {
      earlyBirdWorkouts++;
    }
    if (localEnd.hour >= 22) {
      nightOwlWorkouts++;
    }

    _processedWorkoutIds.add(workoutId);
    if (_processedWorkoutIds.length > 200) {
      _processedWorkoutIds.remove(_processedWorkoutIds.first);
    }
    final int newLevel = level;
    final List<LevelReward> rewards = <LevelReward>[
      for (
        int unlockedLevel = oldLevel + 1;
        unlockedLevel <= newLevel;
        unlockedLevel++
      )
        rewardForLevel(unlockedLevel),
    ];

    await _persist();
    notifyListeners();
    return ProfileWorkoutResult(
      xp: xp,
      previousLevel: oldLevel,
      currentLevel: newLevel,
      currentStreak: currentStreak,
      isFirstWorkoutToday: firstToday,
      levelRewards: rewards,
    );
  }

  Future<void> addBonusXp(int amount) async {
    if (amount <= 0) {
      return;
    }
    await initialize();
    totalXp += amount;
    await _persist();
    notifyListeners();
  }

  Future<void> addMultiplayerWin() async {
    await initialize();
    multiplayerWins++;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final SharedPreferences? preferences = _preferences;
    if (preferences == null) {
      return;
    }
    _writeChain = _writeChain.then(
      (_) => preferences.setString(_storageKey, jsonEncode(_toJson())),
    );
    await _writeChain;
  }

  Map<String, dynamic> _toJson() => <String, dynamic>{
    'totalXp': totalXp,
    'totalDistanceMeters': totalDistanceMeters,
    'totalWorkouts': totalWorkouts,
    'totalPlaytimeSeconds': totalPlaytimeSeconds,
    'bestCombo': bestCombo,
    'bestSpeedKph': bestSpeedKph,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'totalCoins': totalCoins,
    'totalObstaclesCleared': totalObstaclesCleared,
    'multiplayerWins': multiplayerWins,
    'totalCalories': totalCalories,
    'earlyBirdWorkouts': earlyBirdWorkouts,
    'nightOwlWorkouts': nightOwlWorkouts,
    'longestSessionDistanceMeters': longestSessionDistanceMeters,
    'maximumHeartRateBpm': maximumHeartRateBpm,
    'zoneSeconds': <String, int>{
      for (final MapEntry<HeartRateZone, int> entry in zoneSeconds.entries)
        entry.key.name: entry.value,
    },
    'machineKindsUsed': machineKindsUsed
        .map((MachineKind kind) => kind.name)
        .toList(growable: false),
    'processedWorkoutIds': _processedWorkoutIds.toList(growable: false),
    'lastWorkoutDayUtc': _lastWorkoutDayUtc,
    'lastDailyBonusDayUtc': _lastDailyBonusDayUtc,
  };

  void _restore(Map<String, dynamic> json) {
    totalXp = _asInt(json['totalXp']);
    totalDistanceMeters = _asDouble(json['totalDistanceMeters']);
    totalWorkouts = _asInt(json['totalWorkouts']);
    totalPlaytimeSeconds = _asInt(json['totalPlaytimeSeconds']);
    bestCombo = math.max(1, _asDouble(json['bestCombo'], fallback: 1));
    bestSpeedKph = _asDouble(json['bestSpeedKph']);
    currentStreak = _asInt(json['currentStreak']);
    longestStreak = _asInt(json['longestStreak']);
    totalCoins = _asInt(json['totalCoins']);
    totalObstaclesCleared = _asInt(json['totalObstaclesCleared']);
    multiplayerWins = _asInt(json['multiplayerWins']);
    totalCalories = _asDouble(json['totalCalories']);
    earlyBirdWorkouts = _asInt(json['earlyBirdWorkouts']);
    nightOwlWorkouts = _asInt(json['nightOwlWorkouts']);
    longestSessionDistanceMeters = _asDouble(
      json['longestSessionDistanceMeters'],
    );
    maximumHeartRateBpm = _asInt(json['maximumHeartRateBpm']);

    final Map<String, dynamic> savedZones =
        (json['zoneSeconds'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    for (final HeartRateZone zone in zoneSeconds.keys) {
      zoneSeconds[zone] = _asInt(savedZones[zone.name]);
    }
    machineKindsUsed
      ..clear()
      ..addAll(
        _strings(json['machineKindsUsed'])
            .map(
              (String name) => MachineKind.values.firstWhere(
                (MachineKind kind) => kind.name == name,
                orElse: () => MachineKind.unknown,
              ),
            )
            .where((MachineKind kind) => kind != MachineKind.unknown),
      );
    _processedWorkoutIds
      ..clear()
      ..addAll(_strings(json['processedWorkoutIds']));
    _lastWorkoutDayUtc = json['lastWorkoutDayUtc'] as String?;
    _lastDailyBonusDayUtc = json['lastDailyBonusDayUtc'] as String?;
  }

  static int _asInt(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : fallback;

  static double _asDouble(Object? value, {double fallback = 0}) =>
      value is num ? value.toDouble() : fallback;

  static Iterable<String> _strings(Object? value) =>
      value is List ? value.whereType<String>() : const <String>[];

  static DateTime _utcDay(DateTime value) {
    final DateTime utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  static String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDay(String? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse('${value}T00:00:00Z');
  }
}
