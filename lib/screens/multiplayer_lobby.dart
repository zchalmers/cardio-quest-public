import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/palette.dart';
import '../models/machine_models.dart';
import '../models/multiplayer_models.dart';
import '../services/machine_service.dart';
import '../services/multiplayer_service.dart';
import 'multiplayer_race_screen.dart';

class MultiplayerLobby extends StatefulWidget {
  const MultiplayerLobby({
    required this.machineService,
    this.multiplayerService,
    super.key,
  });

  final MachineService machineService;
  final MultiplayerService? multiplayerService;

  @override
  State<MultiplayerLobby> createState() => _MultiplayerLobbyState();
}

class _MultiplayerLobbyState extends State<MultiplayerLobby> {
  late final MultiplayerService _service;
  late final bool _ownsService;
  late final TextEditingController _nameController;
  final TextEditingController _codeController = TextEditingController();
  double _goalMeters = 1000;
  bool _working = false;
  bool _raceRouteOpen = false;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.multiplayerService == null;
    _service = widget.multiplayerService ?? MultiplayerService();
    _nameController = TextEditingController(
      text:
          'Racer ${_service.playerId.substring(_service.playerId.length - 4)}',
    );
    _service.addListener(_onServiceChanged);
    unawaited(_service.connect());
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _nameController.dispose();
    _codeController.dispose();
    if (_ownsService) {
      _service.leaveRoom();
      _service.dispose();
    }
    super.dispose();
  }

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
              Color(0xFF10293A),
              Color(0xFF18213A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _LobbyHeader(
                service: _service,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool wide = constraints.maxWidth >= 820;
                    final Widget content = _service.isInRoom
                        ? _RoomLobby(
                            service: _service,
                            machineService: widget.machineService,
                            goalMeters: _goalMeters,
                            onGoalChanged: (double value) {
                              setState(() => _goalMeters = value);
                            },
                            onLeave: _service.leaveRoom,
                          )
                        : _RoomEntry(
                            service: _service,
                            machineService: widget.machineService,
                            nameController: _nameController,
                            codeController: _codeController,
                            working: _working,
                            wide: wide,
                            onCreate: () => _runAction(
                              () => _service.createRoom(_nameController.text),
                            ),
                            onJoin: () => _runAction(
                              () => _service.joinRoom(
                                _codeController.text,
                                _nameController.text,
                              ),
                            ),
                            onMatchmake: () => _runAction(
                              () => _service.findMatch(_nameController.text),
                            ),
                          );
                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 44 : 18,
                          vertical: 20,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: content,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAction(Future<bool> Function() action) async {
    if (_working) {
      return;
    }
    setState(() => _working = true);
    await action();
    if (mounted) {
      setState(() => _working = false);
    }
  }

  void _onServiceChanged() {
    if (!mounted) {
      return;
    }
    final bool shouldOpenRace =
        !_raceRouteOpen &&
        (_service.roomPhase == MultiplayerRoomPhase.countdown ||
            _service.roomPhase == MultiplayerRoomPhase.racing) &&
        _service.raceStartsAt != null;
    if (shouldOpenRace) {
      _raceRouteOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((Duration _) async {
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => MultiplayerRaceScreen(
              machineService: widget.machineService,
              multiplayerService: _service,
            ),
          ),
        );
        if (mounted) {
          setState(() => _raceRouteOpen = false);
        }
      });
    }
    setState(() {});
  }
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.service, required this.onBack});

  final MultiplayerService service;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.mint, Color(0xFF5DAAFF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppColors.ink,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'MULTIPLAYER RACE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'LIVE CARDIO • UP TO 8 RACERS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          _ConnectionPill(state: service.connectionState),
        ],
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.state});

  final MultiplayerConnectionState state;

  @override
  Widget build(BuildContext context) {
    final bool online = state == MultiplayerConnectionState.connected;
    final bool trying =
        state == MultiplayerConnectionState.connecting ||
        state == MultiplayerConnectionState.reconnecting;
    final String label = online
        ? 'RELAY ONLINE'
        : trying
        ? 'CONNECTING'
        : 'RELAY OFFLINE';
    final Color color = online
        ? AppColors.success
        : trying
        ? AppColors.gold
        : AppColors.coral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (trying)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomEntry extends StatelessWidget {
  const _RoomEntry({
    required this.service,
    required this.machineService,
    required this.nameController,
    required this.codeController,
    required this.working,
    required this.wide,
    required this.onCreate,
    required this.onJoin,
    required this.onMatchmake,
  });

  final MultiplayerService service;
  final MachineService machineService;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final bool working;
  final bool wide;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onMatchmake;

  @override
  Widget build(BuildContext context) {
    final Widget createCard = _LobbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CardTitle(
            icon: Icons.add_circle_outline_rounded,
            title: 'START A ROOM',
            subtitle: 'Create a private code or find a racer automatically.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: working ? null : onCreate,
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('CREATE ROOM'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: working ? null : onMatchmake,
            icon: service.waitingForMatch
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.mint,
                    ),
                  )
                : const Icon(Icons.flash_on_rounded),
            label: Text(
              service.waitingForMatch ? 'FINDING A RACER…' : 'QUICK MATCH',
            ),
          ),
        ],
      ),
    );
    final Widget joinCard = _LobbyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CardTitle(
            icon: Icons.login_rounded,
            title: 'JOIN BY CODE',
            subtitle: 'Enter the four characters shown by your host.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              UpperCaseTextFormatter(),
            ],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: 'ABCD',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: working ? null : onJoin,
            icon: const Icon(Icons.groups_rounded),
            label: const Text('JOIN ROOM'),
          ),
        ],
      ),
    );
    return Column(
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TextField(
            controller: nameController,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'RACER NAME',
              counterText: '',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _MachineSetupCard(machineService: machineService),
        const SizedBox(height: 18),
        if (service.errorMessage != null) ...<Widget>[
          _LobbyError(message: service.errorMessage!),
          const SizedBox(height: 14),
        ],
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: createCard),
              const SizedBox(width: 18),
              Expanded(child: joinCard),
            ],
          )
        else ...<Widget>[createCard, const SizedBox(height: 14), joinCard],
        const SizedBox(height: 16),
        Text(
          'Relay: ${service.serverUri}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _MachineSetupCard extends StatelessWidget {
  const _MachineSetupCard({required this.machineService});

  final MachineService machineService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: machineService,
      builder: (BuildContext context, Widget? child) {
        final MachineDevice? selected = machineService.selectedDevice;
        final bool connected =
            selected != null &&
            machineService.state != WorkoutState.disconnected &&
            machineService.state != WorkoutState.connecting;
        return _LobbyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CardTitle(
                icon: connected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.fitness_center_rounded,
                title: 'WORKOUT SOURCE',
                subtitle: connected
                    ? '${selected.name} is ready to race.'
                    : 'Connect a treadmill or bike, or use the touch pacer.',
              ),
              if (machineService.errorMessage != null) ...<Widget>[
                const SizedBox(height: 10),
                _LobbyError(message: machineService.errorMessage!),
              ],
              if (machineService.devices.isNotEmpty && !connected) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final MachineDevice device in machineService.devices)
                      ActionChip(
                        avatar: Icon(
                          device.kind == MachineKind.indoorBike
                              ? Icons.directions_bike_rounded
                              : Icons.directions_run_rounded,
                          size: 17,
                        ),
                        label: Text(device.name),
                        onPressed:
                            machineService.state == WorkoutState.connecting
                            ? null
                            : () => unawaited(machineService.connect(device)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 13),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: machineService.isScanning
                          ? null
                          : machineService.startScan,
                      icon: machineService.isScanning
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.mint,
                              ),
                            )
                          : const Icon(Icons.radar_rounded),
                      label: Text(
                        machineService.isScanning
                            ? 'SCANNING…'
                            : 'SCAN FOR MACHINE',
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: machineService.enableSimulator,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('TOUCH PACER'),
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

class _RoomLobby extends StatelessWidget {
  const _RoomLobby({
    required this.service,
    required this.machineService,
    required this.goalMeters,
    required this.onGoalChanged,
    required this.onLeave,
  });

  final MultiplayerService service;
  final MachineService machineService;
  final double goalMeters;
  final ValueChanged<double> onGoalChanged;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final MultiplayerRacer? local = service.localRacer;
    return Column(
      children: <Widget>[
        _LobbyCard(
          child: Column(
            children: <Widget>[
              const Text(
                'ROOM CODE',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: service.roomCode ?? ''),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room code copied')),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 3,
                  ),
                  child: Text(
                    service.roomCode ?? '----',
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 9,
                    ),
                  ),
                ),
              ),
              const Text(
                'TAP TO COPY • SHARE WITH UP TO 7 FRIENDS',
                style: TextStyle(color: AppColors.textMuted, fontSize: 9),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget racersCard = _LobbyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _CardTitle(
                    icon: Icons.groups_rounded,
                    title: 'RACERS ${service.racers.length}/8',
                    subtitle: service.allReady
                        ? 'Everyone is ready. The host can start.'
                        : 'Waiting for every connected racer to get ready.',
                  ),
                  const SizedBox(height: 13),
                  for (final MultiplayerRacer racer in service.racers)
                    _LobbyRacerRow(
                      racer: racer,
                      isLocal: racer.id == service.playerId,
                    ),
                ],
              ),
            );
            final Widget setupCard = _LobbyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _CardTitle(
                    icon: Icons.sports_score_rounded,
                    title: 'RACE SETUP',
                    subtitle: 'The first racer to the goal wins.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<double>(
                    initialValue: goalMeters,
                    decoration: const InputDecoration(
                      labelText: 'DISTANCE GOAL',
                    ),
                    items: const <DropdownMenuItem<double>>[
                      DropdownMenuItem<double>(
                        value: 500,
                        child: Text('500 m sprint'),
                      ),
                      DropdownMenuItem<double>(
                        value: 1000,
                        child: Text('1 km race'),
                      ),
                      DropdownMenuItem<double>(
                        value: 2000,
                        child: Text('2 km race'),
                      ),
                      DropdownMenuItem<double>(
                        value: 5000,
                        child: Text('5 km race'),
                      ),
                    ],
                    onChanged: service.isHost
                        ? (double? value) {
                            if (value != null) {
                              onGoalChanged(value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _MachineSource(machineService: machineService),
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: local == null
                        ? null
                        : () => service.setReady(!local.ready),
                    icon: Icon(
                      local?.ready == true
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    label: Text(local?.ready == true ? 'READY!' : 'I’M READY'),
                  ),
                  if (service.isHost) ...<Widget>[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: service.allReady
                          ? () => service.startRace(goalMeters: goalMeters)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('START RACE'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'SAFE CHAT',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    children: <Widget>[
                      for (final PresetRaceMessage message
                          in PresetRaceMessage.values)
                        ActionChip(
                          label: Text(message.text),
                          onPressed: () => service.sendPresetMessage(message),
                        ),
                    ],
                  ),
                ],
              ),
            );
            if (constraints.maxWidth < 700) {
              return Column(
                children: <Widget>[
                  racersCard,
                  const SizedBox(height: 14),
                  setupCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 6, child: racersCard),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: setupCard),
              ],
            );
          },
        ),
        if (service.errorMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          _LobbyError(message: service.errorMessage!),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('LEAVE ROOM'),
        ),
      ],
    );
  }
}

class _LobbyRacerRow extends StatelessWidget {
  const _LobbyRacerRow({required this.racer, required this.isLocal});

  final MultiplayerRacer racer;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isLocal ? const Color(0x1765F2D0) : const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isLocal ? const Color(0x3365F2D0) : const Color(0x18FFFFFF),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            racer.connected
                ? Icons.account_circle_rounded
                : Icons.person_off_rounded,
            color: racer.connected ? AppColors.mint : AppColors.textMuted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${racer.name}${isLocal ? ' (YOU)' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          if (racer.isHost)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.gold,
                size: 17,
              ),
            ),
          Text(
            !racer.connected
                ? 'RECONNECTING'
                : racer.ready
                ? 'READY'
                : 'NOT READY',
            style: TextStyle(
              color: !racer.connected
                  ? AppColors.textMuted
                  : racer.ready
                  ? AppColors.success
                  : AppColors.gold,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineSource extends StatelessWidget {
  const _MachineSource({required this.machineService});

  final MachineService machineService;

  @override
  Widget build(BuildContext context) {
    final bool connected =
        machineService.state != WorkoutState.disconnected &&
        machineService.selectedDevice != null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.bluetooth_connected_rounded : Icons.tune_rounded,
            color: connected ? AppColors.mint : AppColors.gold,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connected
                  ? machineService.selectedDevice!.name
                  : 'Touch pacer will be enabled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: const Color(0xDB102331),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x24FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: const Color(0x1765F2D0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.mint, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LobbyError extends StatelessWidget {
  const _LobbyError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1FFF6B7A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x44FF6B7A)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, color: AppColors.coral, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
