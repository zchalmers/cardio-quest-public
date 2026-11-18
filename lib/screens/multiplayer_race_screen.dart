import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../game/multiplayer_race_game.dart';
import '../models/machine_models.dart';
import '../models/multiplayer_models.dart';
import '../services/machine_service.dart';
import '../services/multiplayer_service.dart';
import '../services/progression_service.dart';

class MultiplayerRaceScreen extends StatefulWidget {
  const MultiplayerRaceScreen({
    required this.machineService,
    required this.multiplayerService,
    super.key,
  });

  final MachineService machineService;
  final MultiplayerService multiplayerService;

  @override
  State<MultiplayerRaceScreen> createState() => _MultiplayerRaceScreenState();
}

class _MultiplayerRaceScreenState extends State<MultiplayerRaceScreen> {
  late final MultiplayerRaceGame _game;
  Timer? _clockTimer;
  Timer? _telemetryTimer;
  GameSummary? _summary;
  SessionProgressionResult? _progression;
  late final String _workoutId;
  DateTime? _goShownAt;
  bool _machineReady = false;
  bool _raceStarted = false;
  bool _leaving = false;
  bool _recordingProgression = false;

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
        'cardio-quest-race-'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}';
    _game = MultiplayerRaceGame(
      machineService: widget.machineService,
      multiplayerService: widget.multiplayerService,
      goalMeters: widget.multiplayerService.goalMeters,
      onRaceFinished: _onRaceFinished,
    );
    widget.multiplayerService.addListener(_onMultiplayerChanged);
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (Timer timer) => _tickClock(),
    );
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (Timer timer) => _sendTelemetry(),
    );
    unawaited(_prepareMachine());
  }

  Future<void> _prepareMachine() async {
    await _waitForMachineConnection();
    if (widget.machineService.state == WorkoutState.complete) {
      widget.machineService.resetWorkout();
    }
    if (widget.machineService.state == WorkoutState.disconnected) {
      await widget.machineService.enableSimulator();
    }
    if (!mounted) {
      return;
    }
    _machineReady = true;
    _tickClock();
  }

  Future<void> _waitForMachineConnection() {
    if (widget.machineService.state != WorkoutState.connecting) {
      return Future<void>.value();
    }
    final Completer<void> completer = Completer<void>();
    late final Timer timeout;

    void listener() {
      if (!completer.isCompleted &&
          widget.machineService.state != WorkoutState.connecting) {
        completer.complete();
      }
    }

    widget.machineService.addListener(listener);
    timeout = Timer(const Duration(seconds: 12), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future.whenComplete(() {
      timeout.cancel();
      widget.machineService.removeListener(listener);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _telemetryTimer?.cancel();
    widget.multiplayerService.removeListener(_onMultiplayerChanged);
    if (widget.machineService.state == WorkoutState.running ||
        widget.machineService.state == WorkoutState.paused) {
      widget.machineService.completeWorkout();
    }
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
    final MultiplayerRacer? local = widget.multiplayerService.localRacer;
    final bool spectating =
        _summary != null &&
        widget.multiplayerService.roomPhase != MultiplayerRoomPhase.finished;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_confirmLeave());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _game.jump,
                child: GameWidget<MultiplayerRaceGame>(
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
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.topLeft,
                    child: _LeaderboardPanel(
                      service: widget.multiplayerService,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: _RaceProgress(
                      distanceMeters: _game.distanceMeters,
                      goalMeters: widget.multiplayerService.goalMeters,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: _RaceControlButton(onPressed: _confirmLeave),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: _PresetMessageBar(
                      onMessage: widget.multiplayerService.sendPresetMessage,
                    ),
                  ),
                  if (widget.machineService.simulatorEnabled)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _RacePacerControls(
                        machineService: widget.machineService,
                      ),
                    ),
                ],
              ),
            ),
            if (_countdownLabel.isNotEmpty)
              _CountdownOverlay(label: _countdownLabel),
            if (spectating)
              Positioned(
                left: 0,
                right: 0,
                top: 82,
                child: Center(
                  child: _SpectatorBanner(
                    place: local?.finishPlace,
                    onLeave: _leaveRace,
                  ),
                ),
              ),
            _LatestChatBubble(service: widget.multiplayerService),
            if (!widget.multiplayerService.isConnected)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: _ReconnectBanner(),
              ),
            if (widget.multiplayerService.roomPhase ==
                    MultiplayerRoomPhase.finished &&
                _summary != null)
              _RaceResultOverlay(
                summary: _summary!,
                localRacer: local,
                winnerId: widget.multiplayerService.winnerId,
                progression: _progression,
                onExit: _leaveRace,
              ),
          ],
        ),
      ),
    );
  }

  String get _countdownLabel {
    final DateTime? startsAt = widget.multiplayerService.raceStartsAt;
    if (startsAt == null || !_machineReady) {
      return 'READY';
    }
    final Duration remaining = startsAt.difference(DateTime.now());
    if (remaining > Duration.zero) {
      return (remaining.inMilliseconds / 1000).ceil().clamp(1, 3).toString();
    }
    if (_goShownAt == null ||
        DateTime.now().difference(_goShownAt!) <
            const Duration(milliseconds: 800)) {
      return 'GO!';
    }
    return '';
  }

  void _tickClock() {
    if (!mounted) {
      return;
    }
    final DateTime? startsAt = widget.multiplayerService.raceStartsAt;
    if (!_raceStarted &&
        _machineReady &&
        startsAt != null &&
        !DateTime.now().isBefore(startsAt)) {
      _raceStarted = true;
      _goShownAt = DateTime.now();
      widget.machineService.beginWorkout();
      unawaited(ProgressionService.instance.beginWorkout(_workoutId));
      _game.startRace();
    }
    if (_raceStarted &&
        _goShownAt != null &&
        DateTime.now().difference(_goShownAt!) >
            const Duration(milliseconds: 900)) {
      _clockTimer?.cancel();
      _clockTimer = null;
    }
    setState(() {});
  }

  void _sendTelemetry() {
    if (!_raceStarted) {
      return;
    }
    widget.multiplayerService.sendTelemetry(
      speedKph: _game.smoothedSpeedKph,
      distanceMeters: _game.distanceMeters,
      position: _game.raceProgress,
      finished: _game.isFinished,
    );
  }

  void _onRaceFinished(GameSummary summary) {
    if (!mounted || _summary != null) {
      return;
    }
    _summary = summary;
    _sendTelemetry();
    setState(() {});
    unawaited(_recordProgressionIfReady());
  }

  void _onMultiplayerChanged() {
    if (mounted) {
      setState(() {});
      unawaited(_recordProgressionIfReady());
    }
  }

  Future<void> _recordProgressionIfReady() async {
    final GameSummary? summary = _summary;
    if (!mounted ||
        summary == null ||
        _recordingProgression ||
        _progression != null ||
        widget.multiplayerService.roomPhase != MultiplayerRoomPhase.finished) {
      return;
    }
    _recordingProgression = true;
    final MultiplayerRacer? local = widget.multiplayerService.localRacer;
    final bool won =
        local?.finishPlace == 1 ||
        local?.id == widget.multiplayerService.winnerId;
    try {
      final MachineKind machineKind =
          widget.machineService.selectedDevice?.kind ?? MachineKind.unknown;
      final SessionProgressionResult result = await ProgressionService.instance
          .completeWorkout(
            workoutId: _workoutId,
            summary: summary,
            machineKind: machineKind,
            endedAt: DateTime.now(),
            multiplayerWin: won,
          );
      if (mounted) {
        setState(() => _progression = result);
      }
    } on Object {
      // The race result remains usable if local persistence is unavailable.
    } finally {
      _recordingProgression = false;
    }
  }

  Future<void> _confirmLeave() async {
    if (_leaving) {
      return;
    }
    final bool? leave = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB8000000),
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF102331),
        title: const Text('Leave this race?'),
        content: const Text(
          'Your racer will disconnect and the other players can continue.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP RACING'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    if (mounted && (leave ?? false)) {
      _leaveRace();
    }
  }

  void _leaveRace() {
    if (_leaving) {
      return;
    }
    _leaving = true;
    widget.multiplayerService.leaveRoom();
    if (widget.machineService.state == WorkoutState.complete) {
      widget.machineService.resetWorkout();
    }
    Navigator.of(context).pop();
  }
}

class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({required this.service});

  final MultiplayerService service;

  @override
  Widget build(BuildContext context) {
    final List<MultiplayerRacer> racers = service.leaderboard;
    final double leaderDistance = racers.isEmpty
        ? 0
        : racers
              .map((MultiplayerRacer racer) => racer.distanceMeters)
              .reduce(math.max);
    return Container(
      width: 224,
      constraints: const BoxConstraints(maxHeight: 270),
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 17),
              SizedBox(width: 7),
              Text(
                'LIVE STANDINGS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (int index = 0; index < racers.length; index++)
            _LeaderboardRow(
              rank: index + 1,
              racer: racers[index],
              isLocal: racers[index].id == service.playerId,
              gapMeters: math.max(
                0,
                leaderDistance - racers[index].distanceMeters,
              ),
            ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.racer,
    required this.isLocal,
    required this.gapMeters,
  });

  final int rank;
  final MultiplayerRacer racer;
  final bool isLocal;
  final double gapMeters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Text(
              racer.finishPlace?.toString() ?? rank.toString(),
              style: TextStyle(
                color: rank == 1 ? AppColors.gold : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: racer.connected ? AppColors.mint : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '${racer.name}${isLocal ? ' (YOU)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isLocal ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            racer.finished
                ? 'FIN'
                : gapMeters < 0.5
                ? '${racer.distanceMeters.round()}m'
                : '-${gapMeters.round()}m',
            style: const TextStyle(
              color: AppColors.mint,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceProgress extends StatelessWidget {
  const _RaceProgress({required this.distanceMeters, required this.goalMeters});

  final double distanceMeters;
  final double goalMeters;

  @override
  Widget build(BuildContext context) {
    final double progress = (distanceMeters / goalMeters)
        .clamp(0, 1)
        .toDouble();
    return Container(
      width: 250,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
      decoration: _panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${distanceMeters.clamp(0, goalMeters).round()} M',
                style: const TextStyle(
                  color: AppColors.mint,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'FINISH ${goalMeters.round()} M',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0x22FFFFFF),
              color: AppColors.mint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceControlButton extends StatelessWidget {
  const _RaceControlButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD20B1C29),
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        onPressed: onPressed,
        tooltip: 'Leave race',
        icon: const Icon(Icons.logout_rounded, color: AppColors.coral),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: const Color(0x5207131F),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                label,
                key: ValueKey<String>(label),
                style: TextStyle(
                  color: label == 'GO!' ? AppColors.mint : AppColors.text,
                  fontSize: label.length > 2 ? 76 : 112,
                  fontWeight: FontWeight.w900,
                  shadows: const <Shadow>[
                    Shadow(color: Color(0x99000000), blurRadius: 30),
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

class _PresetMessageBar extends StatelessWidget {
  const _PresetMessageBar({required this.onMessage});

  final bool Function(PresetRaceMessage message) onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: _panelDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final PresetRaceMessage message in PresetRaceMessage.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: TextButton(
                onPressed: () => onMessage(message),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 35),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(message.text),
              ),
            ),
        ],
      ),
    );
  }
}

class _LatestChatBubble extends StatelessWidget {
  const _LatestChatBubble({required this.service});

  final MultiplayerService service;

  @override
  Widget build(BuildContext context) {
    if (service.chatMessages.isEmpty) {
      return const SizedBox.shrink();
    }
    final RaceChatMessage message = service.chatMessages.last;
    if (DateTime.now().difference(message.receivedAt) >
        const Duration(seconds: 4)) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 78,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: _panelDecoration,
            child: Text(
              '${message.senderName}: ${message.message.text}',
              style: const TextStyle(
                color: AppColors.mint,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpectatorBanner extends StatelessWidget {
  const _SpectatorBanner({required this.place, required this.onLeave});

  final int? place;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 8, 8, 8),
      decoration: _panelDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.visibility_rounded, color: AppColors.mint, size: 18),
          const SizedBox(width: 8),
          Text(
            'FINISHED ${place == null ? '' : '#$place'} • SPECTATING',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 9),
          TextButton(onPressed: onLeave, child: const Text('LEAVE NOW')),
        ],
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xE6431E2C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x55FF6B7A)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.coral,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'RECONNECTING — YOUR WORKOUT CONTINUES',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RacePacerControls extends StatelessWidget {
  const _RacePacerControls({required this.machineService});

  final MachineService machineService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: machineService,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: 230,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
          decoration: _panelDecoration,
          child: Row(
            children: <Widget>[
              const Icon(Icons.tune_rounded, color: AppColors.mint, size: 16),
              Expanded(
                child: Slider(
                  value: machineService.metrics.speedKph
                      .clamp(0, GameConstants.maximumDisplaySpeedKph)
                      .toDouble(),
                  max: GameConstants.maximumDisplaySpeedKph,
                  divisions: 80,
                  onChanged: machineService.setFallbackSpeed,
                ),
              ),
              Text(
                machineService.metrics.speedKph.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.mint,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RaceResultOverlay extends StatelessWidget {
  const _RaceResultOverlay({
    required this.summary,
    required this.localRacer,
    required this.winnerId,
    required this.progression,
    required this.onExit,
  });

  final GameSummary summary;
  final MultiplayerRacer? localRacer;
  final String? winnerId;
  final SessionProgressionResult? progression;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final bool won = localRacer?.finishPlace == 1 || localRacer?.id == winnerId;
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xD007131F),
        child: Center(
          child: Container(
            width: 470,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFA102331),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: won ? const Color(0x6665F2D0) : const Color(0x44FF6B7A),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x99000000), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  won ? Icons.emoji_events_rounded : Icons.sports_score_rounded,
                  color: won ? AppColors.gold : AppColors.coral,
                  size: 52,
                ),
                const SizedBox(height: 10),
                Text(
                  won ? 'VICTORY!' : 'DEFEAT',
                  style: const TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Place #${localRacer?.finishPlace ?? '—'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    _ResultStat(
                      label: 'TIME',
                      value: _durationLabel(summary.duration),
                    ),
                    _ResultStat(
                      label: 'AVG SPEED',
                      value:
                          '${summary.averageSpeedKph.toStringAsFixed(1)} km/h',
                    ),
                    _ResultStat(
                      label: 'MAX SPEED',
                      value: '${summary.maxSpeedKph.toStringAsFixed(1)} km/h',
                    ),
                  ],
                ),
                if (progression != null) ...<Widget>[
                  const SizedBox(height: 18),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.65, end: 1),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutBack,
                    builder:
                        (BuildContext context, double value, Widget? child) =>
                            Transform.scale(scale: value, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1765F2D0),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0x3365F2D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.gold,
                            size: 17,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '+${progression!.profile.xp.total + progression!.challengeXp} XP',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (progression!
                              .achievements
                              .unlocked
                              .isNotEmpty) ...<Widget>[
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                '• ${progression!.achievements.unlocked.first.definition.name} unlocked!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.mint,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onExit,
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('BACK TO LOBBY'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _durationLabel(Duration duration) {
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

const BoxDecoration _panelDecoration = BoxDecoration(
  color: Color(0xDD0B1C29),
  borderRadius: BorderRadius.all(Radius.circular(17)),
  border: Border.fromBorderSide(BorderSide(color: Color(0x2AFFFFFF))),
  boxShadow: <BoxShadow>[
    BoxShadow(color: Color(0x44000000), blurRadius: 20, offset: Offset(0, 8)),
  ],
);
