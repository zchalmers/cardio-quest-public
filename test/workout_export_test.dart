import 'dart:convert';
import 'dart:typed_data';

import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/services/workout_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a FIT activity with a valid header and file CRC', () {
    final DateTime endedAt = DateTime.utc(2026, 1, 1, 12, 30);
    final GameSummary summary = GameSummary(
      duration: const Duration(minutes: 30),
      distanceMeters: 5000,
      averageSpeedKph: 10,
      maxSpeedKph: 13,
      coins: 20,
      score: 9000,
      maxCombo: 3,
      obstaclesCleared: 12,
      averageHeartRateBpm: 148,
      maxHeartRateBpm: 178,
      activeEnergyCalories: 360,
      heartRateZoneDurations: const <HeartRateZone, Duration>{
        HeartRateZone.recovery: Duration(minutes: 2),
        HeartRateZone.aerobic: Duration(minutes: 6),
        HeartRateZone.tempo: Duration(minutes: 10),
        HeartRateZone.threshold: Duration(minutes: 9),
        HeartRateZone.peak: Duration(minutes: 3),
      },
    );

    final Uint8List bytes = WorkoutExport().createFitFile(
      summary,
      endedAt: endedAt,
    );
    final ByteData header = ByteData.sublistView(bytes);

    expect(bytes[0], 14);
    expect(String.fromCharCodes(bytes.sublist(8, 12)), '.FIT');
    expect(header.getUint32(4, Endian.little), bytes.length - 16);
    expect(_crc(bytes), 0);
  });

  test('creates a TCX activity with metrics and timestamped trackpoints', () {
    final DateTime endedAt = DateTime.utc(2026, 1, 1, 12, 30);
    final GameSummary summary = GameSummary(
      duration: const Duration(minutes: 10),
      distanceMeters: 2500,
      averageSpeedKph: 15,
      maxSpeedKph: 20,
      coins: 10,
      score: 1000,
      maxCombo: 2,
      obstaclesCleared: 4,
      averageHeartRateBpm: 140,
      maxHeartRateBpm: 165,
      activeEnergyCalories: 180,
    );

    final String tcx = utf8.decode(
      WorkoutExport().createTcxFile(
        summary,
        machineKind: MachineKind.indoorBike,
        endedAt: endedAt,
      ),
    );

    expect(tcx, contains('<Activity Sport="Biking">'));
    expect(tcx, contains('<DistanceMeters>2500.00</DistanceMeters>'));
    expect(tcx, contains('<MaximumSpeed>5.5556</MaximumSpeed>'));
    expect(tcx, contains('<HeartRateBpm><Value>140</Value>'));
    expect(tcx, contains('<Calories>180</Calories>'));
    expect(tcx, contains('2026-01-01T12:20:00.000Z'));
    expect(tcx, contains('2026-01-01T12:30:00.000Z'));
  });
}

int _crc(List<int> bytes) {
  const List<int> table = <int>[
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
  int crc = 0;
  for (final int byte in bytes) {
    int temporary = table[crc & 0x0f];
    crc = (crc >> 4) & 0x0fff;
    crc = crc ^ temporary ^ table[byte & 0x0f];
    temporary = table[crc & 0x0f];
    crc = (crc >> 4) & 0x0fff;
    crc = crc ^ temporary ^ table[(byte >> 4) & 0x0f];
  }
  return crc & 0xffff;
}
