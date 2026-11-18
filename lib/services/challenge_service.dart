import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine_models.dart';
import 'achievement_service.dart';
import 'cosmetics_service.dart';
import 'player_profile.dart';

enum ChallengeCadence { daily, weekly }

enum ChallengeType { distance, speed, coins, combo, zone, streakDay }

enum ChallengeRewardType { bonusXp, exclusiveCosmetic, achievementBoost }

@immutable
class ChallengeReward {
  const ChallengeReward.xp(this.amount)
    : type = ChallengeRewardType.bonusXp,
      cosmeticId = null,
      achievementCategory = null;

  const ChallengeReward.cosmetic(this.cosmeticId)
    : type = ChallengeRewardType.exclusiveCosmetic,
      amount = 0,
      achievementCategory = null;

  const ChallengeReward.achievementBoost(
    this.achievementCategory, {
    this.amount = 5,
  }) : type = ChallengeRewardType.achievementBoost,
       cosmeticId = null;

  final ChallengeRewardType type;
  final int amount;
  final String? cosmeticId;
  final AchievementCategory? achievementCategory;

  String get label => switch (type) {
    ChallengeRewardType.bonusXp => '+$amount XP',
    ChallengeRewardType.exclusiveCosmetic => 'Exclusive cosmetic',
    ChallengeRewardType.achievementBoost => '+$amount% achievement progress',
  };
}

@immutable
class ChallengeDefinition {
  const ChallengeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.cadence,
    required this.type,
    required this.icon,
    required this.target,
    required this.rewards,
    this.zone,
  });

  final String id;
  final String name;
  final String description;
  final ChallengeCadence cadence;
  final ChallengeType type;
  final IconData icon;
  final double target;
  final HeartRateZone? zone;
  final List<ChallengeReward> rewards;
}

@immutable
class ChallengeProgress {
  const ChallengeProgress({
    required this.definition,
    required this.value,
    required this.completedAt,
  });

  final ChallengeDefinition definition;
  final double value;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;
  double get fraction => (value / definition.target).clamp(0, 1).toDouble();
}

@immutable
class ChallengeCompletion {
  const ChallengeCompletion({
    required this.definition,
    required this.completedAt,
  });

  final ChallengeDefinition definition;
  final DateTime completedAt;
}

@immutable
class ChallengeWorkoutSnapshot {
  const ChallengeWorkoutSnapshot({
    required this.distanceMeters,
    required this.maxSpeedKph,
    required this.coins,
    required this.maxCombo,
    required this.zoneDurations,
    required this.currentStreak,
  });

  final double distanceMeters;
  final double maxSpeedKph;
  final int coins;
  final double maxCombo;
  final Map<HeartRateZone, Duration> zoneDurations;
  final int currentStreak;
}

class ChallengeService extends ChangeNotifier {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();
  static const String _storageKey = 'cardio_quest.challenges.v1';

  SharedPreferences? _preferences;
  bool _initialized = false;
  String? _dailyPeriod;
  String? _weeklyPeriod;
  final Map<String, double> _progress = <String, double>{};
  final Map<String, DateTime> _completedAt = <String, DateTime>{};
  List<ChallengeDefinition> _definitions = const <ChallengeDefinition>[];
  final List<ChallengeCompletion> _popupQueue = <ChallengeCompletion>[];
  final List<ChallengeCompletion> _sessionCompletions = <ChallengeCompletion>[];
  final Map<String, double> _liveBase = <String, double>{};

  String? _activeWorkoutId;
  Future<void> _updateChain = Future<void>.value();
  Timer? _refreshTimer;
  DateTime? _lastLiveUpdate;
  DateTime? _lastPersistedAt;

  bool get isInitialized => _initialized;

  List<ChallengeProgress> get activeChallenges => _definitions
      .map(
        (ChallengeDefinition definition) => ChallengeProgress(
          definition: definition,
          value: _progress[definition.id] ?? 0,
          completedAt: _completedAt[definition.id],
        ),
      )
      .toList(growable: false);

  ChallengeCompletion? takeCompletionPopup() {
    if (_popupQueue.isEmpty) {
      return null;
    }
    return _popupQueue.removeAt(0);
  }

  Future<void> initialize({DateTime? now}) async {
    if (!_initialized) {
      _preferences = await SharedPreferences.getInstance();
      final String? encoded = _preferences!.getString(_storageKey);
      if (encoded != null) {
        try {
          _restore(jsonDecode(encoded) as Map<String, dynamic>);
        } on Object {
          // Invalid challenge state is safe to replace at the next refresh.
        }
      }
      _initialized = true;
    }
    await refreshIfNeeded(now: now);
  }

  /// Regenerates challenge sets exactly at their UTC period boundaries.
  Future<void> refreshIfNeeded({DateTime? now}) async {
    final DateTime utcNow = (now ?? DateTime.now()).toUtc();
    final String daily = _dayKey(utcNow);
    final DateTime weekStart = DateTime.utc(
      utcNow.year,
      utcNow.month,
      utcNow.day,
    ).subtract(Duration(days: utcNow.weekday % 7));
    final String weekly = _dayKey(weekStart);
    bool changed = false;

    if (_dailyPeriod != daily) {
      _removeCadence(ChallengeCadence.daily);
      _dailyPeriod = daily;
      changed = true;
    }
    if (_weeklyPeriod != weekly) {
      _removeCadence(ChallengeCadence.weekly);
      _weeklyPeriod = weekly;
      changed = true;
    }
    _definitions = <ChallengeDefinition>[
      ..._generate(daily, ChallengeCadence.daily, count: 3),
      ..._generate(weekly, ChallengeCadence.weekly, count: 2),
    ];
    if (changed) {
      await _persist();
      notifyListeners();
    }
    if (changed || _refreshTimer == null) {
      _scheduleMidnightRefresh(utcNow);
    }
  }

  Future<void> beginWorkout(String workoutId) async {
    await initialize();
    _popupQueue.clear();
    _activeWorkoutId = workoutId;
    _liveBase
      ..clear()
      ..addEntries(
        _definitions.map(
          (ChallengeDefinition definition) => MapEntry<String, double>(
            definition.id,
            _progress[definition.id] ?? 0,
          ),
        ),
      );
    _sessionCompletions.clear();
    _lastLiveUpdate = null;
  }

  /// This is deliberately cheap to call from Flame's update loop. Actual
  /// persistence and reward work is throttled and serialized.
  void trackGameplay(ChallengeWorkoutSnapshot snapshot) {
    if (_activeWorkoutId == null) {
      return;
    }
    final DateTime now = DateTime.now();
    if (_lastLiveUpdate != null &&
        now.difference(_lastLiveUpdate!) < const Duration(milliseconds: 350)) {
      return;
    }
    _lastLiveUpdate = now;
    _updateChain = _updateChain.then(
      (_) => _applySnapshot(snapshot, forcePersist: false),
    );
  }

  Future<List<ChallengeCompletion>> finishWorkout(
    ChallengeWorkoutSnapshot snapshot,
  ) async {
    await _updateChain;
    await _applySnapshot(snapshot, forcePersist: true);
    final List<ChallengeCompletion> result = List<ChallengeCompletion>.of(
      _sessionCompletions,
    );
    _activeWorkoutId = null;
    _liveBase.clear();
    return result;
  }

  Future<void> _applySnapshot(
    ChallengeWorkoutSnapshot snapshot, {
    required bool forcePersist,
  }) async {
    await refreshIfNeeded();
    bool changed = false;
    for (final ChallengeDefinition definition in _definitions) {
      if (_completedAt.containsKey(definition.id)) {
        continue;
      }
      final double base = _liveBase.putIfAbsent(
        definition.id,
        () => _progress[definition.id] ?? 0,
      );
      final double workoutValue = _workoutValue(definition, snapshot);
      final double next = switch (definition.type) {
        ChallengeType.speed ||
        ChallengeType.combo ||
        ChallengeType.streakDay => math.max(base, workoutValue),
        ChallengeType.distance ||
        ChallengeType.coins ||
        ChallengeType.zone => base + workoutValue,
      };
      if (next > (_progress[definition.id] ?? 0)) {
        _progress[definition.id] = next;
        changed = true;
      }
      if (next >= definition.target) {
        await _complete(definition);
        changed = true;
      }
    }

    final DateTime now = DateTime.now();
    final bool persistenceDue =
        _lastPersistedAt == null ||
        now.difference(_lastPersistedAt!) > const Duration(seconds: 2);
    if (changed && (forcePersist || persistenceDue)) {
      _lastPersistedAt = now;
      await _persist();
    }
    if (changed) {
      notifyListeners();
    }
  }

  double _workoutValue(
    ChallengeDefinition definition,
    ChallengeWorkoutSnapshot snapshot,
  ) {
    return switch (definition.type) {
      ChallengeType.distance => snapshot.distanceMeters,
      ChallengeType.speed => snapshot.maxSpeedKph,
      ChallengeType.coins => snapshot.coins.toDouble(),
      ChallengeType.combo => snapshot.maxCombo,
      ChallengeType.zone =>
        (snapshot.zoneDurations[definition.zone] ?? Duration.zero)
                .inMilliseconds /
            1000,
      ChallengeType.streakDay => snapshot.currentStreak.toDouble(),
    };
  }

  Future<void> _complete(ChallengeDefinition definition) async {
    if (_completedAt.containsKey(definition.id)) {
      return;
    }
    final DateTime completedAt = DateTime.now();
    _completedAt[definition.id] = completedAt;
    final ChallengeCompletion completion = ChallengeCompletion(
      definition: definition,
      completedAt: completedAt,
    );
    _popupQueue.add(completion);
    _sessionCompletions.add(completion);

    for (final ChallengeReward reward in definition.rewards) {
      switch (reward.type) {
        case ChallengeRewardType.bonusXp:
          await PlayerProfile.instance.addBonusXp(reward.amount);
        case ChallengeRewardType.exclusiveCosmetic:
          final String? cosmeticId = reward.cosmeticId;
          if (cosmeticId != null) {
            await CosmeticsService.instance.grantExclusive(cosmeticId);
          }
        case ChallengeRewardType.achievementBoost:
          final AchievementCategory? category = reward.achievementCategory;
          if (category != null) {
            await AchievementService.instance.addProgressBoost(
              category,
              fraction: reward.amount / 100,
            );
          }
      }
    }
  }

  List<ChallengeDefinition> _generate(
    String period,
    ChallengeCadence cadence, {
    required int count,
  }) {
    final int seed = _stableHash('$period-${cadence.name}');
    return List<ChallengeDefinition>.generate(count, (int index) {
      final ChallengeType type = ChallengeType
          .values[(seed + index * 5) % ChallengeType.values.length];
      final int variant = ((seed ~/ (index + 1)) + index) % 3;
      final double target = _target(type, cadence, variant);
      final HeartRateZone? zone = type == ChallengeType.zone
          ? <HeartRateZone>[
              HeartRateZone.tempo,
              HeartRateZone.threshold,
              HeartRateZone.peak,
            ][variant]
          : null;
      final String id = '${cadence.name}-$period-$index-${type.name}';
      return ChallengeDefinition(
        id: id,
        name: _name(type, cadence, zone),
        description: _description(type, target, zone),
        cadence: cadence,
        type: type,
        icon: _icon(type),
        target: target,
        zone: zone,
        rewards: _rewards(cadence, index, seed, type),
      );
    });
  }

  double _target(ChallengeType type, ChallengeCadence cadence, int variant) {
    final bool weekly = cadence == ChallengeCadence.weekly;
    return switch (type) {
      ChallengeType.distance =>
        (weekly
            ? <double>[8000, 12000, 16000]
            : <double>[1000, 1800, 2500])[variant],
      ChallengeType.speed =>
        (weekly ? <double>[12, 15, 18] : <double>[8, 10, 12])[variant],
      ChallengeType.coins =>
        (weekly ? <double>[180, 260, 350] : <double>[25, 45, 70])[variant],
      ChallengeType.combo =>
        (weekly ? <double>[6, 8, 10] : <double>[2, 3, 4])[variant],
      ChallengeType.zone =>
        (weekly ? <double>[600, 900, 1200] : <double>[90, 150, 240])[variant],
      ChallengeType.streakDay =>
        (weekly ? <double>[3, 5, 7] : <double>[1, 2, 3])[variant],
    };
  }

  IconData _icon(ChallengeType type) => switch (type) {
    ChallengeType.distance => Icons.route_rounded,
    ChallengeType.speed => Icons.speed_rounded,
    ChallengeType.coins => Icons.monetization_on_rounded,
    ChallengeType.combo => Icons.local_fire_department_rounded,
    ChallengeType.zone => Icons.favorite_rounded,
    ChallengeType.streakDay => Icons.calendar_today_rounded,
  };

  String _name(
    ChallengeType type,
    ChallengeCadence cadence,
    HeartRateZone? zone,
  ) {
    final String prefix = cadence == ChallengeCadence.daily
        ? 'Daily'
        : 'Weekly';
    return switch (type) {
      ChallengeType.distance => '$prefix Expedition',
      ChallengeType.speed => '$prefix Velocity',
      ChallengeType.coins => '$prefix Treasure Hunt',
      ChallengeType.combo => '$prefix Flow State',
      ChallengeType.zone => '$prefix ${_capitalize(zone?.name ?? 'zone')} Push',
      ChallengeType.streakDay => '$prefix Momentum',
    };
  }

  String _description(ChallengeType type, double target, HeartRateZone? zone) {
    return switch (type) {
      ChallengeType.distance =>
        'Travel ${(target / 1000).toStringAsFixed(1)} km',
      ChallengeType.speed => 'Reach ${target.toStringAsFixed(0)} km/h',
      ChallengeType.coins => 'Collect ${target.toStringAsFixed(0)} coins',
      ChallengeType.combo => 'Reach a ${target.toStringAsFixed(0)}× combo',
      ChallengeType.zone =>
        'Spend ${_durationLabel(target)} in the ${zone?.name ?? 'target'} zone',
      ChallengeType.streakDay =>
        'Build a ${target.toStringAsFixed(0)}-day streak',
    };
  }

  List<ChallengeReward> _rewards(
    ChallengeCadence cadence,
    int index,
    int seed,
    ChallengeType type,
  ) {
    final AchievementCategory category = switch (type) {
      ChallengeType.distance => AchievementCategory.distance,
      ChallengeType.speed => AchievementCategory.speed,
      ChallengeType.coins => AchievementCategory.coins,
      ChallengeType.combo => AchievementCategory.combo,
      ChallengeType.zone => AchievementCategory.zones,
      ChallengeType.streakDay => AchievementCategory.consistency,
    };
    if (cadence == ChallengeCadence.daily) {
      return <ChallengeReward>[
        ChallengeReward.xp(250 + index * 100),
        if (index == 1) ChallengeReward.achievementBoost(category, amount: 3),
      ];
    }
    return <ChallengeReward>[
      ChallengeReward.xp(1000 + index * 500),
      ChallengeReward.achievementBoost(category),
      if (index == 0)
        ChallengeReward.cosmetic(
          seed.isEven ? 'trail_comet' : 'background_aurora',
        ),
    ];
  }

  void _removeCadence(ChallengeCadence cadence) {
    final String prefix = '${cadence.name}-';
    _progress.removeWhere((String id, double _) => id.startsWith(prefix));
    _completedAt.removeWhere((String id, DateTime _) => id.startsWith(prefix));
  }

  void _restore(Map<String, dynamic> json) {
    _dailyPeriod = json['dailyPeriod'] as String?;
    _weeklyPeriod = json['weeklyPeriod'] as String?;
    final Map<String, dynamic> progress =
        (json['progress'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in progress.entries) {
      if (entry.value is num) {
        _progress[entry.key] = (entry.value as num).toDouble();
      }
    }
    final Map<String, dynamic> completed =
        (json['completedAt'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    for (final MapEntry<String, dynamic> entry in completed.entries) {
      final DateTime? date = DateTime.tryParse(entry.value.toString());
      if (date != null) {
        _completedAt[entry.key] = date;
      }
    }
  }

  Future<void> _persist() async {
    await _preferences?.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'dailyPeriod': _dailyPeriod,
        'weeklyPeriod': _weeklyPeriod,
        'progress': _progress,
        'completedAt': <String, String>{
          for (final MapEntry<String, DateTime> entry in _completedAt.entries)
            entry.key: entry.value.toIso8601String(),
        },
      }),
    );
  }

  void _scheduleMidnightRefresh(DateTime utcNow) {
    _refreshTimer?.cancel();
    final DateTime nextMidnight = DateTime.utc(
      utcNow.year,
      utcNow.month,
      utcNow.day + 1,
    );
    _refreshTimer = Timer(nextMidnight.difference(utcNow), () {
      _refreshTimer = null;
      unawaited(refreshIfNeeded(now: nextMidnight));
    });
  }

  static int _stableHash(String value) {
    int hash = 17;
    for (final int code in value.codeUnits) {
      hash = 0x1fffffff & (hash * 37 + code);
    }
    return hash;
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _durationLabel(double seconds) {
    final Duration duration = Duration(seconds: seconds.round());
    if (duration.inMinutes > 0) {
      final int remainder = duration.inSeconds.remainder(60);
      return remainder == 0
          ? '${duration.inMinutes} min'
          : '${duration.inMinutes}m ${remainder}s';
    }
    return '${duration.inSeconds}s';
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
