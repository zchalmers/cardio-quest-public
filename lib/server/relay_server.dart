import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const int maximumRacersPerRoom = 8;
const Duration disconnectedRacerRetention = Duration(seconds: 15);

class RelayServer {
  RelayServer({
    Random? random,
    this.countdownDuration = const Duration(milliseconds: 3500),
  }) : _random = random ?? Random.secure() {
    final Handler socketHandler = webSocketHandler(
      _acceptConnection,
      pingInterval: const Duration(seconds: 20),
    );
    final Router router = Router()
      ..get('/', _status)
      ..get('/health', _health)
      ..mount('/ws', socketHandler);
    handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);
  }

  late final Handler handler;

  final Random _random;
  final Duration countdownDuration;
  final Map<String, _Room> _rooms = <String, _Room>{};
  final Set<_ClientSession> _sessions = <_ClientSession>{};
  final List<_ClientSession> _matchmakingQueue = <_ClientSession>[];

  Response _health(Request request) {
    return Response.ok(
      jsonEncode(<String, Object>{'ok': true}),
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  Response _status(Request request) {
    final int racers = _rooms.values.fold<int>(
      0,
      (int total, _Room room) =>
          total +
          room.racers.values.where((_Racer racer) => racer.connected).length,
    );
    return Response.ok(
      jsonEncode(<String, Object>{
        'service': 'Cardio Quest multiplayer relay',
        'rooms': _rooms.length,
        'connectedRacers': racers,
        'matchmakingQueue': _matchmakingQueue.length,
      }),
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  void _acceptConnection(WebSocketChannel channel, String? protocol) {
    final _ClientSession session = _ClientSession(
      connectionId: _randomId(12),
      channel: channel,
    );
    _sessions.add(session);
    _send(session, <String, Object>{
      'type': 'welcome',
      'connectionId': session.connectionId,
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    });
    channel.stream.listen(
      (Object? data) => _handleMessage(session, data),
      onDone: () => _handleDisconnect(session),
      onError: (Object error, StackTrace stackTrace) =>
          _handleDisconnect(session),
      cancelOnError: true,
    );
  }

  void _handleMessage(_ClientSession session, Object? rawMessage) {
    if (session.closed || rawMessage is! String || rawMessage.length > 8192) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(rawMessage);
      if (decoded is! Map<String, dynamic>) {
        _error(session, 'invalid_message', 'Expected a JSON object.');
        return;
      }
      final String? type = decoded['type'] as String?;
      switch (type) {
        case 'create_room':
          _createRoom(session, decoded);
        case 'join_room':
          _joinRoom(session, decoded);
        case 'matchmake':
          _matchmake(session, decoded);
        case 'leave_room':
          _leaveRoom(session, notifyRacer: true);
        case 'set_ready':
          _setReady(session, decoded['ready'] == true);
        case 'start_race':
          _startRace(session, decoded);
        case 'telemetry':
          _relayTelemetry(session, decoded);
        case 'preset_message':
          _relayPresetMessage(session, decoded);
        default:
          _error(session, 'unknown_message', 'Unknown message type.');
      }
    } on FormatException {
      _error(session, 'invalid_json', 'The message was not valid JSON.');
    } on Object {
      _error(session, 'invalid_message', 'The message could not be handled.');
    }
  }

  void _createRoom(_ClientSession session, Map<String, dynamic> message) {
    if (!_prepareIdentity(session, message) || !_ensureAvailable(session)) {
      return;
    }
    final String code = _newRoomCode();
    final _Room room = _Room(code: code);
    _rooms[code] = room;
    _joinRoomInternal(session, room);
  }

  void _joinRoom(_ClientSession session, Map<String, dynamic> message) {
    if (!_prepareIdentity(session, message) || !_ensureAvailable(session)) {
      return;
    }
    final String code = (message['code'] as String? ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(code)) {
      _error(session, 'invalid_code', 'Enter a four-character room code.');
      return;
    }
    final _Room? room = _rooms[code];
    if (room == null) {
      _error(session, 'room_not_found', 'That room does not exist.');
      return;
    }
    _joinRoomInternal(session, room);
  }

  void _matchmake(_ClientSession session, Map<String, dynamic> message) {
    if (!_prepareIdentity(session, message) || !_ensureAvailable(session)) {
      return;
    }
    _matchmakingQueue.removeWhere(
      (_ClientSession queued) => queued.closed || queued == session,
    );
    _ClientSession? opponent;
    while (_matchmakingQueue.isNotEmpty) {
      final _ClientSession candidate = _matchmakingQueue.removeAt(0);
      if (!candidate.closed &&
          candidate.roomCode == null &&
          candidate.playerId != session.playerId) {
        opponent = candidate;
        break;
      }
    }
    if (opponent == null) {
      _matchmakingQueue.add(session);
      _send(session, const <String, Object>{
        'type': 'matchmaking',
        'status': 'waiting',
      });
      return;
    }

    final _Room room = _Room(code: _newRoomCode());
    _rooms[room.code] = room;
    _joinRoomInternal(opponent, room, broadcast: false);
    _joinRoomInternal(session, room);
  }

  bool _prepareIdentity(_ClientSession session, Map<String, dynamic> message) {
    final String playerId = (message['playerId'] as String? ?? '').trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(playerId)) {
      _error(session, 'invalid_player', 'A valid player ID is required.');
      return false;
    }
    session
      ..playerId = playerId
      ..name = _cleanName(message['name'] as String?);
    return true;
  }

  bool _ensureAvailable(_ClientSession session) {
    if (session.roomCode != null) {
      _error(session, 'already_in_room', 'Leave your current room first.');
      return false;
    }
    return true;
  }

  void _joinRoomInternal(
    _ClientSession session,
    _Room room, {
    bool broadcast = true,
  }) {
    final String playerId = session.playerId!;
    _Racer? racer = room.racers[playerId];
    final bool rejoining = racer != null;
    if (!rejoining &&
        (room.racers.length >= maximumRacersPerRoom ||
            room.phase != _RoomPhase.lobby)) {
      _error(
        session,
        room.racers.length >= maximumRacersPerRoom
            ? 'room_full'
            : 'race_in_progress',
        room.racers.length >= maximumRacersPerRoom
            ? 'That room already has eight racers.'
            : 'That race is already in progress.',
      );
      return;
    }

    if (racer == null) {
      racer = _Racer(id: playerId, name: session.name!);
      room.racers[playerId] = racer;
      room.hostId ??= playerId;
    } else {
      final _ClientSession? oldSession = racer.session;
      if (oldSession != null && oldSession != session) {
        oldSession.roomCode = null;
        _error(
          oldSession,
          'session_replaced',
          'This racer reconnected from another device.',
        );
        unawaited(oldSession.channel.sink.close());
      }
      racer.name = session.name!;
    }
    racer.cleanupTimer?.cancel();
    racer
      ..cleanupTimer = null
      ..connected = true
      ..session = session;
    session.roomCode = room.code;
    _matchmakingQueue.remove(session);

    _send(session, <String, Object>{
      'type': 'room_joined',
      'code': room.code,
      'rejoined': rejoining,
    });
    if (broadcast) {
      _broadcastRoomState(room);
    }
  }

  void _setReady(_ClientSession session, bool ready) {
    final (_Room room, _Racer racer)? membership = _membership(session);
    if (membership == null) {
      return;
    }
    if (membership.$1.phase != _RoomPhase.lobby) {
      _error(session, 'race_started', 'Ready state is locked for this race.');
      return;
    }
    membership.$2.ready = ready;
    _broadcastRoomState(membership.$1);
  }

  void _startRace(_ClientSession session, Map<String, dynamic> message) {
    final (_Room room, _Racer racer)? membership = _membership(session);
    if (membership == null) {
      return;
    }
    final _Room room = membership.$1;
    if (room.hostId != membership.$2.id) {
      _error(session, 'host_only', 'Only the host can start the race.');
      return;
    }
    final List<_Racer> activeRacers = room.racers.values
        .where((_Racer racer) => racer.connected)
        .toList(growable: false);
    if (room.phase != _RoomPhase.lobby ||
        activeRacers.length < 2 ||
        activeRacers.any((_Racer racer) => !racer.ready)) {
      _error(
        session,
        'not_ready',
        'At least two connected racers must all be ready.',
      );
      return;
    }

    room
      ..goalMeters = (_number(message['goalMeters']) ?? 1000)
          .clamp(100, 10000)
          .toDouble()
      ..phase = _RoomPhase.countdown
      ..startsAt = DateTime.now().add(countdownDuration);
    for (final _Racer racer in room.racers.values) {
      racer
        ..speedKph = 0
        ..distanceMeters = 0
        ..position = 0
        ..finished = false
        ..finishPlace = null
        ..finishedAt = null;
    }
    _broadcast(room, <String, Object>{
      'type': 'race_start',
      'code': room.code,
      'startsAt': room.startsAt!.millisecondsSinceEpoch,
      'goalMeters': room.goalMeters,
    });
    _broadcastRoomState(room);
    room.startTimer?.cancel();
    room.startTimer = Timer(room.startsAt!.difference(DateTime.now()), () {
      if (_rooms[room.code] != room || room.phase != _RoomPhase.countdown) {
        return;
      }
      room.phase = _RoomPhase.racing;
      _broadcast(room, <String, Object>{
        'type': 'race_go',
        'startsAt': room.startsAt!.millisecondsSinceEpoch,
      });
      _broadcastRoomState(room);
    });
  }

  void _relayTelemetry(_ClientSession session, Map<String, dynamic> message) {
    final (_Room room, _Racer racer)? membership = _membership(
      session,
      reportError: false,
    );
    if (membership == null || membership.$1.phase != _RoomPhase.racing) {
      return;
    }
    final _Room room = membership.$1;
    final _Racer racer = membership.$2;
    final double speedKph = (_number(message['speedKph']) ?? 0)
        .clamp(0, 100)
        .toDouble();
    final double distanceMeters = (_number(message['distanceMeters']) ?? 0)
        .clamp(0, room.goalMeters + 100)
        .toDouble();
    final double position = (_number(message['position']) ?? 0)
        .clamp(0, 1)
        .toDouble();
    if (!speedKph.isFinite || !distanceMeters.isFinite || !position.isFinite) {
      return;
    }

    racer
      ..speedKph = speedKph
      ..distanceMeters = max(racer.distanceMeters, distanceMeters)
      ..position = max(racer.position, position)
      ..lastTelemetryAt = DateTime.now();
    final bool justFinished =
        !racer.finished &&
        (message['finished'] == true ||
            racer.distanceMeters >= room.goalMeters);
    if (justFinished) {
      final int finishPlace =
          room.racers.values.where((_Racer other) => other.finished).length + 1;
      racer
        ..finished = true
        ..finishPlace = finishPlace
        ..finishedAt = DateTime.now()
        ..distanceMeters = max(racer.distanceMeters, room.goalMeters)
        ..position = 1;
    }

    _broadcast(room, <String, Object?>{
      'type': 'opponent_telemetry',
      ..._racerJson(room, racer),
    }, except: session);
    if (justFinished) {
      _broadcast(room, <String, Object?>{
        'type': 'racer_finished',
        ..._racerJson(room, racer),
      });
      _broadcastRoomState(room);
      _completeRoomIfFinished(room);
    }
  }

  void _relayPresetMessage(
    _ClientSession session,
    Map<String, dynamic> message,
  ) {
    final (_Room room, _Racer racer)? membership = _membership(session);
    if (membership == null) {
      return;
    }
    final String text = message['message'] as String? ?? '';
    if (!const <String>{'GOOD LUCK', 'NICE PACE', 'GG'}.contains(text)) {
      _error(
        session,
        'invalid_preset',
        'Only preset race messages are allowed.',
      );
      return;
    }
    _broadcast(membership.$1, <String, Object>{
      'type': 'preset_message',
      'senderId': membership.$2.id,
      'senderName': membership.$2.name,
      'message': text,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  (_Room, _Racer)? _membership(
    _ClientSession session, {
    bool reportError = true,
  }) {
    final String? code = session.roomCode;
    final String? playerId = session.playerId;
    final _Room? room = code == null ? null : _rooms[code];
    final _Racer? racer = playerId == null ? null : room?.racers[playerId];
    if (room == null || racer == null) {
      if (reportError) {
        _error(session, 'not_in_room', 'Join a room first.');
      }
      return null;
    }
    return (room, racer);
  }

  void _handleDisconnect(_ClientSession session) {
    if (session.closed) {
      return;
    }
    session.closed = true;
    _sessions.remove(session);
    _matchmakingQueue.remove(session);
    final (_Room room, _Racer racer)? membership = _membership(
      session,
      reportError: false,
    );
    if (membership == null) {
      return;
    }
    final _Room room = membership.$1;
    final _Racer racer = membership.$2;
    racer
      ..connected = false
      ..session = null
      ..lastTelemetryAt = DateTime.now();
    _broadcast(room, <String, Object>{
      'type': 'racer_disconnected',
      'id': racer.id,
      'name': racer.name,
    });
    _broadcastRoomState(room);
    racer.cleanupTimer?.cancel();
    racer.cleanupTimer = Timer(disconnectedRacerRetention, () {
      if (!racer.connected && room.racers[racer.id] == racer) {
        room.racers.remove(racer.id);
        _afterRacerRemoved(room);
      }
    });
  }

  void _leaveRoom(_ClientSession session, {required bool notifyRacer}) {
    _matchmakingQueue.remove(session);
    final (_Room room, _Racer racer)? membership = _membership(
      session,
      reportError: false,
    );
    session.roomCode = null;
    if (membership == null) {
      return;
    }
    membership.$2.cleanupTimer?.cancel();
    membership.$1.racers.remove(membership.$2.id);
    if (notifyRacer) {
      _broadcast(membership.$1, <String, Object>{
        'type': 'racer_left',
        'id': membership.$2.id,
        'name': membership.$2.name,
      });
    }
    _afterRacerRemoved(membership.$1);
  }

  void _afterRacerRemoved(_Room room) {
    if (room.racers.isEmpty) {
      room.startTimer?.cancel();
      _rooms.remove(room.code);
      return;
    }
    if (!room.racers.containsKey(room.hostId)) {
      final Iterable<_Racer> connected = room.racers.values.where(
        (_Racer racer) => racer.connected,
      );
      room.hostId =
          (connected.isNotEmpty ? connected.first : room.racers.values.first)
              .id;
    }
    _broadcastRoomState(room);
    _completeRoomIfFinished(room);
  }

  void _completeRoomIfFinished(_Room room) {
    if (room.phase != _RoomPhase.racing) {
      return;
    }
    final List<_Racer> remaining = room.racers.values
        .where((_Racer racer) => racer.connected)
        .toList(growable: false);
    if (remaining.isNotEmpty &&
        remaining.every((_Racer racer) => racer.finished)) {
      room.phase = _RoomPhase.finished;
      _broadcast(room, <String, Object?>{
        'type': 'race_complete',
        'winnerId': room.racers.values
            .where((_Racer racer) => racer.finishPlace == 1)
            .firstOrNull
            ?.id,
      });
      _broadcastRoomState(room);
    }
  }

  void _broadcastRoomState(_Room room) {
    _broadcast(room, <String, Object?>{
      'type': 'room_state',
      'code': room.code,
      'phase': room.phase.name,
      'hostId': room.hostId,
      'goalMeters': room.goalMeters,
      'startsAt': room.startsAt?.millisecondsSinceEpoch,
      'racers': room.racers.values
          .map(((_Racer racer) => _racerJson(room, racer)))
          .toList(growable: false),
    });
  }

  Map<String, Object?> _racerJson(_Room room, _Racer racer) {
    return <String, Object?>{
      'id': racer.id,
      'name': racer.name,
      'ready': racer.ready,
      'connected': racer.connected,
      'isHost': racer.id == room.hostId,
      'speedKph': racer.speedKph,
      'distanceMeters': racer.distanceMeters,
      'position': racer.position,
      'finished': racer.finished,
      'finishPlace': racer.finishPlace,
      'finishedAt': racer.finishedAt?.millisecondsSinceEpoch,
    };
  }

  void _broadcast(
    _Room room,
    Map<String, Object?> message, {
    _ClientSession? except,
  }) {
    for (final _Racer racer in room.racers.values) {
      final _ClientSession? target = racer.session;
      if (target != null && target != except && !target.closed) {
        _send(target, message);
      }
    }
  }

  void _send(_ClientSession session, Map<String, Object?> message) {
    if (session.closed) {
      return;
    }
    try {
      session.channel.sink.add(jsonEncode(message));
    } on Object {
      _handleDisconnect(session);
    }
  }

  void _error(_ClientSession session, String code, String humanMessage) {
    _send(session, <String, Object>{
      'type': 'error',
      'code': code,
      'message': humanMessage,
    });
  }

  String _newRoomCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (int attempt = 0; attempt < 1000; attempt++) {
      final String code = List<String>.generate(
        4,
        (int index) => alphabet[_random.nextInt(alphabet.length)],
        growable: false,
      ).join();
      if (!_rooms.containsKey(code)) {
        return code;
      }
    }
    throw StateError('Unable to allocate a room code.');
  }

  String _randomId(int length) {
    const String alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
    return List<String>.generate(
      length,
      (int index) => alphabet[_random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }

  String _cleanName(String? value) {
    final String cleaned = (value ?? 'Racer')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (cleaned.isEmpty) {
      return 'Racer';
    }
    return cleaned.length <= 20 ? cleaned : cleaned.substring(0, 20);
  }

  double? _number(Object? value) {
    if (value is! num) {
      return null;
    }
    return value.toDouble();
  }

  Future<void> close() async {
    for (final _Room room in _rooms.values) {
      room.startTimer?.cancel();
      for (final _Racer racer in room.racers.values) {
        racer.cleanupTimer?.cancel();
      }
    }
    final List<_ClientSession> sessions = _sessions.toList(growable: false);
    for (final _ClientSession session in sessions) {
      session.closed = true;
      await session.channel.sink.close();
    }
    _sessions.clear();
    _rooms.clear();
    _matchmakingQueue.clear();
  }
}

enum _RoomPhase { lobby, countdown, racing, finished }

class _Room {
  _Room({required this.code});

  final String code;
  final Map<String, _Racer> racers = <String, _Racer>{};
  String? hostId;
  _RoomPhase phase = _RoomPhase.lobby;
  double goalMeters = 1000;
  DateTime? startsAt;
  Timer? startTimer;
}

class _Racer {
  _Racer({required this.id, required this.name});

  final String id;
  String name;
  bool ready = false;
  bool connected = true;
  double speedKph = 0;
  double distanceMeters = 0;
  double position = 0;
  bool finished = false;
  int? finishPlace;
  DateTime? finishedAt;
  DateTime lastTelemetryAt = DateTime.now();
  _ClientSession? session;
  Timer? cleanupTimer;
}

class _ClientSession {
  _ClientSession({required this.connectionId, required this.channel});

  final String connectionId;
  final WebSocketChannel channel;
  String? playerId;
  String? name;
  String? roomCode;
  bool closed = false;
}
