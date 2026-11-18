import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../game/cardio_quest_game.dart';
import '../models/machine_models.dart';
import '../services/challenge_service.dart';
import '../services/fitness_export_service.dart';
import '../services/machine_service.dart';
import '../services/progression_service.dart';
import '../services/workout_export.dart';
import 'summary_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.machineService,
    required this.fitnessExportService,
    super.key,
  });

  final MachineService machineService;
  final FitnessExportService fitnessExportService;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final CardioQuestGame _game;
  Timer? _hintTimer;
  Timer? _challengePopupTimer;
  final WorkoutExport _workoutExport = WorkoutExport();
  late final String _workoutId;
  bool _paused = false;
  bool _showTapHint = true;
  bool _navigatingToSummary = false;
  ChallengeCompletion? _challengePopup;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    _workoutId =
        'cardio-quest-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    widget.machineService.beginWorkout();
    ChallengeService.instance.addListener(_onChallengeChanged);
    unawaited(ProgressionService.instance.beginWorkout(_workoutId));
    _game = CardioQuestGame(
      machineService: widget.machineService,
      onComplete: _showSummary,
    );
    _hintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showTapHint = false);
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _challengePopupTimer?.cancel();
    ChallengeService.instance.removeListener(_onChallengeChanged);
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_confirmEndWorkout());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_paused) {
                    _game.jump();
                    if (_showTapHint) {
                      setState(() => _showTapHint = false);
                    }
                  }
                },
                child: GameWidget<CardioQuestGame>(
                  game: _game,
                  loadingBuilder: (BuildContext context) => const ColoredBox(
                    color: AppColors.ink,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.mint),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _GameControlButton(
                      icon: _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      tooltip: _paused ? 'Resume' : 'Pause',
                      onPressed: _paused ? _resume : _pause,
                    ),
                    const SizedBox(width: 8),
                    _GameControlButton(
                      icon: Icons.stop_rounded,
                      tooltip: 'Finish run',
                      color: AppColors.coral,
                      onPressed: _confirmEndWorkout,
                    ),
                  ],
                ),
              ),
            ),
            if (_showTapHint && !_paused)
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: IgnorePointer(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.68, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutBack,
                      builder:
                          (BuildContext context, double value, Widget? child) {
                            return Transform.scale(scale: value, child: child);
                          },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xC40B1C29),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x3365F2D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.touch_app_rounded,
                              color: AppColors.mint,
                              size: 19,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TAP ANYWHERE TO JUMP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.machineService.simulatorEnabled)
              Positioned(
                right: 16,
                bottom: 16,
                child: _SimulatorControls(service: widget.machineService),
              ),
            AnimatedBuilder(
              animation: widget.machineService,
              builder: (BuildContext context, Widget? child) {
                if (widget.machineService.simulatorEnabled ||
                    widget.machineService.state != WorkoutState.disconnected) {
                  return const SizedBox.shrink();
                }
                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6431E2C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x66FF6B7A)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.bluetooth_disabled_rounded,
                            color: AppColors.coral,
                            size: 17,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Machine signal lost — pace is slowing safely',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_paused) _PauseOverlay(onResume: _resume, onEnd: _finish),
            if (_challengePopup case final ChallengeCompletion completion)
              _ChallengeCompletePopup(
                key: ValueKey<String>(completion.definition.id),
                completion: completion,
              ),
          ],
        ),
      ),
    );
  }

  void _pause() {
    if (_paused) {
      return;
    }
    _game.pauseWorkout();
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) {
      return;
    }
    _game.resumeWorkout();
    setState(() => _paused = false);
  }

  Future<void> _confirmEndWorkout() async {
    final bool wasPaused = _paused;
    if (!wasPaused) {
      _pause();
    }
    final bool? shouldEnd = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102331),
          title: const Text('Finish this quest?'),
          content: const Text(
            'Your distance, coins, combo, and score will be saved to the '
            'workout summary.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('KEEP RUNNING'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('FINISH'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (shouldEnd ?? false) {
      _finish();
    } else if (!wasPaused) {
      _resume();
    }
  }

  void _finish() {
    if (_navigatingToSummary) {
      return;
    }
    _game.finishWorkout();
  }

  void _showSummary(GameSummary summary) {
    if (_navigatingToSummary) {
      return;
    }
    _navigatingToSummary = true;
    unawaited(_completeAndShowSummary(summary));
  }

  Future<void> _completeAndShowSummary(GameSummary summary) async {
    final MachineKind machineKind =
        widget.machineService.selectedDevice?.kind ?? MachineKind.unknown;
    final DateTime endedAt = DateTime.now();
    unawaited(
      _workoutExport.writeToHealth(
        summary,
        machineKind: machineKind,
        endedAt: endedAt,
      ),
    );
    unawaited(
      widget.fitnessExportService.autoUploadWorkout(
        workoutId: _workoutId,
        summary: summary,
        machineKind: machineKind,
        endedAt: endedAt,
      ),
    );
    SessionProgressionResult? progression;
    try {
      progression = await ProgressionService.instance.completeWorkout(
        workoutId: _workoutId,
        summary: summary,
        machineKind: machineKind,
        endedAt: endedAt,
      );
    } on Object {
      // Fitness data still reaches the summary if local progression storage
      // is temporarily unavailable.
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => SummaryScreen(
            machineService: widget.machineService,
            fitnessExportService: widget.fitnessExportService,
            summary: summary,
            workoutId: _workoutId,
            machineKind: machineKind,
            endedAt: endedAt,
            progression: progression,
          ),
        ),
      );
    });
  }

  void _onChallengeChanged() {
    if (!mounted || _challengePopup != null) {
      return;
    }
    final ChallengeCompletion? completion = ChallengeService.instance
        .takeCompletionPopup();
    if (completion == null) {
      return;
    }
    setState(() => _challengePopup = completion);
    _challengePopupTimer?.cancel();
    _challengePopupTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() => _challengePopup = null);
      _onChallengeChanged();
    });
  }
}

class _ChallengeCompletePopup extends StatelessWidget {
  const _ChallengeCompletePopup({required this.completion, super.key});

  final ChallengeCompletion completion;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 92,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.5, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (BuildContext context, double value, Widget? child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value.clamp(0, 1), child: child),
              );
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(15, 12, 18, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xF0204B49), Color(0xF0222548)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x9965F2D0), width: 2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x8065F2D0), blurRadius: 28),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 45,
                    height: 45,
                    decoration: const BoxDecoration(
                      color: Color(0x2265F2D0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          'CHALLENGE COMPLETE!',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          completion.definition.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          completion.definition.rewards
                              .map((ChallengeReward reward) => reward.label)
                              .join(' • '),
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
    );
  }
}

class _GameControlButton extends StatelessWidget {
  const _GameControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xC20B1C29),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x24FFFFFF)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SimulatorControls extends StatelessWidget {
  const _SimulatorControls({required this.service});

  final MachineService service;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: 276,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xDE0B1C29),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x2AFFFFFF)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.tune_rounded,
                    color: AppColors.mint,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'TOUCH PACER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${service.metrics.speedKph.toStringAsFixed(1)} km/h',
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 30,
                child: Slider(
                  value: service.metrics.speedKph
                      .clamp(0, GameConstants.maximumDisplaySpeedKph)
                      .toDouble(),
                  max: GameConstants.maximumDisplaySpeedKph,
                  divisions: 80,
                  onChanged: service.setFallbackSpeed,
                ),
              ),
              Row(
                children: <Widget>[
                  const Text(
                    'INCLINE',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: Slider(
                        value: service.metrics.inclinePercent
                            .clamp(0, GameConstants.maximumInclinePercent)
                            .toDouble(),
                        max: GameConstants.maximumInclinePercent,
                        divisions: 40,
                        onChanged: service.setFallbackIncline,
                      ),
                    ),
                  ),
                  Text(
                    '${service.metrics.inclinePercent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onEnd});

  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB807131F),
        child: Center(
          child: Container(
            width: 330,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xF0102331),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0x1F65F2D0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: AppColors.mint,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Quest paused',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Catch your breath. The trail will wait.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEnd,
                        child: const Text('FINISH'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onResume,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('RESUME'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
