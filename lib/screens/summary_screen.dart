import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/machine_models.dart';
import '../services/achievement_service.dart';
import '../services/cosmetics_service.dart';
import '../services/fitness_export_models.dart';
import '../services/fitness_export_service.dart';
import '../services/machine_service.dart';
import '../services/player_profile.dart';
import '../services/progression_service.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    required this.machineService,
    required this.fitnessExportService,
    required this.summary,
    required this.workoutId,
    required this.machineKind,
    required this.endedAt,
    this.progression,
    super.key,
  });

  final MachineService machineService;
  final FitnessExportService fitnessExportService;
  final GameSummary summary;
  final String workoutId;
  final MachineKind machineKind;
  final DateTime endedAt;
  final SessionProgressionResult? progression;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF081727),
              Color(0xFF173448),
              Color(0xFF251738),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CelebrationPainter()),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth > 780;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 54 : 22,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: wide
                          ? Row(
                              children: <Widget>[
                                Expanded(
                                  flex: 4,
                                  child: _SummaryHero(summary: summary),
                                ),
                                const SizedBox(width: 44),
                                Expanded(
                                  flex: 6,
                                  child: _SummaryDetails(
                                    machineService: machineService,
                                    fitnessExportService: fitnessExportService,
                                    summary: summary,
                                    workoutId: workoutId,
                                    machineKind: machineKind,
                                    endedAt: endedAt,
                                    progression: progression,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: <Widget>[
                                _SummaryHero(summary: summary, compact: true),
                                const SizedBox(height: 24),
                                _SummaryDetails(
                                  machineService: machineService,
                                  fitnessExportService: fitnessExportService,
                                  summary: summary,
                                  workoutId: workoutId,
                                  machineKind: machineKind,
                                  endedAt: endedAt,
                                  progression: progression,
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
            if (progression != null &&
                progression!.achievements.unlocked.isNotEmpty)
              _UnlockPopupSequence(unlocks: progression!.achievements.unlocked),
          ],
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.summary, this.compact = false});

  final GameSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: compact ? 180 : 250,
          height: compact ? 180 : 250,
          child: CustomPaint(painter: _MedalPainter(combo: summary.maxCombo)),
        ),
        const SizedBox(height: 8),
        const Text(
          'QUEST COMPLETE',
          style: TextStyle(
            color: AppColors.mint,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _headlineFor(summary),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontSize: compact ? 27 : 37),
        ),
        const SizedBox(height: 9),
        Text(
          '${summary.score}',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: compact ? 40 : 56,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'TOTAL SCORE',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
          ),
        ),
      ],
    );
  }

  String _headlineFor(GameSummary summary) {
    if (summary.distanceMeters >= 5000) {
      return 'Trail legend!';
    }
    if (summary.distanceMeters >= 2000) {
      return 'Epic distance!';
    }
    if (summary.maxCombo >= 3) {
      return 'Locked in!';
    }
    return 'Strong finish!';
  }
}

class _SummaryDetails extends StatelessWidget {
  const _SummaryDetails({
    required this.machineService,
    required this.fitnessExportService,
    required this.summary,
    required this.workoutId,
    required this.machineKind,
    required this.endedAt,
    required this.progression,
  });

  final MachineService machineService;
  final FitnessExportService fitnessExportService;
  final GameSummary summary;
  final String workoutId;
  final MachineKind machineKind;
  final DateTime endedAt;
  final SessionProgressionResult? progression;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Workout recap',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Every meter below came from your real movement.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: <Widget>[
            _StatCard(
              icon: Icons.route_rounded,
              color: AppColors.mint,
              label: 'DISTANCE',
              value: summary.distanceMeters < 1000
                  ? '${summary.distanceMeters.round()} m'
                  : '${(summary.distanceMeters / 1000).toStringAsFixed(2)} km',
            ),
            _StatCard(
              icon: Icons.timer_outlined,
              color: const Color(0xFF9BB7FF),
              label: 'ACTIVE TIME',
              value: _formatDuration(summary.duration),
            ),
            _StatCard(
              icon: Icons.speed_rounded,
              color: AppColors.coral,
              label: 'AVG SPEED',
              value: '${summary.averageSpeedKph.toStringAsFixed(1)} km/h',
            ),
            _StatCard(
              icon: Icons.bolt_rounded,
              color: AppColors.gold,
              label: 'TOP SPEED',
              value: '${summary.maxSpeedKph.toStringAsFixed(1)} km/h',
            ),
            _StatCard(
              icon: Icons.monetization_on_rounded,
              color: AppColors.gold,
              label: 'COINS',
              value: '${summary.coins}',
            ),
            _StatCard(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.coral,
              label: 'BEST COMBO',
              value: '×${summary.maxCombo.toStringAsFixed(1)}',
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x1FFFFFFF)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.keyboard_double_arrow_up_rounded,
                color: AppColors.mint,
                size: 20,
              ),
              const SizedBox(width: 9),
              Text(
                '${summary.obstaclesCleared} obstacles cleared',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Text(
                'DISTANCE × COMBO × COINS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (progression != null) ...<Widget>[
          _ProgressionRecap(result: progression!),
          const SizedBox(height: 20),
        ],
        _FitnessShareActions(
          fitnessExportService: fitnessExportService,
          workoutId: workoutId,
          summary: summary,
          machineKind: machineKind,
          endedAt: endedAt,
        ),
        const SizedBox(height: 13),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _backToMachines(context),
                icon: const Icon(Icons.bluetooth_rounded),
                label: const Text('MACHINES'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _runAgain(context),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('RUN AGAIN'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _backToMachines(BuildContext context) {
    machineService.resetWorkout();
    Navigator.of(context).pop();
  }

  void _runAgain(BuildContext context) {
    machineService.resetWorkout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScreen(
          machineService: machineService,
          fitnessExportService: fitnessExportService,
        ),
      ),
    );
  }
}

class _ProgressionRecap extends StatelessWidget {
  const _ProgressionRecap({required this.result});

  final SessionProgressionResult result;

  @override
  Widget build(BuildContext context) {
    final ProfileWorkoutResult profileResult = result.profile;
    final PlayerProfile profile = PlayerProfile.instance;
    final int totalXp = profileResult.xp.total + result.challengeXp;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xD51A3C44), Color(0xD5272040)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x3865F2D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0x2265F2D0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '+$totalXp XP',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    profileResult.leveledUp
                        ? 'LEVEL ${profileResult.currentLevel} REACHED!'
                        : 'LEVEL ${profileResult.currentLevel} • '
                              '${profile.xpIntoLevel} / '
                              '${profile.xpNeededThisLevel} XP',
                    style: TextStyle(
                      color: profileResult.leveledUp
                          ? AppColors.mint
                          : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (profileResult.isFirstWorkoutToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x20FFD45D),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '+${profileResult.xp.dailyBonus} DAILY',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: profile.levelProgress,
              minHeight: 8,
              backgroundColor: const Color(0x22FFFFFF),
              color: AppColors.mint,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _XpChip(label: 'DISTANCE', value: profileResult.xp.distance),
              _XpChip(label: 'COINS', value: profileResult.xp.coins),
              _XpChip(label: 'COMBO', value: profileResult.xp.combo),
              _XpChip(label: 'OBSTACLES', value: profileResult.xp.obstacles),
              if (result.challengeXp > 0)
                _XpChip(label: 'CHALLENGES', value: result.challengeXp),
            ],
          ),
          if (profileResult.levelRewards.isNotEmpty ||
              result.achievements.unlocked.isNotEmpty ||
              result.unlockedCosmetics.isNotEmpty ||
              result.completedChallenges.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Divider(color: Color(0x1FFFFFFF), height: 1),
            const SizedBox(height: 12),
            const Text(
              'NEW REWARDS',
              style: TextStyle(
                color: AppColors.mint,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final LevelReward reward in profileResult.levelRewards)
                  _RewardPill(
                    icon: Icons.keyboard_double_arrow_up_rounded,
                    label: reward.name,
                    color: AppColors.mint,
                  ),
                for (final AchievementUnlock unlock
                    in result.achievements.unlocked)
                  _RewardPill(
                    icon: unlock.definition.icon,
                    label: unlock.definition.name,
                    color: AppColors.gold,
                  ),
                for (final CosmeticDefinition cosmetic
                    in result.unlockedCosmetics)
                  _RewardPill(
                    icon: cosmetic.icon,
                    label: cosmetic.name,
                    color: cosmetic.primary,
                  ),
                for (final completion in result.completedChallenges)
                  _RewardPill(
                    icon: Icons.flag_rounded,
                    label: completion.definition.name,
                    color: AppColors.success,
                  ),
              ],
            ),
          ],
          if (result.achievements.nearlyComplete.isNotEmpty) ...<Widget>[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x18FFD45D),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _almostThereLabel(result),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _almostThereLabel(SessionProgressionResult result) {
    final NearlyCompleteAchievement near =
        result.achievements.nearlyComplete.first;
    final int percent = (near.progress.fraction * 100).floor();
    final int more = result.achievements.nearlyComplete.length - 1;
    return 'Almost there: ${near.progress.definition.name} is $percent% '
        'complete${more > 0 ? ' (+$more more)' : ''}.';
  }
}

class _XpChip extends StatelessWidget {
  const _XpChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$label +$value',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _UnlockPopupSequence extends StatefulWidget {
  const _UnlockPopupSequence({required this.unlocks});

  final List<AchievementUnlock> unlocks;

  @override
  State<_UnlockPopupSequence> createState() => _UnlockPopupSequenceState();
}

class _UnlockPopupSequenceState extends State<_UnlockPopupSequence> {
  Timer? _timer;
  int _index = 0;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (Timer timer) {
      if (!mounted) {
        return;
      }
      if (_index + 1 >= widget.unlocks.length) {
        timer.cancel();
        setState(() => _visible = false);
      } else {
        setState(() => _index++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    final AchievementDefinition definition = widget.unlocks[_index].definition;
    return Positioned(
      top: 18,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey<String>(definition.id),
              tween: Tween<double>(begin: 0.25, end: 1),
              duration: const Duration(milliseconds: 750),
              curve: Curves.elasticOut,
              builder: (BuildContext context, double value, Widget? child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value.clamp(0, 1), child: child),
                );
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 410),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(15, 13, 20, 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFA3A3020), Color(0xFA211C3F)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.gold, width: 2),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x88FFD45D), blurRadius: 34),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0x22FFD45D),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        definition.icon,
                        color: AppColors.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            'ACHIEVEMENT UNLOCKED!',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            definition.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            definition.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FitnessShareActions extends StatelessWidget {
  const _FitnessShareActions({
    required this.fitnessExportService,
    required this.workoutId,
    required this.summary,
    required this.machineKind,
    required this.endedAt,
  });

  final FitnessExportService fitnessExportService;
  final String workoutId;
  final GameSummary summary;
  final MachineKind machineKind;
  final DateTime endedAt;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fitnessExportService,
      builder: (BuildContext context, Widget? child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.ios_share_rounded, color: AppColors.mint, size: 18),
                SizedBox(width: 8),
                Text(
                  'SHARE WORKOUT',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: FitnessPlatform.values
                  .map(
                    (FitnessPlatform platform) => SizedBox(
                      width: 205,
                      child: _shareButton(context, platform),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        );
      },
    );
  }

  Widget _shareButton(BuildContext context, FitnessPlatform platform) {
    final FitnessExportEntry? entry = fitnessExportService.latestEntry(
      workoutId,
      platform,
    );
    final bool connected = fitnessExportService.isConnected(platform);
    final String platformName = _platformName(platform);
    final bool uploading =
        entry?.status == FitnessUploadStatus.queued ||
        entry?.status == FitnessUploadStatus.uploading ||
        entry?.status == FitnessUploadStatus.processing;
    final bool succeeded = entry?.status == FitnessUploadStatus.succeeded;
    final bool failed = entry?.status == FitnessUploadStatus.failed;

    final Widget icon = uploading
        ? const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            succeeded
                ? Icons.check_circle_rounded
                : failed
                ? Icons.error_rounded
                : connected
                ? Icons.ios_share_rounded
                : Icons.link_rounded,
            color: succeeded
                ? AppColors.success
                : failed
                ? AppColors.coral
                : null,
          );
    final String label = uploading
        ? entry?.status == FitnessUploadStatus.processing
              ? '$platformName PROCESSING'
              : 'SHARING TO ${platformName.toUpperCase()}'
        : succeeded
        ? 'SHARED TO ${platformName.toUpperCase()}'
        : failed
        ? 'RETRY $platformName'
        : 'SHARE TO ${platformName.toUpperCase()}';

    return OutlinedButton.icon(
      onPressed: uploading || succeeded
          ? null
          : () =>
                connected ? _share(context, platform) : _openSettings(context),
      icon: icon,
      label: Text(label),
    );
  }

  Future<void> _share(BuildContext context, FitnessPlatform platform) async {
    try {
      await fitnessExportService.shareWorkout(
        platform: platform,
        workoutId: workoutId,
        summary: summary,
        machineKind: machineKind,
        endedAt: endedAt,
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SettingsScreen(fitnessExportService: fitnessExportService),
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is FitnessServiceException) {
      return error.message;
    }
    return 'The workout could not be shared. It remains queued for retry.';
  }

  String _platformName(FitnessPlatform platform) => switch (platform) {
    FitnessPlatform.strava => 'Strava',
    FitnessPlatform.garmin => 'Garmin',
  };
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xB3102231),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter({required this.combo});

  final double combo;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.shortestSide * 0.29;
    canvas.drawCircle(
      center,
      radius * 1.5,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    for (int i = 0; i < 24; i++) {
      final double angle = i / 24 * math.pi * 2;
      final double inner = radius * 1.18;
      final double outer = radius * (i.isEven ? 1.43 : 1.32);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        Paint()
          ..color = AppColors.gold.withValues(alpha: 0.2)
          ..strokeWidth = i.isEven ? 2 : 1,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFF2A8),
            Color(0xFFFFC13D),
            Color(0xFFDB7C18),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..color = const Color(0x253E2600)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final TextPainter runner = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_run_rounded.codePoint),
        style: TextStyle(
          color: const Color(0xFF4A2B0D),
          fontSize: radius * 0.9,
          fontFamily: Icons.directions_run_rounded.fontFamily,
          package: Icons.directions_run_rounded.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    runner.paint(canvas, center - Offset(runner.width / 2, runner.height / 2));
    final TextPainter comboPainter = TextPainter(
      text: TextSpan(
        text: '×${combo.toStringAsFixed(1)}',
        style: TextStyle(
          color: AppColors.text,
          fontSize: radius * 0.3,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final RRect badge = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center + Offset(0, radius * 0.95),
        width: comboPainter.width + 22,
        height: comboPainter.height + 10,
      ),
      const Radius.circular(14),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xFF102331));
    comboPainter.paint(
      canvas,
      Offset(
        badge.center.dx - comboPainter.width / 2,
        badge.center.dy - comboPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MedalPainter oldDelegate) =>
      oldDelegate.combo != combo;
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random random = math.Random(93);
    const List<Color> colors = <Color>[
      AppColors.mint,
      AppColors.gold,
      AppColors.coral,
      Color(0xFF9BB7FF),
    ];
    for (int i = 0; i < 75; i++) {
      final Offset point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final double rotation = random.nextDouble() * math.pi;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 3 + random.nextDouble() * 7,
            height: 1.5 + random.nextDouble() * 3,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = colors[random.nextInt(colors.length)].withValues(
            alpha: 0.18,
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
