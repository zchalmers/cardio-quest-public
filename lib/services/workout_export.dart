import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/machine_models.dart';

class WorkoutHealthExportResult {
  const WorkoutHealthExportResult({
    required this.workoutWritten,
    required this.supportingSamplesWritten,
    this.permissionDenied = false,
    this.message,
  });

  final bool workoutWritten;
  final bool supportingSamplesWritten;
  final bool permissionDenied;
  final String? message;

  bool get succeeded => workoutWritten && supportingSamplesWritten;
}

class WorkoutExport {
  WorkoutExport({this.debugLogging = false});

  final bool debugLogging;

  /// No-op — HealthKit requires a paid Apple Developer account.
  /// On sideloaded builds the entitlement is stripped by SideStore and any
  /// HealthKit API call causes an immediate SIGKILL. FIT / TCX exports are
  /// still available via [createFitFile] and [createTcxFile].
  Future<WorkoutHealthExportResult> writeToHealth(
    GameSummary summary, {
    MachineKind machineKind = MachineKind.treadmill,
    DateTime? endedAt,
  }) async {
    return const WorkoutHealthExportResult(
      workoutWritten: false,
      supportingSamplesWritten: false,
      message:
          'Health export requires a paid Apple Developer account '
          '(HealthKit entitlement). FIT and TCX files are still available.',
    );
  }

  /// Builds a standards-compliant binary FIT activity file in memory.
  Uint8List createFitFile(
    GameSummary summary, {
    MachineKind machineKind = MachineKind.treadmill,
    DateTime? endedAt,
  }) {
    return _FitActivityEncoder(
      summary: summary,
      machineKind: machineKind,
      endedAt: endedAt ?? DateTime.now(),
    ).encode();
  }

  /// Builds a Garmin Training Center XML (TCX v2) activity.
  ///
  /// FIT remains the preferred export because it carries richer summary
  /// fields. TCX is available for Garmin partner tenants that explicitly
  /// require XML uploads.
  Uint8List createTcxFile(
    GameSummary summary, {
    MachineKind machineKind = MachineKind.treadmill,
    DateTime? endedAt,
  }) {
    final DateTime end = (endedAt ?? DateTime.now()).toUtc();
    final DateTime start = end.subtract(summary.duration);
    final List<WorkoutMetricSample> samples = summary.metricSamples.isEmpty
        ? <WorkoutMetricSample>[
            WorkoutMetricSample(
              recordedAt: start,
              elapsed: Duration.zero,
              speedKph: summary.averageSpeedKph,
              inclinePercent: 0,
              distanceMeters: 0,
              heartRateBpm: summary.averageHeartRateBpm,
              heartRateSource: HeartRateSource.none,
            ),
            WorkoutMetricSample(
              recordedAt: end,
              elapsed: summary.duration,
              speedKph: summary.averageSpeedKph,
              inclinePercent: 0,
              distanceMeters: summary.distanceMeters,
              heartRateBpm: summary.maxHeartRateBpm,
              heartRateSource: HeartRateSource.none,
            ),
          ]
        : summary.metricSamples;
    final String sport = switch (machineKind) {
      MachineKind.treadmill => 'Running',
      MachineKind.indoorBike => 'Biking',
      MachineKind.crossTrainer ||
      MachineKind.rower ||
      MachineKind.unknown ||
      MachineKind.simulator => 'Other',
    };
    final StringBuffer xml = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<TrainingCenterDatabase '
      'xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
      'xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2" '
      'xsi:schemaLocation="http://www.garmin.com/xmlschemas/'
      'TrainingCenterDatabase/v2 '
      'http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">'
      '<Activities><Activity Sport="$sport">'
      '<Id>${start.toIso8601String()}</Id>'
      '<Lap StartTime="${start.toIso8601String()}">'
      '<TotalTimeSeconds>${summary.duration.inMilliseconds / 1000}</TotalTimeSeconds>'
      '<DistanceMeters>${summary.distanceMeters.toStringAsFixed(2)}</DistanceMeters>'
      '<MaximumSpeed>${(summary.maxSpeedKph / 3.6).toStringAsFixed(4)}</MaximumSpeed>'
      '<Calories>${summary.activeEnergyCalories.round()}</Calories>'
      '<Intensity>Active</Intensity><TriggerMethod>Manual</TriggerMethod>'
      '<Track>',
    );
    for (final WorkoutMetricSample sample in samples) {
      final DateTime recordedAt = start.add(sample.elapsed).toUtc();
      xml
        ..write('<Trackpoint><Time>${recordedAt.toIso8601String()}</Time>')
        ..write(
          '<DistanceMeters>'
          '${sample.distanceMeters.toStringAsFixed(2)}'
          '</DistanceMeters>',
        );
      if (sample.heartRateBpm > 0) {
        xml.write(
          '<HeartRateBpm><Value>${sample.heartRateBpm}</Value></HeartRateBpm>',
        );
      }
      xml.write(
        '<Extensions><ns3:TPX><ns3:Speed>'
        '${(sample.speedKph / 3.6).toStringAsFixed(4)}'
        '</ns3:Speed></ns3:TPX></Extensions></Trackpoint>',
      );
    }
    xml.write(
      '</Track></Lap></Activity></Activities>'
      '<Author xsi:type="Application_t"><Name>Cardio Quest</Name>'
      '<Build><Version><VersionMajor>1</VersionMajor>'
      '<VersionMinor>0</VersionMinor></Version></Build>'
      '<LangID>EN</LangID><PartNumber>000-00000-00</PartNumber>'
      '</Author></TrainingCenterDatabase>',
    );
    return Uint8List.fromList(utf8.encode(xml.toString()));
  }

  Future<File> writeFitFile(
    GameSummary summary, {
    required String outputPath,
    MachineKind machineKind = MachineKind.treadmill,
    DateTime? endedAt,
  }) async {
    final File output = File(outputPath);
    if (output.path.toLowerCase().endsWith('.fit') == false) {
      throw ArgumentError.value(
        outputPath,
        'outputPath',
        'FIT exports must use a .fit extension.',
      );
    }
    await output.writeAsBytes(
      createFitFile(summary, machineKind: machineKind, endedAt: endedAt),
      flush: true,
    );
    return output;
  }

}

class _FitActivityEncoder {
  _FitActivityEncoder({
    required this.summary,
    required this.machineKind,
    required this.endedAt,
  });

  static final DateTime _fitEpoch = DateTime.utc(1989, 12, 31);
  static const int _protocolVersion = 0x20;
  static const int _profileVersion = 2200;

  final GameSummary summary;
  final MachineKind machineKind;
  final DateTime endedAt;
  final BytesBuilder _data = BytesBuilder(copy: false);

  Uint8List encode() {
    final DateTime startedAt = endedAt.subtract(summary.duration);
    final List<WorkoutMetricSample> records = _records(startedAt);
    final int startTimestamp = _fitTimestamp(startedAt);
    final int endTimestamp = _fitTimestamp(endedAt);
    final int elapsedMilliseconds = summary.duration.inMilliseconds;
    final int distanceCentimeters = _unsigned32(
      (summary.distanceMeters * 100).round(),
    );
    final int calories = _unsigned16(summary.activeEnergyCalories.round());
    final int avgSpeed = _speed(summary.averageSpeedKph);
    final int maxSpeed = _speed(summary.maxSpeedKph);

    _definition(
      localMessage: 0,
      globalMessage: 0,
      fields: const <_FitField>[
        _FitField(0, 1, _FitBaseType.enumeration),
        _FitField(1, 2, _FitBaseType.uint16),
        _FitField(2, 2, _FitBaseType.uint16),
        _FitField(3, 4, _FitBaseType.uint32z),
        _FitField(4, 4, _FitBaseType.uint32),
      ],
    );
    _message(
      0,
      const <_FitField>[
        _FitField(0, 1, _FitBaseType.enumeration),
        _FitField(1, 2, _FitBaseType.uint16),
        _FitField(2, 2, _FitBaseType.uint16),
        _FitField(3, 4, _FitBaseType.uint32z),
        _FitField(4, 4, _FitBaseType.uint32),
      ],
      <int, Object>{0: 4, 1: 255, 2: 1, 3: 1, 4: startTimestamp},
    );

    const List<_FitField> eventFields = <_FitField>[
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.enumeration),
      _FitField(1, 1, _FitBaseType.enumeration),
      _FitField(4, 1, _FitBaseType.uint8),
    ];
    _definition(localMessage: 1, globalMessage: 21, fields: eventFields);
    _message(1, eventFields, <int, Object>{
      253: startTimestamp,
      0: 0,
      1: 0,
      4: 0,
    });

    const List<_FitField> recordFields = <_FitField>[
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(3, 1, _FitBaseType.uint8),
      _FitField(5, 4, _FitBaseType.uint32),
      _FitField(6, 2, _FitBaseType.uint16),
      _FitField(9, 2, _FitBaseType.sint16),
      _FitField(33, 2, _FitBaseType.uint16),
    ];
    _definition(localMessage: 2, globalMessage: 20, fields: recordFields);
    for (final WorkoutMetricSample record in records) {
      final double progress = summary.duration.inMilliseconds <= 0
          ? 1
          : (record.elapsed.inMilliseconds / summary.duration.inMilliseconds)
                .clamp(0, 1)
                .toDouble();
      _message(2, recordFields, <int, Object>{
        253: _fitTimestamp(record.recordedAt),
        3: _heartRate(record.heartRateBpm),
        5: _unsigned32((record.distanceMeters * 100).round()),
        6: _speed(record.speedKph),
        9: _signed16((record.inclinePercent * 100).round()),
        33: _unsigned16((summary.activeEnergyCalories * progress).round()),
      });
    }

    _message(1, eventFields, <int, Object>{
      253: endTimestamp,
      0: 0,
      1: 4,
      4: 0,
    });

    const List<_FitField> lapFields = <_FitField>[
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.enumeration),
      _FitField(1, 1, _FitBaseType.enumeration),
      _FitField(2, 4, _FitBaseType.uint32),
      _FitField(7, 4, _FitBaseType.uint32),
      _FitField(8, 4, _FitBaseType.uint32),
      _FitField(9, 4, _FitBaseType.uint32),
      _FitField(11, 2, _FitBaseType.uint16),
      _FitField(13, 2, _FitBaseType.uint16),
      _FitField(14, 2, _FitBaseType.uint16),
      _FitField(15, 1, _FitBaseType.uint8),
      _FitField(16, 1, _FitBaseType.uint8),
      _FitField(25, 1, _FitBaseType.enumeration),
    ];
    _definition(localMessage: 3, globalMessage: 19, fields: lapFields);
    _message(3, lapFields, <int, Object>{
      253: endTimestamp,
      0: 9,
      1: 1,
      2: startTimestamp,
      7: _unsigned32(elapsedMilliseconds),
      8: _unsigned32(elapsedMilliseconds),
      9: distanceCentimeters,
      11: calories,
      13: avgSpeed,
      14: maxSpeed,
      15: _heartRate(summary.averageHeartRateBpm),
      16: _heartRate(summary.maxHeartRateBpm),
      25: _sport,
    });

    const List<_FitField> sessionFields = <_FitField>[
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 1, _FitBaseType.enumeration),
      _FitField(1, 1, _FitBaseType.enumeration),
      _FitField(2, 4, _FitBaseType.uint32),
      _FitField(5, 1, _FitBaseType.enumeration),
      _FitField(6, 1, _FitBaseType.enumeration),
      _FitField(7, 4, _FitBaseType.uint32),
      _FitField(8, 4, _FitBaseType.uint32),
      _FitField(9, 4, _FitBaseType.uint32),
      _FitField(11, 2, _FitBaseType.uint16),
      _FitField(14, 2, _FitBaseType.uint16),
      _FitField(15, 2, _FitBaseType.uint16),
      _FitField(16, 1, _FitBaseType.uint8),
      _FitField(17, 1, _FitBaseType.uint8),
      _FitField(25, 2, _FitBaseType.uint16),
      _FitField(26, 2, _FitBaseType.uint16),
      _FitField(65, 20, _FitBaseType.uint32),
    ];
    _definition(localMessage: 4, globalMessage: 18, fields: sessionFields);
    _message(4, sessionFields, <int, Object>{
      253: endTimestamp,
      0: 8,
      1: 1,
      2: startTimestamp,
      5: _sport,
      6: 0,
      7: _unsigned32(elapsedMilliseconds),
      8: _unsigned32(elapsedMilliseconds),
      9: distanceCentimeters,
      11: calories,
      14: avgSpeed,
      15: maxSpeed,
      16: _heartRate(summary.averageHeartRateBpm),
      17: _heartRate(summary.maxHeartRateBpm),
      25: 0,
      26: 1,
      65: _zoneTimes,
    });

    const List<_FitField> activityFields = <_FitField>[
      _FitField(253, 4, _FitBaseType.uint32),
      _FitField(0, 4, _FitBaseType.uint32),
      _FitField(1, 2, _FitBaseType.uint16),
      _FitField(2, 1, _FitBaseType.enumeration),
      _FitField(3, 1, _FitBaseType.enumeration),
      _FitField(4, 1, _FitBaseType.enumeration),
      _FitField(5, 4, _FitBaseType.uint32),
    ];
    _definition(localMessage: 5, globalMessage: 34, fields: activityFields);
    _message(5, activityFields, <int, Object>{
      253: endTimestamp,
      0: _unsigned32(elapsedMilliseconds),
      1: 1,
      2: 0,
      3: 26,
      4: 1,
      5: _fitTimestamp(endedAt.toLocal()),
    });

    final Uint8List dataBytes = _data.takeBytes();
    final BytesBuilder file = BytesBuilder(copy: false);
    final BytesBuilder headerWithoutCrc = BytesBuilder(copy: false)
      ..addByte(14)
      ..addByte(_protocolVersion)
      ..add(_uint16Bytes(_profileVersion))
      ..add(_uint32Bytes(dataBytes.length))
      ..add(const <int>[0x2e, 0x46, 0x49, 0x54]);
    final Uint8List firstTwelveHeaderBytes = headerWithoutCrc.takeBytes();
    final int headerCrc = _FitCrc.calculate(firstTwelveHeaderBytes);
    final Uint8List header = Uint8List.fromList(<int>[
      ...firstTwelveHeaderBytes,
      ..._uint16Bytes(headerCrc),
    ]);
    file
      ..add(header)
      ..add(dataBytes);
    final Uint8List withoutFileCrc = file.takeBytes();
    final int fileCrc = _FitCrc.calculate(withoutFileCrc);
    return Uint8List.fromList(<int>[
      ...withoutFileCrc,
      ..._uint16Bytes(fileCrc),
    ]);
  }

  List<WorkoutMetricSample> _records(DateTime startedAt) {
    if (summary.metricSamples.isNotEmpty) {
      return summary.metricSamples
          .map(
            (WorkoutMetricSample sample) => WorkoutMetricSample(
              recordedAt: startedAt.add(sample.elapsed),
              elapsed: sample.elapsed,
              speedKph: sample.speedKph,
              inclinePercent: sample.inclinePercent,
              distanceMeters: sample.distanceMeters,
              heartRateBpm: sample.heartRateBpm,
              heartRateSource: sample.heartRateSource,
              activeEnergyCalories: sample.activeEnergyCalories,
            ),
          )
          .toList(growable: false);
    }
    return <WorkoutMetricSample>[
      WorkoutMetricSample(
        recordedAt: startedAt,
        elapsed: Duration.zero,
        speedKph: summary.averageSpeedKph,
        inclinePercent: 0,
        distanceMeters: 0,
        heartRateBpm: summary.averageHeartRateBpm,
        heartRateSource: HeartRateSource.none,
      ),
      WorkoutMetricSample(
        recordedAt: endedAt,
        elapsed: summary.duration,
        speedKph: summary.averageSpeedKph,
        inclinePercent: 0,
        distanceMeters: summary.distanceMeters,
        heartRateBpm: summary.maxHeartRateBpm,
        heartRateSource: HeartRateSource.none,
      ),
    ];
  }

  List<int> get _zoneTimes {
    const List<HeartRateZone> orderedZones = <HeartRateZone>[
      HeartRateZone.recovery,
      HeartRateZone.aerobic,
      HeartRateZone.tempo,
      HeartRateZone.threshold,
      HeartRateZone.peak,
    ];
    return orderedZones
        .map(
          (HeartRateZone zone) => _unsigned32(
            (summary.heartRateZoneDurations[zone] ?? Duration.zero)
                .inMilliseconds,
          ),
        )
        .toList(growable: false);
  }

  int get _sport {
    return switch (machineKind) {
      MachineKind.treadmill => 1,
      MachineKind.indoorBike => 2,
      MachineKind.crossTrainer => 4,
      MachineKind.rower => 15,
      MachineKind.unknown || MachineKind.simulator => 0,
    };
  }

  void _definition({
    required int localMessage,
    required int globalMessage,
    required List<_FitField> fields,
  }) {
    _data
      ..addByte(0x40 | localMessage)
      ..addByte(0)
      ..addByte(0)
      ..add(_uint16Bytes(globalMessage))
      ..addByte(fields.length);
    for (final _FitField field in fields) {
      _data
        ..addByte(field.number)
        ..addByte(field.size)
        ..addByte(field.baseType.value);
    }
  }

  void _message(
    int localMessage,
    List<_FitField> fields,
    Map<int, Object> values,
  ) {
    _data.addByte(localMessage);
    for (final _FitField field in fields) {
      final Object value = values[field.number]!;
      if (value is List<int>) {
        for (final int item in value) {
          _writeValue(item, field.baseType);
        }
      } else {
        _writeValue(value as int, field.baseType);
      }
    }
  }

  void _writeValue(int value, _FitBaseType type) {
    switch (type) {
      case _FitBaseType.enumeration:
      case _FitBaseType.uint8:
        _data.addByte(value);
      case _FitBaseType.sint16:
      case _FitBaseType.uint16:
        _data.add(_uint16Bytes(value));
      case _FitBaseType.uint32:
      case _FitBaseType.uint32z:
        _data.add(_uint32Bytes(value));
    }
  }

  int _fitTimestamp(DateTime dateTime) =>
      dateTime.toUtc().difference(_fitEpoch).inSeconds.clamp(0, 0xffffffff);

  int _speed(double kph) => _unsigned16((kph / 3.6 * 1000).round());
  int _heartRate(int bpm) => bpm > 0 && bpm < 255 ? bpm : 0xff;
  int _unsigned16(int value) => value.clamp(0, 0xfffe);
  int _signed16(int value) => value.clamp(-0x7fff, 0x7fff);
  int _unsigned32(int value) => value.clamp(0, 0xfffffffe);

  List<int> _uint16Bytes(int value) {
    final ByteData bytes = ByteData(2)
      ..setUint16(0, value & 0xffff, Endian.little);
    return bytes.buffer.asUint8List();
  }

  List<int> _uint32Bytes(int value) {
    final ByteData bytes = ByteData(4)
      ..setUint32(0, value & 0xffffffff, Endian.little);
    return bytes.buffer.asUint8List();
  }
}

class _FitField {
  const _FitField(this.number, this.size, this.baseType);

  final int number;
  final int size;
  final _FitBaseType baseType;
}

enum _FitBaseType {
  enumeration(0x00),
  uint8(0x02),
  sint16(0x83),
  uint16(0x84),
  uint32(0x86),
  uint32z(0x8c);

  const _FitBaseType(this.value);
  final int value;
}

class _FitCrc {
  static const List<int> _table = <int>[
    0x0000,
    0xcc01,
    0xd801,
    0x1400,
    0xf001,
    0x3c00,
    0x2800,
    0xe401,
    0xa001,
    0x6c00,
    0x7800,
    0xb401,
    0x5000,
    0x9c01,
    0x8801,
    0x4400,
  ];

  static int calculate(List<int> bytes) {
    int crc = 0;
    for (final int byte in bytes) {
      int temporary = _table[crc & 0x0f];
      crc = (crc >> 4) & 0x0fff;
      crc = crc ^ temporary ^ _table[byte & 0x0f];
      temporary = _table[crc & 0x0f];
      crc = (crc >> 4) & 0x0fff;
      crc = crc ^ temporary ^ _table[(byte >> 4) & 0x0f];
    }
    return crc & 0xffff;
  }
}
