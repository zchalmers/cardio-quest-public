import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'relay_server.dart';

Future<void> main(List<String> arguments) async {
  final String host = _argument(
    arguments,
    '--host',
    Platform.environment['CARDIO_QUEST_RELAY_HOST'] ?? '0.0.0.0',
  );
  final int port =
      int.tryParse(
        _argument(arguments, '--port', Platform.environment['PORT'] ?? '8080'),
      ) ??
      8080;

  final RelayServer relay = RelayServer();
  final HttpServer server = await shelf_io.serve(
    relay.handler,
    host,
    port,
    poweredByHeader: 'Cardio Quest Relay',
  );
  stdout.writeln(
    'Cardio Quest relay listening on '
    'http://${server.address.host}:${server.port} (WebSocket: /ws)',
  );

  Future<void> shutdown(ProcessSignal signal) async {
    stdout.writeln('Received $signal; shutting down.');
    await server.close(force: true);
    await relay.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen(shutdown);
  }
}

String _argument(List<String> arguments, String name, String fallback) {
  final int equalsIndex = arguments.indexWhere(
    (String value) => value.startsWith('$name='),
  );
  if (equalsIndex >= 0) {
    return arguments[equalsIndex].substring(name.length + 1);
  }
  final int index = arguments.indexOf(name);
  if (index >= 0 && index + 1 < arguments.length) {
    return arguments[index + 1];
  }
  return fallback;
}
