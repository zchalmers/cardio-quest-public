import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievement_service.dart';
import 'player_profile.dart';

enum CosmeticType { characterSkin, trailEffect, hudTheme, backgroundTheme }

enum CosmeticRarity { common, rare, epic, legendary }

@immutable
class CosmeticDefinition {
  const CosmeticDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.rarity,
    required this.primary,
    required this.secondary,
    this.levelRequired,
    this.achievementRequired,
    this.challengeExclusive = false,
    this.minimumCombo = 1,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final CosmeticType type;
  final CosmeticRarity rarity;
  final Color primary;
  final Color secondary;
  final int? levelRequired;
  final String? achievementRequired;
  final bool challengeExclusive;
  final double minimumCombo;

  bool get isStarter =>
      levelRequired == null &&
      achievementRequired == null &&
      !challengeExclusive;
}

class CosmeticsService extends ChangeNotifier {
  CosmeticsService._();

  static final CosmeticsService instance = CosmeticsService._();
  static const String _storageKey = 'cardio_quest.cosmetics.v1';

  SharedPreferences? _preferences;
  bool _initialized = false;
  final Set<String> _granted = <String>{};
  final Set<String> _knownAvailable = <String>{};
  final Map<CosmeticType, String> _selected = <CosmeticType, String>{
    CosmeticType.characterSkin: 'skin_quest',
    CosmeticType.trailEffect: 'trail_none',
    CosmeticType.hudTheme: 'hud_classic',
    CosmeticType.backgroundTheme: 'background_sunset',
  };

  static const List<CosmeticDefinition> definitions = <CosmeticDefinition>[
    CosmeticDefinition(
      id: 'skin_quest',
      name: 'Quest Runner',
      description: 'The classic mint trailblazer',
      icon: Icons.directions_run_rounded,
      type: CosmeticType.characterSkin,
      rarity: CosmeticRarity.common,
      primary: Color(0xFF65F2D0),
      secondary: Color(0xFF102A38),
    ),
    CosmeticDefinition(
      id: 'skin_ember',
      name: 'Ember',
      description: 'A molten runner unlocked at level 2',
      icon: Icons.local_fire_department_rounded,
      type: CosmeticType.characterSkin,
      rarity: CosmeticRarity.rare,
      primary: Color(0xFFFF704F),
      secondary: Color(0xFF6D2431),
      levelRequired: 2,
    ),
    CosmeticDefinition(
      id: 'skin_volt',
      name: 'Volt',
      description: 'Charged up at level 5',
      icon: Icons.bolt_rounded,
      type: CosmeticType.characterSkin,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFFFFE66D),
      secondary: Color(0xFF4A51A3),
      levelRequired: 5,
    ),
    CosmeticDefinition(
      id: 'skin_prism',
      name: 'Prism',
      description: 'Awarded for reaching 10 cumulative kilometers',
      icon: Icons.auto_awesome_rounded,
      type: CosmeticType.characterSkin,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFFCFA8FF),
      secondary: Color(0xFF4E7CFF),
      achievementRequired: 'distance_10k',
    ),
    CosmeticDefinition(
      id: 'skin_phantom',
      name: 'Phantom',
      description: 'A spectral level 12 runner',
      icon: Icons.blur_on_rounded,
      type: CosmeticType.characterSkin,
      rarity: CosmeticRarity.legendary,
      primary: Color(0xFFB8C8FF),
      secondary: Color(0xFF33285F),
      levelRequired: 12,
    ),
    CosmeticDefinition(
      id: 'trail_none',
      name: 'Clean Air',
      description: 'No trail effect',
      icon: Icons.air_rounded,
      type: CosmeticType.trailEffect,
      rarity: CosmeticRarity.common,
      primary: Color(0x00000000),
      secondary: Color(0x00000000),
    ),
    CosmeticDefinition(
      id: 'trail_fire',
      name: 'Fire Trail',
      description: 'Ignites above a 5× combo',
      icon: Icons.local_fire_department_rounded,
      type: CosmeticType.trailEffect,
      rarity: CosmeticRarity.rare,
      primary: Color(0xFFFF7A45),
      secondary: Color(0xFFFFD65A),
      achievementRequired: 'combo_5x',
      minimumCombo: 5,
    ),
    CosmeticDefinition(
      id: 'trail_electric',
      name: 'Electric Trail',
      description: 'Crackles above a 10× combo',
      icon: Icons.electric_bolt_rounded,
      type: CosmeticType.trailEffect,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFF6DEBFF),
      secondary: Color(0xFFB9A4FF),
      achievementRequired: 'combo_10x',
      minimumCombo: 10,
    ),
    CosmeticDefinition(
      id: 'trail_rainbow',
      name: 'Rainbow Trail',
      description: 'A legendary reward for a 20× combo',
      icon: Icons.looks_rounded,
      type: CosmeticType.trailEffect,
      rarity: CosmeticRarity.legendary,
      primary: Color(0xFFFF6B7A),
      secondary: Color(0xFF65F2D0),
      achievementRequired: 'combo_20x',
      minimumCombo: 20,
    ),
    CosmeticDefinition(
      id: 'trail_ghost',
      name: 'Ghost Trail',
      description: 'Ethereal afterimages above an 8× combo',
      icon: Icons.blur_circular_rounded,
      type: CosmeticType.trailEffect,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFFB9C9FF),
      secondary: Color(0xFF8E7CFF),
      levelRequired: 8,
      minimumCombo: 8,
    ),
    CosmeticDefinition(
      id: 'trail_comet',
      name: 'Comet Trail',
      description: 'Exclusive weekly challenge reward',
      icon: Icons.rocket_rounded,
      type: CosmeticType.trailEffect,
      rarity: CosmeticRarity.legendary,
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFF5DAAFF),
      challengeExclusive: true,
      minimumCombo: 6,
    ),
    CosmeticDefinition(
      id: 'hud_classic',
      name: 'Quest Glass',
      description: 'The original glass dashboard',
      icon: Icons.space_dashboard_rounded,
      type: CosmeticType.hudTheme,
      rarity: CosmeticRarity.common,
      primary: Color(0xFF65F2D0),
      secondary: Color(0xB30B1C29),
    ),
    CosmeticDefinition(
      id: 'hud_neon',
      name: 'Neon Grid',
      description: 'A level 4 electric dashboard',
      icon: Icons.grid_view_rounded,
      type: CosmeticType.hudTheme,
      rarity: CosmeticRarity.rare,
      primary: Color(0xFF68E8FF),
      secondary: Color(0xC4141640),
      levelRequired: 4,
    ),
    CosmeticDefinition(
      id: 'hud_summit',
      name: 'Summit Gold',
      description: 'Unlocked by Marathon Spirit',
      icon: Icons.landscape_rounded,
      type: CosmeticType.hudTheme,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFFFFD45D),
      secondary: Color(0xC32D2112),
      achievementRequired: 'distance_42k',
    ),
    CosmeticDefinition(
      id: 'hud_pulse',
      name: 'Pulse',
      description: 'Unlocked by recording 170 bpm',
      icon: Icons.monitor_heart_rounded,
      type: CosmeticType.hudTheme,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFFFF7185),
      secondary: Color(0xC3341424),
      achievementRequired: 'heart_170',
    ),
    CosmeticDefinition(
      id: 'hud_prismatic',
      name: 'Prismatic',
      description: 'A legendary level 15 dashboard',
      icon: Icons.gradient_rounded,
      type: CosmeticType.hudTheme,
      rarity: CosmeticRarity.legendary,
      primary: Color(0xFFCDA8FF),
      secondary: Color(0xC312293A),
      levelRequired: 15,
    ),
    CosmeticDefinition(
      id: 'background_sunset',
      name: 'Sunset Peaks',
      description: 'Warm skies over the original trail',
      icon: Icons.wb_sunny_rounded,
      type: CosmeticType.backgroundTheme,
      rarity: CosmeticRarity.common,
      primary: Color(0xFF183B56),
      secondary: Color(0xFFFFA46B),
    ),
    CosmeticDefinition(
      id: 'background_night',
      name: 'Midnight',
      description: 'Moonlight unlocked at level 3',
      icon: Icons.nights_stay_rounded,
      type: CosmeticType.backgroundTheme,
      rarity: CosmeticRarity.rare,
      primary: Color(0xFF07142D),
      secondary: Color(0xFF564B9B),
      levelRequired: 3,
    ),
    CosmeticDefinition(
      id: 'background_snow',
      name: 'Snowline',
      description: 'Unlocked after 21 cumulative kilometers',
      icon: Icons.ac_unit_rounded,
      type: CosmeticType.backgroundTheme,
      rarity: CosmeticRarity.rare,
      primary: Color(0xFF9CC8E8),
      secondary: Color(0xFFEAF7FF),
      achievementRequired: 'distance_21k',
    ),
    CosmeticDefinition(
      id: 'background_desert',
      name: 'Desert Run',
      description: 'Unlocked after 100 cumulative kilometers',
      icon: Icons.wb_sunny_outlined,
      type: CosmeticType.backgroundTheme,
      rarity: CosmeticRarity.epic,
      primary: Color(0xFF6D342A),
      secondary: Color(0xFFFFC270),
      achievementRequired: 'distance_100k',
    ),
    CosmeticDefinition(
      id: 'background_cyberpunk',
      name: 'Cyber City',
      description: 'Neon horizons unlocked at level 10',
      icon: Icons.location_city_rounded,
      type: CosmeticType.backgroundTheme,
      rarity: CosmeticRarity.legendary,
      primary: Color(0xFF090B2D),
      secondary: Color(0xFFFF4FD8),
      levelRequired: 10,
    ),
    CosmeticDefinition(
      id: 'background_aurora',
      name: 'Aurora',
      description: 'Exclusive weekly challenge reward',
      icon: Icons.auto_awesome_rounded,
      type: CosmeticType.backgroundTheme,
      rarity: CosmeticRarity.legendary,
      primary: Color(0xFF071C31),
      secondary: Color(0xFF58F2B5),
      challengeExclusive: true,
    ),
  ];

  bool get isInitialized => _initialized;
  Set<String> get grantedIds => Set<String>.unmodifiable(_granted);

  CosmeticDefinition selected(CosmeticType type) {
    final String fallback = switch (type) {
      CosmeticType.characterSkin => 'skin_quest',
      CosmeticType.trailEffect => 'trail_none',
      CosmeticType.hudTheme => 'hud_classic',
      CosmeticType.backgroundTheme => 'background_sunset',
    };
    final String id = _selected[type] ?? fallback;
    return definitionById(id) ?? definitionById(fallback)!;
  }

  CosmeticDefinition get characterSkin => selected(CosmeticType.characterSkin);
  CosmeticDefinition get trailEffect => selected(CosmeticType.trailEffect);
  CosmeticDefinition get hudTheme => selected(CosmeticType.hudTheme);
  CosmeticDefinition get backgroundTheme =>
      selected(CosmeticType.backgroundTheme);

  CosmeticDefinition? definitionById(String id) {
    for (final CosmeticDefinition definition in definitions) {
      if (definition.id == id) {
        return definition;
      }
    }
    return null;
  }

  bool isAvailable(
    CosmeticDefinition definition,
    PlayerProfile profile,
    AchievementService achievements,
  ) {
    return definition.isStarter ||
        _granted.contains(definition.id) ||
        (definition.levelRequired != null &&
            profile.level >= definition.levelRequired!) ||
        (definition.achievementRequired != null &&
            achievements.isUnlocked(definition.achievementRequired!));
  }

  List<CosmeticDefinition> availableFor(
    CosmeticType type,
    PlayerProfile profile,
    AchievementService achievements,
  ) {
    return definitions
        .where(
          (CosmeticDefinition item) =>
              item.type == type && isAvailable(item, profile, achievements),
        )
        .toList(growable: false);
  }

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
        _granted.addAll(
          (json['granted'] as List?)?.whereType<String>() ?? const <String>[],
        );
        _knownAvailable.addAll(
          (json['knownAvailable'] as List?)?.whereType<String>() ??
              const <String>[],
        );
        final Map<String, dynamic> selected =
            (json['selected'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        for (final CosmeticType type in CosmeticType.values) {
          final Object? id = selected[type.name];
          if (id is String && definitionById(id)?.type == type) {
            _selected[type] = id;
          }
        }
      } on Object {
        // Keep the safe starter loadout if saved cosmetic data is damaged.
      }
    }
    _initialized = true;
  }

  Future<List<CosmeticDefinition>> syncUnlocks(
    PlayerProfile profile,
    AchievementService achievements, {
    bool announce = true,
  }) async {
    await initialize();
    final Set<String> available = definitions
        .where(
          (CosmeticDefinition item) => isAvailable(item, profile, achievements),
        )
        .map((CosmeticDefinition item) => item.id)
        .toSet();
    final List<CosmeticDefinition> newlyAvailable = definitions
        .where(
          (CosmeticDefinition item) =>
              available.contains(item.id) &&
              !_knownAvailable.contains(item.id) &&
              !item.isStarter,
        )
        .toList(growable: false);
    _knownAvailable.addAll(available);
    await _persist();
    if (announce && newlyAvailable.isNotEmpty) {
      notifyListeners();
      return newlyAvailable;
    }
    return const <CosmeticDefinition>[];
  }

  Future<void> grantExclusive(String cosmeticId) async {
    final CosmeticDefinition? definition = definitionById(cosmeticId);
    if (definition == null) {
      return;
    }
    await initialize();
    if (_granted.add(cosmeticId)) {
      await _persist();
      notifyListeners();
    }
  }

  Future<bool> selectCosmetic(
    String cosmeticId,
    PlayerProfile profile,
    AchievementService achievements,
  ) async {
    final CosmeticDefinition? definition = definitionById(cosmeticId);
    if (definition == null || !isAvailable(definition, profile, achievements)) {
      return false;
    }
    _selected[definition.type] = definition.id;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    await _preferences?.setString(
      _storageKey,
      jsonEncode(<String, dynamic>{
        'granted': _granted.toList(growable: false),
        'knownAvailable': _knownAvailable.toList(growable: false),
        'selected': <String, String>{
          for (final MapEntry<CosmeticType, String> entry in _selected.entries)
            entry.key.name: entry.value,
        },
      }),
    );
  }
}
