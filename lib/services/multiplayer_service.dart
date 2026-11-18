import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/multiplayer_models.dart';

const String _defaultRelayUrl = String.fromEnvironment(
  'MULTIPLAYER_SERVER_URL',
  defaultValue: 'ws://localhost:8080/ws',
);

class MultiplayerService extends ChangeNotifier {
  MultiplayerService({Uri? serverUri, String? playerId, Random? random})
    : serverUri = serverUri ?? Uri.parse(_defaultRelayUrl),
      playerId = playerId ?? _newPlayerId(random ?? Random.secure());

  final Uri serverUri;
  final String playerId;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _reconnectTimer;
  Future<bool>? _connectionFuture;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  int _serverClockOffsetMilliseconds = 0;
  bool _disposed = false;
  bool _allowReconnect = true;

  MultiplayerConnectionState _connectionState =
      MultiplayerConnectionState.disconnected;
  MultiplayerRoomPhase _roomPhase = MultiplayerRoomPhase.lobby;
  final Map<String, MultiplayerRacer> _racers = <String, MultiplayerRacer>{};
  final List<RaceChatMessage> _chatMessages = <RaceChatMessage>[];
  String? _roomCode;
  String? _desiredRoomCode;
  String? _playerName;
  String? _errorMessage;
  String? _winnerId;
  DateTime? _raceStartsAt;
  double _goalMeters = 1000;
  bool _waitingForMatch = false;

  MultiplayerConnectionState get connectionState => _connectionState;
  MultiplayerRoomPhase get roomPhase => _roomPhase;
  String? get roomCode => _roomCode;
  String? get errorMessage => _errorMessage;
  String? get winnerId => _winnerId;
  DateTime? get raceStartsAt => _raceStartsAt;
  double get goalMeters => _goalMeters;
  bool get waitingForMatch => _waitingForMatch;
  bool get isConnected =>
      _connectionState == MultiplayerConnectionState.connected;
  bool get isInRoom => _roomCode != null;
  bool get isHost => localRacer?.isHost ?? false;
  bool get allReady {
    final List<MultiplayerRacer> connected = _racers.values
        .where((MultiplayerRacer racer) => racer.connected)
        .toList(growable: false);
    return connected.length >= 2 &&
        connected.every((MultiplayerRacer racer) => racer.ready);
  }

  MultiplayerRacer? get localRacer => _racers[playerId];
  List<MultiplayerRacer> get racers =>
      List<MultiplayerRacer>.unmodifiable(_racers.values);
  List<MultiplayerRacer> get opponents => List<MultiplayerRacer>.unmodifiable(
    _racers.values.where((MultiplayerRacer racer) => racer.id != playerId),
  );
  List<RaceChatMessage> get chatMessages =>
      List<RaceChatMessage>.unmodifiable(_chatMessages);

  List<MultiplayerRacer> get leaderboard {
    final List<MultiplayerRacer> sorted = _racers.values.toList();
    sorted.sort((MultiplayerRacer a, MultiplayerRacer b) {
      final int? aPlace = a.finishPlace;
      final int? bPlace = b.finishPlace;
      if (aPlace != null || bPlace != null) {
        if (aPlace == null) {
          return 1;
        }
        if (bPlace == null) {
          return -1;
        }
        return aPlace.compareTo(bPlace);
      }
      final int distanceOrder = b.distanceMeters.compareTo(a.distanceMeters);
      return distanceOrder != 0 ? distanceOrder : a.name.compareTo(b.name);
    });
    return List<MultiplayerRacer>.unmodifiable(sorted);
  }

  Future<bool> connect() {
    if (_disposed) {
      return Future<bool>.value(false);
    }
    if (isConnected) {
      return Future<bool>.value(true);
    }
    return _connectionFuture ??= _openSocket().whenComplete(() {
      _connectionFuture = null;
    });
  }

  Future<bool> _openSocket() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final int generation = ++_connectionGeneration;
    _connectionState = _reconnectAttempt == 0
        ? MultiplayerConnectionState.connecting
        : MultiplayerConnectionState.reconnecting;
    _errorMessage = null;
    notifyListeners();

    WebSocketChannel? channel;
    try {
      final WebSocketChannel openedChannel = WebSocketChannel.connect(
        serverUri,
      );
      channel = openedChannel;
      _channel = openedChannel;
      _subscription = openedChannel.stream.listen(
        _handleRawMessage,
        onDone: () => _socketClosed(openedChannel),
        onError: (Object error, StackTrace stackTrace) =>
            _socketClosed(openedChannel, error: error),
        cancelOnError: true,
      );
      await openedChannel.ready.timeout(const Duration(seconds: 5));
      if (_disposed || generation != _connectionGeneration) {
        await openedChannel.sink.close();
        return false;
      }
      _connectionState = MultiplayerConnectionState.connected;
      _reconnectAttempt = 0;
      _errorMessage = null;
      notifyListeners();
      final String? desiredRoom = _desiredRoomCode;
      final String? name = _playerName;
      if (desiredRoom != null && name != null) {
        _send(<String, Object>{
          'type': 'join_room',
          'code': desiredRoom,
          'playerId': playerId,
          'name': name,
        });
      } else if (_waitingForMatch && name != null) {
        _send(<String, Object>{
          'type': 'matchmake',
          'playerId': playerId,
          'name': name,
        });
      }
      return true;
    } on Object {
      if (generation != _connectionGeneration || _disposed) {
        return false;
      }
      if (_channel == channel) {
        _channel = null;
      }
      await _subscription?.cancel();
      _subscription = null;
      await channel?.sink.close();
      _connectionState = MultiplayerConnectionState.unavailable;
      _errorMessage =
          'Multiplayer relay is unreachable. Single-player modes still work.';
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }

  Future<bool> createRoom(String name) async {
    _prepareForRoom(name);
    if (!await connect()) {
      return false;
    }
    return _send(<String, Object>{
      'type': 'create_room',
      'playerId': playerId,
      'name': _playerName!,
    });
  }

  Future<bool> joinRoom(String code, String name) async {
    final String normalizedCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(normalizedCode)) {
      _errorMessage = 'Enter a four-character room code.';
      notifyListeners();
      return false;
    }
    _prepareForRoom(name);
    _desiredRoomCode = normalizedCode;
    if (!await connect()) {
      return false;
    }
    return _send(<String, Object>{
      'type': 'join_room',
      'code': normalizedCode,
      'playerId': playerId,
      'name': _playerName!,
    });
  }

  Future<bool> findMatch(String name) async {
    _prepareForRoom(name);
    if (!await connect()) {
      return false;
    }
    _waitingForMatch = true;
    notifyListeners();
    return _send(<String, Object>{
      'type': 'matchmake',
      'playerId': playerId,
      'name': _playerName!,
    });
  }

  void _prepareForRoom(String name) {
    _allowReconnect = true;
    _errorMessage = null;
    _winnerId = null;
    _roomCode = null;
    _desiredRoomCode = null;
    _roomPhase = MultiplayerRoomPhase.lobby;
    _raceStartsAt = null;
    _racers.clear();
    _chatMessages.clear();
    _waitingForMatch = false;
    final String cleaned = name.trim();
    _playerName = cleaned.isEmpty
        ? 'Racer'
        : cleaned.substring(0, min(20, cleaned.length));
    notifyListeners();
  }

  bool setReady(bool ready) {
    return _send(<String, Object>{'type': 'set_ready', 'ready': ready});
  }

  bool startRace({required double goalMeters}) {
    return _send(<String, Object>{
      'type': 'start_race',
      'goalMeters': goalMeters,
    });
  }

  bool sendTelemetry({
    required double speedKph,
    required double distanceMeters,
    required double position,
    bool finished = false,
  }) {
    if (_roomPhase != MultiplayerRoomPhase.racing) {
      return false;
    }
    final MultiplayerRacer? current = localRacer;
    if (current != null) {
      _racers[playerId] = current.copyWith(
        speedKph: speedKph,
        distanceMeters: distanceMeters,
        position: position,
        finished: finished || current.finished,
        lastTelemetryAt: DateTime.now(),
      );
      notifyListeners();
    }
    return _send(<String, Object>{
      'type': 'telemetry',
      'speedKph': speedKph,
      'distanceMeters': distanceMeters,
      'position': position,
      'finished': finished,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  bool sendPresetMessage(PresetRaceMessage message) {
    return _send(<String, Object>{
      'type': 'preset_message',
      'message': message.text,
    });
  }

  void leaveRoom() {
    if (isConnected && _roomCode != null) {
      _send(const <String, Object>{'type': 'leave_room'});
    }
    _clearRoom();
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void _handleRawMessage(Object? rawMessage) {
    if (rawMessage is! String) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(rawMessage);
      if (decoded is! Map) {
        return;
      }
      final Map<String, dynamic> message = decoded.cast<String, dynamic>();
      switch (message['type']) {
        case 'welcome':
          final Object? rawServerTime = message['serverTime'];
          if (rawServerTime is num) {
            _serverClockOffsetMilliseconds =
                rawServerTime.toInt() - DateTime.now().millisecondsSinceEpoch;
          }
        case 'room_joined':
          _roomCode = message['code'] as String?;
          _desiredRoomCode = _roomCode;
          _waitingForMatch = false;
          _errorMessage = null;
        case 'matchmaking':
          _waitingForMatch = message['status'] == 'waiting';
        case 'room_state':
          _applyRoomState(message);
        case 'race_start':
          _roomPhase = MultiplayerRoomPhase.countdown;
          _goalMeters = _asDouble(message['goalMeters']) ?? _goalMeters;
          _raceStartsAt = _serverDateTime(message['startsAt']);
        case 'race_go':
          _roomPhase = MultiplayerRoomPhase.racing;
          _raceStartsAt = _serverDateTime(message['startsAt']) ?? _raceStartsAt;
        case 'opponent_telemetry':
        case 'racer_finished':
          _applyRacerUpdate(message);
        case 'racer_disconnected':
        case 'racer_left':
          _markRacerDisconnected(message['id'] as String?);
        case 'preset_message':
          _applyChatMessage(message);
        case 'race_complete':
          _winnerId = message['winnerId'] as String?;
          _roomPhase = MultiplayerRoomPhase.finished;
        case 'error':
          _applyServerError(message);
        default:
          return;
      }
      notifyListeners();
    } on Object {
      // Ignore malformed relay frames without taking down an active workout.
    }
  }

  void _applyRoomState(Map<String, dynamic> message) {
    _roomCode = message['code'] as String? ?? _roomCode;
    _desiredRoomCode = _roomCode;
    _goalMeters = _asDouble(message['goalMeters']) ?? _goalMeters;
    _raceStartsAt = _serverDateTime(message['startsAt']) ?? _raceStartsAt;
    _roomPhase = switch (message['phase']) {
      'countdown' => MultiplayerRoomPhase.countdown,
      'racing' => MultiplayerRoomPhase.racing,
      'finished' => MultiplayerRoomPhase.finished,
      _ => MultiplayerRoomPhase.lobby,
    };
    final Object? rawRacers = message['racers'];
    if (rawRacers is! List) {
      return;
    }
    final Set<String> present = <String>{};
    for (final Object? rawRacer in rawRacers) {
      if (rawRacer is! Map) {
        continue;
      }
      final Map<String, dynamic> racerJson = rawRacer.cast<String, dynamic>();
      final String? id = racerJson['id'] as String?;
      if (id == null || id.isEmpty) {
        continue;
      }
      present.add(id);
      _racers[id] = MultiplayerRacer.fromJson(racerJson, previous: _racers[id]);
    }
    for (final String id in _racers.keys.toList(growable: false)) {
      if (!present.contains(id)) {
        _markRacerDisconnected(id);
      }
    }
  }

  void _applyRacerUpdate(Map<String, dynamic> message) {
    final String? id = message['id'] as String?;
    if (id == null || id.isEmpty) {
      return;
    }
    _racers[id] = MultiplayerRacer.fromJson(message, previous: _racers[id]);
  }

  void _markRacerDisconnected(String? id) {
    if (id == null) {
      return;
    }
    final MultiplayerRacer? racer = _racers[id];
    if (racer != null) {
      _racers[id] = racer.copyWith(
        connected: false,
        lastTelemetryAt: DateTime.now(),
      );
    }
  }

  void _applyChatMessage(Map<String, dynamic> message) {
    final PresetRaceMessage? preset = PresetRaceMessage.fromText(
      message['message'] as String? ?? '',
    );
    if (preset == null) {
      return;
    }
    _chatMessages.add(
      RaceChatMessage(
        senderId: message['senderId'] as String? ?? '',
        senderName: message['senderName'] as String? ?? 'Racer',
        message: preset,
        receivedAt: _serverDateTime(message['sentAt']) ?? DateTime.now(),
      ),
    );
    if (_chatMessages.length > 8) {
      _chatMessages.removeAt(0);
    }
  }

  void _applyServerError(Map<String, dynamic> message) {
    _errorMessage =
        message['message'] as String? ??
        'The multiplayer relay returned an error.';
    final String? code = message['code'] as String?;
    if (code == 'room_not_found' ||
        code == 'room_full' ||
        code == 'race_in_progress') {
      _clearRoom();
    }
  }

  bool _send(Map<String, Object> message) {
    final WebSocketChannel? channel = _channel;
    if (!isConnected || channel == null) {
      return false;
    }
    try {
      channel.sink.add(jsonEncode(message));
      return true;
    } on Object {
      _socketClosed(channel);
      return false;
    }
  }

  void _socketClosed(WebSocketChannel channel, {Object? error}) {
    if (_disposed || channel != _channel) {
      return;
    }
    _channel = null;
    _subscription = null;
    _connectionState = MultiplayerConnectionState.unavailable;
    _errorMessage =
        'Connection lost. Rejoining the race when the relay returns…';
    for (final MultiplayerRacer racer in opponents) {
      _racers[racer.id] = racer.copyWith(
        connected: false,
        lastTelemetryAt: DateTime.now(),
      );
    }
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || !_allowReconnect || _reconnectTimer != null) {
      return;
    }
    final int exponent = min(_reconnectAttempt, 5);
    final int seconds = min(30, 1 << exponent);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      if (!_disposed && _allowReconnect) {
        unawaited(connect());
      }
    });
  }

  void _clearRoom() {
    _roomCode = null;
    _desiredRoomCode = null;
    _roomPhase = MultiplayerRoomPhase.lobby;
    _raceStartsAt = null;
    _winnerId = null;
    _waitingForMatch = false;
    _racers.clear();
    _chatMessages.clear();
  }

  DateTime? _serverDateTime(Object? value) {
    if (value is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() - _serverClockOffsetMilliseconds,
    );
  }

  Future<void> disconnect() async {
    _allowReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_roomCode != null) {
      _send(const <String, Object>{'type': 'leave_room'});
    }
    _clearRoom();
    final WebSocketChannel? channel = _channel;
    _channel = null;
    _connectionGeneration++;
    await _subscription?.cancel();
    _subscription = null;
    await channel?.sink.close();
    _connectionState = MultiplayerConnectionState.disconnected;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _allowReconnect = false;
    _reconnectTimer?.cancel();
    _connectionGeneration++;
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    _subscription = null;
    _channel = null;
    super.dispose();
  }

  static String _newPlayerId(Random random) {
    const String alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
    final String randomPart = List<String>.generate(
      18,
      (int index) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
    return 'cq_$randomPart';
  }
}

double? _asDouble(Object? value) {
  return value is num ? value.toDouble() : null;
}
