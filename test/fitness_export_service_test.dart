import 'dart:io';
import 'dart:typed_data';

import 'package:cardio_quest/models/machine_models.dart';
import 'package:cardio_quest/services/fitness_export_models.dart';
import 'package:cardio_quest/services/fitness_export_service.dart';
import 'package:cardio_quest/services/garmin_service.dart';
import 'package:cardio_quest/services/strava_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uploads a workout and records successful export history', () async {
    final Directory storage = await Directory.systemTemp.createTemp(
      'cardio-quest-export-success-',
    );
    addTearDown(() => storage.delete(recursive: true));
    final _FakeStravaService strava = _FakeStravaService(succeeds: true);
    final FitnessExportService service = FitnessExportService(
      stravaService: strava,
      garminService: _FakeGarminService(),
      preferences: _MemoryPreferences(),
      storageDirectory: storage,
    );
    addTearDown(service.dispose);
    await service.initialize();

    await service.shareWorkout(
      platform: FitnessPlatform.strava,
      workoutId: 'workout-success',
      summary: _summary(),
      machineKind: MachineKind.treadmill,
      endedAt: DateTime.utc(2026, 7, 23, 12),
    );

    final FitnessExportEntry entry = service.history.single;
    expect(entry.status, FitnessUploadStatus.succeeded);
    expect(entry.remoteId, 'strava-activity-1');
    expect(entry.payloadPath, isEmpty);
    expect(strava.uploadCount, 1);
  });

  test('persists an offline upload and retries it after restart', () async {
    final Directory storage = await Directory.systemTemp.createTemp(
      'cardio-quest-export-retry-',
    );
    addTearDown(() => storage.delete(recursive: true));
    final _MemoryPreferences preferences = _MemoryPreferences();
    final FitnessExportService offlineService = FitnessExportService(
      stravaService: _FakeStravaService(succeeds: false),
      garminService: _FakeGarminService(),
      preferences: preferences,
      storageDirectory: storage,
    );
    await offlineService.initialize();
    await offlineService.shareWorkout(
      platform: FitnessPlatform.strava,
      workoutId: 'workout-offline',
      summary: _summary(),
      machineKind: MachineKind.indoorBike,
      endedAt: DateTime.utc(2026, 7, 23, 13),
    );
    final FitnessExportEntry failed = offlineService.history.single;
    expect(failed.status, FitnessUploadStatus.failed);
    expect(await File(failed.payloadPath).exists(), isTrue);
    offlineService.dispose();

    final _FakeStravaService onlineStrava = _FakeStravaService(succeeds: true);
    final FitnessExportService restoredService = FitnessExportService(
      stravaService: onlineStrava,
      garminService: _FakeGarminService(),
      preferences: preferences,
      storageDirectory: storage,
    );
    addTearDown(restoredService.dispose);
    await restoredService.initialize();
    await restoredService.retryFailedUploads();

    final FitnessExportEntry retried = restoredService.history.single;
    expect(retried.status, FitnessUploadStatus.succeeded);
    expect(retried.remoteId, 'strava-activity-1');
    expect(onlineStrava.uploadCount, 1);
  });
}

GameSummary _summary() {
  return const GameSummary(
    duration: Duration(minutes: 20),
    distanceMeters: 4000,
    averageSpeedKph: 12,
    maxSpeedKph: 17,
    coins: 20,
    score: 2400,
    maxCombo: 3,
    obstaclesCleared: 8,
    averageHeartRateBpm: 145,
    maxHeartRateBpm: 172,
    activeEnergyCalories: 260,
  );
}

class _FakeStravaService extends StravaService {
  _FakeStravaService({required this.succeeds})
    : super(
        client: MockClient(
          (http.Request request) async => http.Response('{}', 200),
        ),
      );

  final bool succeeds;
  int uploadCount = 0;

  @override
  bool get isConfigured => true;

  @override
  bool get isConnected => true;

  @override
  FitnessAccountProfile get profile =>
      const FitnessAccountProfile(id: '1', displayName: 'Test Athlete');

  @override
  Future<void> initialize() async {}

  @override
  Future<FitnessUploadResult> uploadFit({
    required Uint8List bytes,
    required String fileName,
    required String externalId,
    required String sportType,
    String name = 'Cardio Quest',
  }) async {
    uploadCount += 1;
    if (!succeeds) {
      return const FitnessUploadResult.failure(
        message: 'Offline. Queued for retry.',
      );
    }
    return const FitnessUploadResult.success(remoteId: 'strava-activity-1');
  }
}

class _FakeGarminService extends GarminService {
  _FakeGarminService()
    : super(
        client: MockClient(
          (http.Request request) async => http.Response('{}', 200),
        ),
      );

  @override
  bool get isConfigured => false;

  @override
  bool get isConnected => false;

  @override
  Future<void> initialize() async {}
}

class _MemoryPreferences implements FitnessExportPreferences {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
