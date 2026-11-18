import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/machine_models.dart';
import '../services/fitness_export_service.dart';
import '../services/machine_service.dart';
import '../services/player_profile.dart';
import 'achievements_screen.dart';
import 'game_screen.dart';
import 'multiplayer_lobby.dart';
import 'settings_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({
    required this.machineService,
    required this.fitnessExportService,
    super.key,
  });

  final MachineService machineService;
  final FitnessExportService fitnessExportService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF07131F),
              Color(0xFF0B2634),
              Color(0xFF132A3D),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: _MenuAtmosphere()),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool wide = constraints.maxWidth >= 860;
                  final Widget content = wide
                      ? Row(
                          children: <Widget>[
                            const Expanded(flex: 11, child: _HeroCopy()),
                            Expanded(
                              flex: 9,
                              child: _ConnectionPanel(
                                machineService: machineService,
                                fitnessExportService: fitnessExportService,
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: <Widget>[
                            const SizedBox(
                              height: 380,
                              child: _HeroCopy(compact: true),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _ConnectionPanel(
                                machineService: machineService,
                                fitnessExportService: fitnessExportService,
                              ),
                            ),
                          ],
                        );
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 42 : 0,
                      vertical: wide ? 20 : 0,
                    ),
                    child: content,
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: PlayerProfile.instance,
                        builder: (BuildContext context, Widget? child) {
                          return _ProfileButton(
                            profile: PlayerProfile.instance,
                            onPressed: () => _openAchievements(context),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Achievements and loadout',
                        onPressed: () => _openAchievements(context),
                        icon: const Icon(Icons.emoji_events_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Fitness connections',
                        onPressed: () => _openSettings(context),
                        icon: const Icon(Icons.settings_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SettingsScreen(fitnessExportService: fitnessExportService),
      ),
    );
  }

  Future<void> _openAchievements(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AchievementsScreen(),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.profile, required this.onPressed});

  final PlayerProfile profile;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD5122938),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x2865F2D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 27,
                height: 27,
                decoration: const BoxDecoration(
                  color: Color(0x2265F2D0),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${profile.level}',
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LV ${profile.level}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${profile.currentStreak} DAY STREAK',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 24 : 30,
        compact ? 22 : 20,
        compact ? 24 : 48,
        compact ? 12 : 20,
      ),
      child: Stack(
        children: <Widget>[
          Align(
            alignment: compact
                ? const Alignment(0.85, 0.34)
                : const Alignment(0.7, 0.25),
            child: SizedBox(
              width: compact ? 250 : 430,
              height: compact ? 250 : 430,
              child: const CustomPaint(painter: _RunnerEmblemPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _BrandMark(),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1A65F2D0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x4465F2D0)),
                ),
                child: const Text(
                  'REAL SPEED • REAL ADVENTURE',
                  style: TextStyle(
                    color: AppColors.mint,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'TURN YOUR\nWORKOUT INTO\nA QUEST.',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: compact ? 37 : 58),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Text(
                  'Connect a treadmill or bike. Your pace moves the world, '
                  'your incline shapes the trail.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: compact ? 14 : 17,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[AppColors.mint, Color(0xFF5DAAFF)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x4465F2D0),
                blurRadius: 22,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_run_rounded,
            color: AppColors.ink,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'CARDIO QUEST',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
    required this.machineService,
    required this.fitnessExportService,
  });

  final MachineService machineService;
  final FitnessExportService fitnessExportService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: machineService,
      builder: (BuildContext context, Widget? child) {
        return Card(
          margin: const EdgeInsets.all(0),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0x1A65F2D0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.bluetooth_searching_rounded,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Choose your machine',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'FTMS • secure read-only connection',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (machineService.state != WorkoutState.disconnected)
                      _StateChip(state: machineService.state),
                  ],
                ),
                const SizedBox(height: 22),
                if (machineService.errorMessage != null) ...<Widget>[
                  _ErrorBanner(message: machineService.errorMessage!),
                  const SizedBox(height: 14),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 238),
                  child: machineService.devices.isEmpty
                      ? _EmptyScanState(isScanning: machineService.isScanning)
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: machineService.devices.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 9),
                          itemBuilder: (BuildContext context, int index) {
                            final MachineDevice device =
                                machineService.devices[index];
                            return _DeviceTile(
                              device: device,
                              selected:
                                  machineService.selectedDevice?.id ==
                                  device.id,
                              connecting:
                                  machineService.state ==
                                      WorkoutState.connecting &&
                                  machineService.selectedDevice?.id ==
                                      device.id,
                              onTap: () => _connectAndLaunch(context, device),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: machineService.isScanning
                      ? null
                      : machineService.startScan,
                  icon: machineService.isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.ink,
                          ),
                        )
                      : const Icon(Icons.radar_rounded),
                  label: Text(
                    machineService.isScanning
                        ? 'SCANNING FOR FTMS…'
                        : 'SCAN FOR MACHINES',
                  ),
                ),
                const SizedBox(height: 11),
                OutlinedButton.icon(
                  onPressed: () => _launchSimulator(context),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('PLAY WITH TOUCH CONTROLS'),
                ),
                const SizedBox(height: 11),
                FilledButton.icon(
                  onPressed: () => _launchMultiplayer(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lavender,
                  ),
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('MULTIPLAYER RACE'),
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Speed and workout data only — machine controls are never written',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _connectAndLaunch(
    BuildContext context,
    MachineDevice device,
  ) async {
    await machineService.connect(device);
    if (!context.mounted ||
        machineService.state != WorkoutState.connectedIdle) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScreen(
          machineService: machineService,
          fitnessExportService: fitnessExportService,
        ),
      ),
    );
  }

  Future<void> _launchSimulator(BuildContext context) async {
    await machineService.enableSimulator();
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GameScreen(
          machineService: machineService,
          fitnessExportService: fitnessExportService,
        ),
      ),
    );
  }

  Future<void> _launchMultiplayer(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            MultiplayerLobby(machineService: machineService),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.connecting,
    required this.onTap,
  });

  final MachineDevice device;
  final bool selected;
  final bool connecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (device.kind) {
      MachineKind.indoorBike => Icons.directions_bike_rounded,
      MachineKind.treadmill => Icons.directions_run_rounded,
      MachineKind.crossTrainer => Icons.fitness_center_rounded,
      MachineKind.rower => Icons.rowing_rounded,
      MachineKind.unknown ||
      MachineKind.simulator => Icons.monitor_heart_rounded,
    };
    final int signalBars = device.rssi >= -55
        ? 3
        : device.rssi >= -72
        ? 2
        : 1;
    return Material(
      color: selected ? const Color(0x1F65F2D0) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: connecting ? null : onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? const Color(0x6665F2D0)
                  : const Color(0x16FFFFFF),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x16FFFFFF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.mint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _kindLabel(device.kind),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (connecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.mint,
                  ),
                )
              else ...<Widget>[
                _SignalBars(bars: signalBars),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _kindLabel(MachineKind kind) {
    return switch (kind) {
      MachineKind.treadmill => 'FTMS treadmill',
      MachineKind.indoorBike => 'FTMS indoor bike',
      MachineKind.crossTrainer => 'FTMS cross trainer',
      MachineKind.rower => 'FTMS rower',
      MachineKind.simulator => 'Touch simulator',
      MachineKind.unknown => 'FTMS cardio machine',
    };
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(3, (int index) {
        return Container(
          width: 3,
          height: 6 + index * 4,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: index < bars ? AppColors.mint : const Color(0x22FFFFFF),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _EmptyScanState extends StatelessWidget {
  const _EmptyScanState({required this.isScanning});

  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152,
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0x16FFFFFF)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isScanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.bluetooth_rounded,
              color: isScanning ? AppColors.mint : AppColors.textMuted,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              isScanning ? 'Looking for nearby machines…' : 'No machines yet',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Wake the machine, then scan',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1FFF6B7A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FF6B7A)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.coral,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final WorkoutState state;

  @override
  Widget build(BuildContext context) {
    final bool online =
        state != WorkoutState.disconnected && state != WorkoutState.connecting;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: (online ? AppColors.success : AppColors.gold).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? AppColors.success : AppColors.gold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            online ? 'READY' : 'LINKING',
            style: TextStyle(
              color: online ? AppColors.success : AppColors.gold,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuAtmosphere extends StatelessWidget {
  const _MenuAtmosphere();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AtmospherePainter());
  }
}

class _AtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = const Color(0x0965F2D0)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), grid);
    }
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.86),
      size.shortestSide * 0.3,
      Paint()
        ..color = const Color(0x125DAAFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.1),
      size.shortestSide * 0.2,
      Paint()
        ..color = const Color(0x1065F2D0)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RunnerEmblemPainter extends CustomPainter {
  const _RunnerEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.5, size.height * 0.5);
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        center,
        size.shortestSide * (0.19 + i * 0.075),
        Paint()
          ..color = Color.lerp(
            AppColors.mint,
            const Color(0xFF5DAAFF),
            i / 3,
          )!.withValues(alpha: 0.15 - i * 0.025)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final Paint glow = Paint()
      ..color = AppColors.mint.withValues(alpha: 0.22)
      ..strokeWidth = size.shortestSide * 0.06
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final Paint line = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[AppColors.mint, Color(0xFF5DAAFF)],
      ).createShader(Offset.zero & size)
      ..strokeWidth = size.shortestSide * 0.028
      ..strokeCap = StrokeCap.round;

    final double unit = size.shortestSide / 10;
    final Offset head = center + Offset(unit * 0.7, -unit * 2.8);
    final Offset shoulder = center + Offset(unit * 0.25, -unit * 1.5);
    final Offset hip = center + Offset(-unit * 0.2, unit * 0.3);
    final List<(Offset, Offset)> segments = <(Offset, Offset)>[
      (shoulder, hip),
      (shoulder, center + Offset(-unit * 1.7, -unit * 0.2)),
      (shoulder, center + Offset(unit * 1.9, -unit * 0.8)),
      (hip, center + Offset(-unit * 2, unit * 2.5)),
      (hip, center + Offset(unit * 2.3, unit * 2)),
    ];
    for (final (Offset start, Offset end) in segments) {
      canvas.drawLine(start, end, glow);
    }
    canvas.drawCircle(
      head,
      unit * 0.63,
      Paint()
        ..color = AppColors.mint.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    for (final (Offset start, Offset end) in segments) {
      canvas.drawLine(start, end, line);
    }
    canvas.drawCircle(head, unit * 0.55, Paint()..color = AppColors.mint);

    final Paint streak = Paint()
      ..color = AppColors.mint.withValues(alpha: 0.24)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      streak.strokeWidth = 1 + i * 0.45;
      final double y = center.dy - unit * 1.7 + i * unit * 0.7;
      canvas.drawLine(
        Offset(center.dx - unit * (4.4 + i * 0.25), y),
        Offset(center.dx - unit * (2.7 - i * 0.14), y),
        streak,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
