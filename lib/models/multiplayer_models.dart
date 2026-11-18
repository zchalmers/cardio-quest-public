enum MultiplayerConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  unavailable,
}

enum MultiplayerRoomPhase { lobby, countdown, racing, finished }

enum PresetRaceMessage {
  goodLuck('GOOD LUCK'),
  nicePace('NICE PACE'),
  gg('GG');

  const PresetRaceMessage(this.text);

  final String text;

  static PresetRaceMessage? fromText(String value) {
    for (final PresetRaceMessage message in values) {
      if (message.text == value) {
        return message;
      }
    }
    return null;
  }
}

class MultiplayerRacer {
  const MultiplayerRacer({
    required this.id,
    required this.name,
    required this.ready,
    required this.connected,
    required this.isHost,
    required this.speedKph,
    required this.distanceMeters,
    required this.position,
    required this.finished,
    required this.lastTelemetryAt,
    this.finishPlace,
    this.finishedAt,
  });

  factory MultiplayerRacer.fromJson(
    Map<String, dynamic> json, {
    MultiplayerRacer? previous,
  }) {
    final DateTime now = DateTime.now();
    final bool telemetryIncluded =
        json.containsKey('speedKph') ||
        json.containsKey('distanceMeters') ||
        json.containsKey('position');
    return MultiplayerRacer(
      id: json['id'] as String? ?? previous?.id ?? '',
      name: json['name'] as String? ?? previous?.name ?? 'Racer',
      ready: json['ready'] as bool? ?? previous?.ready ?? false,
      connected: json['connected'] as bool? ?? previous?.connected ?? true,
      isHost: json['isHost'] as bool? ?? previous?.isHost ?? false,
      speedKph: _asDouble(json['speedKph']) ?? previous?.speedKph ?? 0,
      distanceMeters:
          _asDouble(json['distanceMeters']) ?? previous?.distanceMeters ?? 0,
      position: _asDouble(json['position']) ?? previous?.position ?? 0,
      finished: json['finished'] as bool? ?? previous?.finished ?? false,
      finishPlace: _asInt(json['finishPlace']) ?? previous?.finishPlace,
      finishedAt:
          _dateTimeFromMilliseconds(json['finishedAt']) ?? previous?.finishedAt,
      lastTelemetryAt: telemetryIncluded
          ? now
          : previous?.lastTelemetryAt ?? now,
    );
  }

  final String id;
  final String name;
  final bool ready;
  final bool connected;
  final bool isHost;
  final double speedKph;
  final double distanceMeters;
  final double position;
  final bool finished;
  final int? finishPlace;
  final DateTime? finishedAt;
  final DateTime lastTelemetryAt;

  MultiplayerRacer copyWith({
    String? name,
    bool? ready,
    bool? connected,
    bool? isHost,
    double? speedKph,
    double? distanceMeters,
    double? position,
    bool? finished,
    int? finishPlace,
    DateTime? finishedAt,
    DateTime? lastTelemetryAt,
  }) {
    return MultiplayerRacer(
      id: id,
      name: name ?? this.name,
      ready: ready ?? this.ready,
      connected: connected ?? this.connected,
      isHost: isHost ?? this.isHost,
      speedKph: speedKph ?? this.speedKph,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      position: position ?? this.position,
      finished: finished ?? this.finished,
      finishPlace: finishPlace ?? this.finishPlace,
      finishedAt: finishedAt ?? this.finishedAt,
      lastTelemetryAt: lastTelemetryAt ?? this.lastTelemetryAt,
    );
  }
}

class RaceChatMessage {
  const RaceChatMessage({
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.receivedAt,
  });

  final String senderId;
  final String senderName;
  final PresetRaceMessage message;
  final DateTime receivedAt;
}

double? _asDouble(Object? value) {
  return switch (value) {
    final num number => number.toDouble(),
    _ => null,
  };
}

int? _asInt(Object? value) {
  return switch (value) {
    final num number => number.toInt(),
    _ => null,
  };
}

DateTime? _dateTimeFromMilliseconds(Object? value) {
  final int? milliseconds = _asInt(value);
  if (milliseconds == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
