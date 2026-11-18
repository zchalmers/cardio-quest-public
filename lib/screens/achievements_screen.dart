import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/palette.dart';
import '../services/achievement_service.dart';
import '../services/challenge_service.dart';
import '../services/cosmetics_service.dart';
import '../services/player_profile.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementCategory? _category;

  @override
  Widget build(BuildContext context) {
    final PlayerProfile profile = PlayerProfile.instance;
    final AchievementService achievements = AchievementService.instance;
    final CosmeticsService cosmetics = CosmeticsService.instance;
    final ChallengeService challenges = ChallengeService.instance;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        title: const Text('ACHIEVEMENTS'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cosmetic loadout',
            onPressed: () => _showLoadout(context),
            icon: const Icon(Icons.palette_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          profile,
          achievements,
          cosmetics,
          challenges,
        ]),
        builder: (BuildContext context, Widget? child) {
          final List<AchievementProgress> all = achievements.progressFor(
            profile,
          );
          final List<AchievementProgress> filtered = _category == null
              ? all
              : all
                    .where(
                      (AchievementProgress item) =>
                          item.definition.category == _category,
                    )
                    .toList(growable: false);
          final List<AchievementProgress> recent = achievements.recentFor(
            profile,
          );
          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ProfileHeader(
                    profile: profile,
                    achievements: achievements,
                    onLoadout: () => _showLoadout(context),
                  ),
                ),
              ),
              if (recent.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _RecentUnlocks(recent: recent),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ChallengeStrip(
                    challenges: challenges.activeChallenges,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _CategoryFilters(
                    selected: _category,
                    onSelected: (AchievementCategory? category) {
                      setState(() => _category = category);
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverLayoutBuilder(
                  builder:
                      (BuildContext context, SliverConstraints constraints) {
                        final double width = constraints.crossAxisExtent;
                        final int columns = width >= 1100
                            ? 4
                            : width >= 720
                            ? 3
                            : width >= 430
                            ? 2
                            : 1;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: columns == 1 ? 2.25 : 1.18,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (BuildContext context, int index) =>
                                _AchievementCard(progress: filtered[index]),
                            childCount: filtered.length,
                          ),
                        );
                      },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showLoadout(BuildContext context) async {
    final PlayerProfile profile = PlayerProfile.instance;
    final AchievementService achievements = AchievementService.instance;
    final CosmeticsService cosmetics = CosmeticsService.instance;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF102331),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(VoidCallback fn) updateSheet,
              ) {
                return SafeArea(
                  child: DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.82,
                    maxChildSize: 0.94,
                    minChildSize: 0.55,
                    builder:
                        (
                          BuildContext context,
                          ScrollController scrollController,
                        ) {
                          return ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                            children: <Widget>[
                              Center(
                                child: Container(
                                  width: 44,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0x44FFFFFF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Quest loadout',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Every look is drawn live on Canvas—no image '
                                'assets required.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              for (final CosmeticType type
                                  in CosmeticType.values) ...<Widget>[
                                const SizedBox(height: 24),
                                Text(
                                  _cosmeticTypeLabel(type),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                    color: AppColors.mint,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: CosmeticsService.definitions
                                      .where(
                                        (CosmeticDefinition item) =>
                                            item.type == type,
                                      )
                                      .map((CosmeticDefinition item) {
                                        final bool available = cosmetics
                                            .isAvailable(
                                              item,
                                              profile,
                                              achievements,
                                            );
                                        final bool selected =
                                            cosmetics.selected(type).id ==
                                            item.id;
                                        return _CosmeticTile(
                                          definition: item,
                                          available: available,
                                          selected: selected,
                                          onTap: available
                                              ? () async {
                                                  await cosmetics
                                                      .selectCosmetic(
                                                        item.id,
                                                        profile,
                                                        achievements,
                                                      );
                                                  updateSheet(() {});
                                                }
                                              : null,
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ],
                          );
                        },
                  ),
                );
              },
        );
      },
    );
  }

  static String _cosmeticTypeLabel(CosmeticType type) => switch (type) {
    CosmeticType.characterSkin => 'CHARACTER SKINS',
    CosmeticType.trailEffect => 'TRAIL EFFECTS',
    CosmeticType.hudTheme => 'HUD THEMES',
    CosmeticType.backgroundTheme => 'PARALLAX WORLDS',
  };
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.achievements,
    required this.onLoadout,
  });

  final PlayerProfile profile;
  final AchievementService achievements;
  final VoidCallback onLoadout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF123348), Color(0xFF282044)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x2865F2D0)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 560;
          final Widget level = SizedBox(
            width: compact ? double.infinity : 280,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CustomPaint(
                    painter: _CompletionRingPainter(
                      fraction: achievements.completionFraction,
                    ),
                    child: Center(
                      child: Text(
                        '${profile.level}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'LEVEL ${profile.level}',
                        style: const TextStyle(
                          color: AppColors.mint,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.rankTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${achievements.unlockedCount} / '
                        '${AchievementService.definitions.length} unlocked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          final Widget stats = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '${profile.xpIntoLevel} XP',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${profile.xpNeededThisLevel} XP',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: profile.levelProgress,
                  minHeight: 9,
                  backgroundColor: const Color(0x22FFFFFF),
                  color: AppColors.mint,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${profile.currentStreak}',
                      label: 'DAY STREAK',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.route_rounded,
                      value: (profile.totalDistanceMeters / 1000)
                          .toStringAsFixed(1),
                      label: 'TOTAL KM',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.timer_rounded,
                      value: '${profile.totalWorkouts}',
                      label: 'QUESTS',
                    ),
                  ),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                level,
                const SizedBox(height: 20),
                stats,
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onLoadout,
                  icon: const Icon(Icons.palette_rounded),
                  label: const Text('CUSTOMIZE LOADOUT'),
                ),
              ],
            );
          }
          return Row(
            children: <Widget>[
              level,
              const SizedBox(width: 36),
              Expanded(child: stats),
              const SizedBox(width: 22),
              IconButton.filledTonal(
                onPressed: onLoadout,
                tooltip: 'Customize loadout',
                icon: const Icon(Icons.palette_rounded),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: AppColors.gold, size: 17),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _RecentUnlocks extends StatelessWidget {
  const _RecentUnlocks({required this.recent});

  final List<AchievementProgress> recent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'RECENTLY UNLOCKED',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final AchievementProgress progress = recent[index];
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.72, end: 1),
                duration: Duration(milliseconds: 500 + index * 90),
                curve: Curves.easeOutBack,
                builder: (BuildContext context, double value, Widget? child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _tierColor(
                      progress.definition.tier,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _tierColor(
                        progress.definition.tier,
                      ).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      _AchievementIcon(
                        definition: progress.definition,
                        unlocked: true,
                        size: 48,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              progress.definition.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              progress.definition.tier.name.toUpperCase(),
                              style: TextStyle(
                                color: _tierColor(progress.definition.tier),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChallengeStrip extends StatelessWidget {
  const _ChallengeStrip({required this.challenges});

  final List<ChallengeProgress> challenges;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.flag_rounded, color: AppColors.mint, size: 18),
            SizedBox(width: 7),
            Text(
              'ACTIVE CHALLENGES',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.mint,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: challenges.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final ChallengeProgress progress = challenges[index];
              return Container(
                width: 225,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xB3102231),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: progress.isCompleted
                        ? const Color(0x5565F2D0)
                        : const Color(0x1FFFFFFF),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          progress.isCompleted
                              ? Icons.check_circle_rounded
                              : progress.definition.icon,
                          color: progress.isCompleted
                              ? AppColors.success
                              : AppColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            progress.definition.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress.isCompleted
                          ? 'COMPLETED'
                          : progress.definition.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: progress.isCompleted
                            ? AppColors.success
                            : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 6,
                        backgroundColor: const Color(0x22FFFFFF),
                        color: progress.isCompleted
                            ? AppColors.success
                            : AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress.definition.rewards
                          .map((ChallengeReward reward) => reward.label)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({required this.selected, required this.onSelected});

  final AchievementCategory? selected;
  final ValueChanged<AchievementCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('ALL'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final AchievementCategory category in AchievementCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(_categoryIcon(category), size: 16),
                label: Text(_categoryLabel(category)),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.progress});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final AchievementDefinition definition = progress.definition;
    final Color tier = _tierColor(definition.tier);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: progress.isUnlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  tier.withValues(alpha: 0.2),
                  const Color(0xE6102231),
                ],
              )
            : null,
        color: progress.isUnlocked ? null : const Color(0xB3102231),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: progress.isUnlocked
              ? tier.withValues(alpha: 0.55)
              : const Color(0x1FFFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AchievementIcon(
                definition: definition,
                unlocked: progress.isUnlocked,
                size: 54,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  definition.tier.name.toUpperCase(),
                  style: TextStyle(
                    color: tier,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            definition.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              definition.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 9),
          if (progress.isUnlocked)
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_rounded, color: tier, size: 15),
                const SizedBox(width: 5),
                const Text(
                  'UNLOCKED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Text(
                  _progressLabel(progress),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress.fraction * 100).floor()}%',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 7,
                backgroundColor: const Color(0x22FFFFFF),
                color: progress.fraction >= 0.8 ? AppColors.gold : tier,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementIcon extends StatelessWidget {
  const _AchievementIcon({
    required this.definition,
    required this.unlocked,
    required this.size,
  });

  final AchievementDefinition definition;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = unlocked
        ? _tierColor(definition.tier)
        : AppColors.textMuted;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: unlocked ? 0.17 : 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
        boxShadow: unlocked
            ? <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 16),
              ]
            : null,
      ),
      child: Icon(
        unlocked ? definition.icon : Icons.lock_rounded,
        color: color,
        size: size * 0.46,
      ),
    );
  }
}

class _CosmeticTile extends StatelessWidget {
  const _CosmeticTile({
    required this.definition,
    required this.available,
    required this.selected,
    required this.onTap,
  });

  final CosmeticDefinition definition;
  final bool available;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: Material(
        color: selected
            ? definition.primary.withValues(alpha: 0.17)
            : const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? definition.primary : const Color(0x1FFFFFFF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 58,
                  child: CustomPaint(
                    painter: _CosmeticPreviewPainter(
                      definition: definition,
                      locked: !available,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        definition.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.mint,
                        size: 16,
                      )
                    else if (!available)
                      const Icon(
                        Icons.lock_rounded,
                        color: AppColors.textMuted,
                        size: 15,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  available ? definition.description : _unlockLabel(definition),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 8,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _unlockLabel(CosmeticDefinition item) {
    if (item.levelRequired != null) {
      return 'Reach level ${item.levelRequired}';
    }
    if (item.achievementRequired != null) {
      return 'Unlock its achievement';
    }
    return 'Complete a weekly challenge';
  }
}

class _CosmeticPreviewPainter extends CustomPainter {
  const _CosmeticPreviewPainter({
    required this.definition,
    required this.locked,
  });

  final CosmeticDefinition definition;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final Color primary = locked
        ? AppColors.textMuted.withValues(alpha: 0.28)
        : definition.primary;
    final Color secondary = locked
        ? const Color(0x332A3540)
        : definition.secondary;
    final Rect bounds = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(12)),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            secondary.withValues(alpha: 0.75),
            primary.withValues(alpha: 0.28),
          ],
        ).createShader(bounds),
    );

    switch (definition.type) {
      case CosmeticType.characterSkin:
        final Paint runner = Paint()
          ..color = primary
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        final Offset center = Offset(size.width / 2, size.height / 2 - 5);
        canvas
          ..drawCircle(center + const Offset(0, -11), 6, runner)
          ..drawLine(
            center + const Offset(0, -4),
            center + const Offset(-2, 13),
            runner,
          )
          ..drawLine(
            center + const Offset(-2, 13),
            center + const Offset(-14, 23),
            runner,
          )
          ..drawLine(
            center + const Offset(-2, 13),
            center + const Offset(13, 21),
            runner,
          )
          ..drawLine(
            center + const Offset(0, 1),
            center + const Offset(-13, 8),
            runner,
          )
          ..drawLine(
            center + const Offset(0, 1),
            center + const Offset(12, -2),
            runner,
          );
      case CosmeticType.trailEffect:
        for (int i = 0; i < 5; i++) {
          final double y = 12 + i * 9;
          final Path path = Path()
            ..moveTo(size.width * 0.17, y + math.sin(i.toDouble()) * 4)
            ..quadraticBezierTo(
              size.width * 0.48,
              y - 8,
              size.width * 0.82,
              y + 2,
            );
          canvas.drawPath(
            path,
            Paint()
              ..color = Color.lerp(primary, secondary, i / 5)!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
      case CosmeticType.hudTheme:
        for (int i = 0; i < 3; i++) {
          final Rect panel = Rect.fromLTWH(
            10 + i * (size.width - 30) / 3,
            16,
            (size.width - 38) / 3,
            28,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(panel, const Radius.circular(7)),
            Paint()..color = secondary,
          );
          canvas.drawRect(
            Rect.fromLTWH(
              panel.left + 5,
              panel.bottom - 8,
              panel.width - 10,
              3,
            ),
            Paint()..color = primary,
          );
        }
      case CosmeticType.backgroundTheme:
        final Path mountains = Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width * 0.25, size.height * 0.43)
          ..lineTo(size.width * 0.44, size.height * 0.72)
          ..lineTo(size.width * 0.68, size.height * 0.25)
          ..lineTo(size.width, size.height * 0.74)
          ..lineTo(size.width, size.height)
          ..close();
        canvas.drawPath(
          mountains,
          Paint()..color = primary.withValues(alpha: 0.75),
        );
        canvas.drawCircle(
          Offset(size.width * 0.8, size.height * 0.25),
          8,
          Paint()..color = secondary,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CosmeticPreviewPainter oldDelegate) =>
      oldDelegate.definition.id != definition.id ||
      oldDelegate.locked != locked;
}

class _CompletionRingPainter extends CustomPainter {
  const _CompletionRingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect arc = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );
  }

  @override
  bool shouldRepaint(covariant _CompletionRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

Color _tierColor(AchievementTier tier) => switch (tier) {
  AchievementTier.bronze => const Color(0xFFD58A57),
  AchievementTier.silver => const Color(0xFFB9C7D6),
  AchievementTier.gold => AppColors.gold,
  AchievementTier.platinum => const Color(0xFF7BE6EF),
  AchievementTier.legendary => const Color(0xFFC89BFF),
};

IconData _categoryIcon(AchievementCategory category) => switch (category) {
  AchievementCategory.distance => Icons.route_rounded,
  AchievementCategory.speed => Icons.speed_rounded,
  AchievementCategory.combo => Icons.local_fire_department_rounded,
  AchievementCategory.zones => Icons.favorite_rounded,
  AchievementCategory.consistency => Icons.calendar_month_rounded,
  AchievementCategory.coins => Icons.monetization_on_rounded,
  AchievementCategory.multiplayer => Icons.groups_rounded,
  AchievementCategory.heartRate => Icons.monitor_heart_rounded,
  AchievementCategory.calories => Icons.whatshot_rounded,
  AchievementCategory.variety => Icons.fitness_center_rounded,
  AchievementCategory.lifestyle => Icons.schedule_rounded,
};

String _categoryLabel(AchievementCategory category) => switch (category) {
  AchievementCategory.distance => 'DISTANCE',
  AchievementCategory.speed => 'SPEED',
  AchievementCategory.combo => 'COMBO',
  AchievementCategory.zones => 'ZONES',
  AchievementCategory.consistency => 'STREAKS',
  AchievementCategory.coins => 'COINS',
  AchievementCategory.multiplayer => 'RACES',
  AchievementCategory.heartRate => 'HEART',
  AchievementCategory.calories => 'CALORIES',
  AchievementCategory.variety => 'VARIETY',
  AchievementCategory.lifestyle => 'LIFESTYLE',
};

String _progressLabel(AchievementProgress progress) {
  final double value = math.min(progress.value, progress.definition.target);
  final double target = progress.definition.target;
  switch (progress.definition.unit) {
    case 'm':
      return '${(value / 1000).toStringAsFixed(value < 10000 ? 1 : 0)} / '
          '${(target / 1000).toStringAsFixed(target < 10000 ? 1 : 0)} km';
    case 'sec':
      return '${(value / 60).toStringAsFixed(1)} / '
          '${(target / 60).toStringAsFixed(1)} min';
    case 'km/h':
      return '${value.toStringAsFixed(1)} / '
          '${target.toStringAsFixed(0)} km/h';
    case '×':
      return '${value.toStringAsFixed(1)} / ${target.toStringAsFixed(0)}×';
    default:
      return '${value.toStringAsFixed(0)} / '
          '${target.toStringAsFixed(0)} ${progress.definition.unit}';
  }
}
