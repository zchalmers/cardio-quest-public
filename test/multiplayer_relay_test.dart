import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cardio_quest/server/relay_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  late RelayServer relay;
  late HttpServer server;
  final List<WebSocket> sockets = <WebSocket>[];

  setUp(() async {
    relay = RelayServer(countdownDuration: const Duration(milliseconds: 20));
    server = await shelf_io.serve(
      relay.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
  });

  tearDown(() async {
    for (final WebSocket socket in sockets) {
      await socket.close();
    }
    sockets.clear();
    await server.close(force: true);
    await relay.close();
  });

  Future<_TestSocket> connect() async {
    final WebSocket socket = await WebSocket.connect(
      'ws://${server.address.host}:${server.port}/ws',
    );
    sockets.add(socket);
    final _TestSocket client = _TestSocket(socket);
    expect((await client.next('welcome'))['connectionId'], isNotEmpty);
    return client;
  }

  test(
    'creates, joins, races, relays telemetry, and reports disconnects',
    () async {
      final _TestSocket host = await connect();
      final _TestSocket guest = await connect();

      host.send(<String, Object>{
        'type': 'create_room',
        'playerId': 'player_host_123',
        'name': 'Host',
      });
      final Map<String, dynamic> hostJoined = await host.next('room_joined');
      final String code = hostJoined['code'] as String;
      expect(code, hasLength(4));
      await host.next('room_state');

      guest.send(<String, Object>{
        'type': 'join_room',
        'code': code,
        'playerId': 'player_guest_456',
        'name': 'Guest',
      });
      await guest.next('room_joined');
      final Map<String, dynamic> joinedState = await guest.next('room_state');
      expect(joinedState['racers'], hasLength(2));
      await host.next('room_state');

      host.send(<String, Object>{'type': 'set_ready', 'ready': true});
      await host.next('room_state');
      await guest.next('room_state');
      guest.send(<String, Object>{'type': 'set_ready', 'ready': true});
      await host.next('room_state');
      await guest.next('room_state');

      host.send(<String, Object>{'type': 'start_race', 'goalMeters': 500});
      final Map<String, dynamic> start = await host.next('race_start');
      expect(start['goalMeters'], 500);
      await guest.next('race_start');
      await host.next('race_go');
      await guest.next('race_go');

      host.send(<String, Object>{
        'type': 'telemetry',
        'speedKph': 11.2,
        'distanceMeters': 42.5,
        'position': 0.085,
        'finished': false,
      });
      final Map<String, dynamic> telemetry = await guest.next(
        'opponent_telemetry',
      );
      expect(telemetry['id'], 'player_host_123');
      expect(telemetry['speedKph'], 11.2);
      expect(telemetry['distanceMeters'], 42.5);

      await host.socket.close();
      final Map<String, dynamic> disconnected = await guest.next(
        'racer_disconnected',
      );
      expect(disconnected['id'], 'player_host_123');
    },
  );

  test('quick match pairs two waiting racers into the same room', () async {
    final _TestSocket first = await connect();
    final _TestSocket second = await connect();

    first.send(<String, Object>{
      'type': 'matchmake',
      'playerId': 'quick_player_one',
      'name': 'One',
    });
    expect((await first.next('matchmaking'))['status'], 'waiting');

    second.send(<String, Object>{
      'type': 'matchmake',
      'playerId': 'quick_player_two',
      'name': 'Two',
    });
    final String firstCode =
        (await first.next('room_joined'))['code'] as String;
    final String secondCode =
        (await second.next('room_joined'))['code'] as String;
    expect(secondCode, firstCode);
    expect((await second.next('room_state'))['racers'], hasLength(2));
  });

  test('rooms reject a ninth racer', () async {
    final _TestSocket host = await connect();
    host.send(<String, Object>{
      'type': 'create_room',
      'playerId': 'capacity_host_123',
      'name': 'Host',
    });
    final String code = (await host.next('room_joined'))['code'] as String;

    for (int index = 1; index < maximumRacersPerRoom; index++) {
      final _TestSocket racer = await connect();
      racer.send(<String, Object>{
        'type': 'join_room',
        'code': code,
        'playerId': 'capacity_racer_$index',
        'name': 'Racer $index',
      });
      expect((await racer.next('room_joined'))['code'], code);
    }

    final _TestSocket ninth = await connect();
    ninth.send(<String, Object>{
      'type': 'join_room',
      'code': code,
      'playerId': 'capacity_racer_9',
      'name': 'Ninth',
    });
    final Map<String, dynamic> error = await ninth.next('error');
    expect(error['code'], 'room_full');
  });
}

class _TestSocket {
  _TestSocket(this.socket) : _iterator = StreamIterator<dynamic>(socket);

  final WebSocket socket;
  final StreamIterator<dynamic> _iterator;

  void send(Map<String, Object> message) {
    socket.add(jsonEncode(message));
  }

  Future<Map<String, dynamic>> next(String type) async {
    while (await _iterator.moveNext().timeout(const Duration(seconds: 2))) {
      final Object? decoded = jsonDecode(_iterator.current as String);
      if (decoded is Map) {
        final Map<String, dynamic> message = decoded.cast<String, dynamic>();
        if (message['type'] == type) {
          return message;
        }
      }
    }
    throw StateError('Socket closed before receiving $type.');
  }
}
