import 'dart:async';
import 'dart:io';

import 'package:cardio_quest/models/multiplayer_models.dart';
import 'package:cardio_quest/server/relay_server.dart';
import 'package:cardio_quest/services/multiplayer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  late RelayServer relay;
  late HttpServer server;
  late MultiplayerService host;
  late MultiplayerService guest;

  setUp(() async {
    relay = RelayServer(countdownDuration: const Duration(milliseconds: 20));
    server = await shelf_io.serve(
      relay.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    final Uri relayUri = Uri.parse(
      'ws://${server.address.host}:${server.port}/ws',
    );
    host = MultiplayerService(
      serverUri: relayUri,
      playerId: 'service_host_123',
    );
    guest = MultiplayerService(
      serverUri: relayUri,
      playerId: 'service_guest_456',
    );
  });

  tearDown(() async {
    await host.disconnect();
    await guest.disconnect();
    host.dispose();
    guest.dispose();
    await server.close(force: true);
    await relay.close();
  });

  test(
    'client services synchronize room, race, chat, and finish state',
    () async {
      expect(await host.createRoom('Host'), isTrue);
      await _waitFor(host, () => host.roomCode != null);

      expect(await guest.joinRoom(host.roomCode!, 'Guest'), isTrue);
      await _waitFor(host, () => host.racers.length == 2);
      await _waitFor(guest, () => guest.racers.length == 2);

      expect(host.setReady(true), isTrue);
      expect(guest.setReady(true), isTrue);
      await _waitFor(host, () => host.allReady);

      expect(host.startRace(goalMeters: 100), isTrue);
      await _waitFor(host, () => host.roomPhase == MultiplayerRoomPhase.racing);
      await _waitFor(
        guest,
        () => guest.roomPhase == MultiplayerRoomPhase.racing,
      );

      expect(
        host.sendTelemetry(speedKph: 12.5, distanceMeters: 42, position: 0.42),
        isTrue,
      );
      await _waitFor(guest, () => guest.opponents.single.distanceMeters == 42);
      expect(guest.opponents.single.speedKph, 12.5);

      expect(host.sendPresetMessage(PresetRaceMessage.nicePace), isTrue);
      await _waitFor(guest, () => guest.chatMessages.isNotEmpty);
      expect(guest.chatMessages.last.message, PresetRaceMessage.nicePace);

      host.sendTelemetry(
        speedKph: 12,
        distanceMeters: 100,
        position: 1,
        finished: true,
      );
      await _waitFor(host, () => host.localRacer?.finishPlace == 1);
      guest.sendTelemetry(
        speedKph: 11,
        distanceMeters: 100,
        position: 1,
        finished: true,
      );
      await _waitFor(
        host,
        () => host.roomPhase == MultiplayerRoomPhase.finished,
      );
      expect(host.winnerId, host.playerId);
      expect(host.localRacer?.finishPlace, 1);
    },
  );

  test('client reconnects with exponential backoff after relay loss', () async {
    expect(await host.connect(), isTrue);
    expect(host.connectionState, MultiplayerConnectionState.connected);
    final int port = server.port;

    await server.close(force: true);
    await relay.close();
    await _waitFor(
      host,
      () => host.connectionState == MultiplayerConnectionState.unavailable,
    );

    relay = RelayServer();
    server = await shelf_io.serve(
      relay.handler,
      InternetAddress.loopbackIPv4,
      port,
    );
    await _waitFor(
      host,
      () => host.connectionState == MultiplayerConnectionState.connected,
      timeoutAfter: const Duration(seconds: 4),
    );
  });
}

Future<void> _waitFor(
  MultiplayerService service,
  bool Function() predicate, {
  Duration timeoutAfter = const Duration(seconds: 2),
}) {
  if (predicate()) {
    return Future<void>.value();
  }
  final Completer<void> completer = Completer<void>();
  late final Timer timeout;

  void listener() {
    if (!completer.isCompleted && predicate()) {
      completer.complete();
    }
  }

  service.addListener(listener);
  timeout = Timer(timeoutAfter, () {
    if (!completer.isCompleted) {
      completer.completeError(
        TimeoutException('Timed out waiting for multiplayer state.'),
      );
    }
  });
  return completer.future.whenComplete(() {
    timeout.cancel();
    service.removeListener(listener);
  });
}
