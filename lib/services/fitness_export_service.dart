import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/machine_models.dart';
import 'fitness_export_models.dart';
import 'garmin_service.dart';
import 'strava_service.dart';
import 'workout_export.dart';

class FitnessExportService extends ChangeNotifier with WidgetsBindingObserver {
  FitnessExportService({
    StravaService? stravaService,
    GarminService? garminService,
    WorkoutExport? workoutExport,
    FitnessExportPreferences? preferences,
    Directory? storageDirectory,
    DateTime Function()? clock,
  }) : _strava = stravaService ?? StravaService(),
       _garmin = garminService ?? GarminService(),
       _workoutExport = workoutExport ?? WorkoutExport(),
       _preferences = preferences,
       _providedStorageDirectory = storageDirectory,
       _clock = clock ?? DateTime.now;

  static const String _heartRatePreference = 'fitness.export.share_heart_rate';
  static const String _locationPreference = 'fitness.export.share_location';
  static const String _lastSyncPreference = 'fitness.export.last_sync';
  static const int _maximumHistoryEntries = 200;

  final StravaService _strava;
  final GarminService _garmin;
  final WorkoutExport _workoutExport;
  FitnessExportPreferences? _preferences;
  final Directory? _providedStorageDirectory;
  final DateTime Function() _clock;

  final Map<FitnessPlatform, FitnessConnectionStatus> _connectionStatuses =
      <FitnessPlatform, FitnessConnectionStatus>{};
  final Map<FitnessPlatform, String?> _connectionErrors =
      <FitnessPlatform, String?>{};
  final List<FitnessExportEntry> _entries = <FitnessExportEntry>[];

  Directory? _storageDirectory;
  Timer? _retryTimer;
  Timer? _nextRetryTimer;
  Future<void>? _initializing;
  Future<void>? _syncFuture;
  bool _initialized = false;
  bool _syncing = false;
  bool _syncRequested = false;
  bool _disposed = false;
  bool _shareHeartRate = true;
  bool _shareLocation = false;
  DateTime? _lastSyncAt;

  bool get isInitialized => _initialized;
  bool get isSyncing => _syncing;
  bool get shareHeartRate => _shareHeartRate;
  bool get shareLocation => _shareLocation;
  DateTime? get lastSyncAt => _lastSyncAt;
  List<FitnessExportEntry> get history => List<FitnessExportEntry>.unmodifiable(
    _entries.toList()..sort(
      (FitnessExportEntry a, FitnessExportEntry b) =>
          b.updatedAt.compareTo(a.updatedAt),
    ),
  );
  int get pendingCount =>
      _entries.where((FitnessExportEntry entry) => entry.isPending).length;

  Future<void> initialize() {
    final Future<void>? existing = _initializing;
    if (existing != null) {
      return existing;
    }
    final Future<void> initialization = _initialize();
    _initializing = initialization;
    return initialization;
  }

  FitnessConnectionStatus connectionStatus(FitnessPlatform platform) {
    return _connectionStatuses[platform] ??
        (isConfigured(platform)
            ? FitnessConnectionStatus.disconnected
            : FitnessConnectionStatus.unavailable);
  }

  String? connectionError(FitnessPlatform platform) =>
      _connectionErrors[platform];

  bool isConfigured(FitnessPlatform platform) => switch (platform) {
    FitnessPlatform.strava => _strava.isConfigured,
    FitnessPlatform.garmin => _garmin.isConfigured,
  };

  bool isConnected(FitnessPlatform platform) => switch (platform) {
    FitnessPlatform.strava => _strava.isConnected,
    FitnessPlatform.garmin => _garmin.isConnected,
  };

  FitnessAccountProfile? account(FitnessPlatform platform) =>
      switch (platform) {
        FitnessPlatform.strava => _strava.profile,
        FitnessPlatform.garmin => _garmin.profile,
      };

  FitnessExportEntry? latestEntry(String workoutId, FitnessPlatform platform) {
    final Iterable<FitnessExportEntry> matches = _entries.where(
      (FitnessExportEntry entry) =>
          entry.workoutId == workoutId && entry.platform == platform,
    );
    if (matches.isEmpty) {
      return null;
    }
    return matches.reduce(
      (FitnessExportEntry a, FitnessExportEntry b) =>
          a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );
  }

  bool isUploading(String workoutId, FitnessPlatform platform) {
    final FitnessUploadStatus? status = latestEntry(
      workoutId,
      platform,
    )?.status;
    return status == FitnessUploadStatus.queued ||
        status == FitnessUploadStatus.uploading ||
        status == FitnessUploadStatus.processing;
  }

  Future<void> connect(FitnessPlatform platform) async {
    await initialize();
    _connectionStatuses[platform] = FitnessConnectionStatus.connecting;
    _connectionErrors[platform] = null;
    _notify();
    try {
      switch (platform) {
        case FitnessPlatform.strava:
          await _strava.connect();
        case FitnessPlatform.garmin:
          await _garmin.connect();
      }
      _connectionStatuses[platform] = FitnessConnectionStatus.connected;
      _connectionErrors[platform] = null;
      _notify();
      unawaited(
        syncPending(force: true, platforms: <FitnessPlatform>{platform}),
      );
    } on Object catch (error) {
      _connectionStatuses[platform] = isConnected(platform)
          ? FitnessConnectionStatus.connected
          : FitnessConnectionStatus.error;
      _connectionErrors[platform] = _friendlyError(error);
      _notify();
      rethrow;
    }
  }

  Future<void> disconnect(FitnessPlatform platform) async {
    await initialize();
    _connectionErrors[platform] = null;
    try {
      switch (platform) {
        case FitnessPlatform.strava:
          await _strava.disconnect();
        case FitnessPlatform.garmin:
          await _garmin.disconnect();
      }
      _connectionStatuses[platform] = isConfigured(platform)
          ? FitnessConnectionStatus.disconnected
          : FitnessConnectionStatus.unavailable;
      _notify();
    } on Object catch (error) {
      _connectionStatuses[platform] = FitnessConnectionStatus.error;
      _connectionErrors[platform] = _friendlyError(error);
      _notify();
      rethrow;
    }
  }

  Future<void> setShareHeartRate(bool value) async {
    _shareHeartRate = value;
    _notify();
    await _prefs.setBool(_heartRatePreference, value);
  }

  Future<void> setShareLocation(bool value) async {
    _shareLocation = value;
    _notify();
    await _prefs.setBool(_locationPreference, value);
  }

  Future<void> autoUploadWorkout({
    required String workoutId,
    required GameSummary summary,
    required MachineKind machineKind,
    required DateTime endedAt,
  }) async {
    await initialize();
    final Set<FitnessPlatform> connected = FitnessPlatform.values
        .where(isConnected)
        .toSet();
    if (connected.isEmpty) {
      return;
    }
    await _enqueueWorkout(
      workoutId: workoutId,
      summary: summary,
      machineKind: machineKind,
      endedAt: endedAt,
      platforms: connected,
    );
    unawaited(syncPending(platforms: connected));
  }

  Future<void> shareWorkout({
    required FitnessPlatform platform,
    required String workoutId,
    required GameSummary summary,
    required MachineKind machineKind,
    required DateTime endedAt,
  }) async {
    await initialize();
    if (!isConnected(platform)) {
      throw FitnessServiceException(
        'Connect ${_platformLabel(platform)} in Settings before sharing.',
        authenticationRequired: true,
      );
    }
    final FitnessExportEntry? existing = latestEntry(workoutId, platform);
    if (existing == null) {
      await _enqueueWorkout(
        workoutId: workoutId,
        summary: summary,
        machineKind: machineKind,
        endedAt: endedAt,
        platforms: <FitnessPlatform>{platform},
      );
    }
    await syncPending(
      force: true,
      platforms: <FitnessPlatform>{platform},
      workoutId: workoutId,
    );
  }

  Future<void> retryFailedUploads() => syncPending(force: true);

  Future<void> syncPending({
    bool force = false,
    Set<FitnessPlatform>? platforms,
    String? workoutId,
  }) async {
    await initialize();
    final Future<void>? activeSync = _syncFuture;
    if (activeSync != null) {
      _syncRequested = true;
      await activeSync;
      if (force || platforms != null || workoutId != null) {
        await syncPending(
          force: force,
          platforms: platforms,
          workoutId: workoutId,
        );
      }
      return;
    }
    final Future<void> run = _runSync(
      force: force,
      platforms: platforms,
      workoutId: workoutId,
    );
    _syncFuture = run;
    try {
      await run;
    } finally {
      if (identical(_syncFuture, run)) {
        _syncFuture = null;
      }
    }
  }

  Future<void> _runSync({
    required bool force,
    required Set<FitnessPlatform>? platforms,
    required String? workoutId,
  }) async {
    _syncing = true;
    _notify();
    try {
      do {
        _syncRequested = false;
        final DateTime now = _clock();
        final List<FitnessExportEntry> candidates = _entries
            .where(
              (FitnessExportEntry entry) =>
                  entry.isPending &&
                  (platforms == null || platforms.contains(entry.platform)) &&
                  (workoutId == null || entry.workoutId == workoutId) &&
                  (force ||
                      entry.nextAttemptAt == null ||
                      !entry.nextAttemptAt!.isAfter(now)),
            )
            .toList(growable: false);
        for (final FitnessExportEntry entry in candidates) {
          if (!isConnected(entry.platform)) {
            continue;
          }
          await _syncEntry(entry);
        }
      } while (_syncRequested);
      _lastSyncAt = _clock();
      await _prefs.setString(
        _lastSyncPreference,
        _lastSyncAt!.toUtc().toIso8601String(),
      );
    } finally {
      _syncing = false;
      _scheduleNextRetry();
      _notify();
    }
  }

  Future<void> _initialize() async {
    _storageDirectory =
        _providedStorageDirectory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}'
          '${Platform.pathSeparator}fitness_exports',
        );
    await _storageDirectory!.create(recursive: true);
    _shareHeartRate = await _prefs.getBool(_heartRatePreference) ?? true;
    _shareLocation = await _prefs.getBool(_locationPreference) ?? false;
    _lastSyncAt = DateTime.tryParse(
      await _prefs.getString(_lastSyncPreference) ?? '',
    );
    await _loadEntries();
    await Future.wait<void>(<Future<void>>[
      _strava.initialize(),
      _garmin.initialize(),
    ]);
    for (final FitnessPlatform platform in FitnessPlatform.values) {
      _connectionStatuses[platform] = isConnected(platform)
          ? FitnessConnectionStatus.connected
          : isConfigured(platform)
          ? FitnessConnectionStatus.disconnected
          : FitnessConnectionStatus.unavailable;
    }
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (Timer _) {
      unawaited(syncPending());
    });
    _notify();
    unawaited(syncPending());
  }

  Future<void> _enqueueWorkout({
    required String workoutId,
    required GameSummary summary,
    required MachineKind machineKind,
    required DateTime endedAt,
    required Set<FitnessPlatform> platforms,
  }) async {
    final GameSummary exportSummary = _privacyFilteredSummary(summary);
    for (final FitnessPlatform platform in platforms) {
      if (latestEntry(workoutId, platform) != null) {
        continue;
      }
      final bool tcx = platform == FitnessPlatform.garmin && _garmin.usesTcx;
      final String dataType = tcx ? 'tcx' : 'fit';
      final Uint8List payload = tcx
          ? _workoutExport.createTcxFile(
              exportSummary,
              machineKind: machineKind,
              endedAt: endedAt,
            )
          : _workoutExport.createFitFile(
              exportSummary,
              machineKind: machineKind,
              endedAt: endedAt,
            );
      final String entryId = _safeName('$workoutId-${platform.name}');
      final String fileName = 'cardio-quest-$entryId.$dataType';
      final File payloadFile = File(
        '${_storageDirectory!.path}${Platform.pathSeparator}$fileName',
      );
      await payloadFile.writeAsBytes(payload, flush: true);
      final DateTime now = _clock();
      _entries.add(
        FitnessExportEntry(
          id: entryId,
          workoutId: workoutId,
          platform: platform,
          status: FitnessUploadStatus.queued,
          createdAt: now,
          updatedAt: now,
          endedAt: endedAt,
          machineKindName: machineKind.name,
          fileName: fileName,
          dataType: dataType,
          sportType: _sportType(machineKind, platform),
          payloadPath: payloadFile.path,
        ),
      );
    }
    await _saveEntries();
    _scheduleNextRetry();
    _notify();
  }

  Future<void> _syncEntry(FitnessExportEntry original) async {
    FitnessExportEntry entry = _currentEntry(original.id) ?? original;
    entry = entry.copyWith(
      status: entry.status == FitnessUploadStatus.processing
          ? FitnessUploadStatus.processing
          : FitnessUploadStatus.uploading,
      updatedAt: _clock(),
      clearError: true,
      clearNextAttempt: true,
    );
    await _replaceAndSave(entry);
    FitnessUploadResult result;
    if (entry.status == FitnessUploadStatus.processing &&
        entry.remoteId != null) {
      result = await switch (entry.platform) {
        FitnessPlatform.strava => _strava.checkUpload(entry.remoteId!),
        FitnessPlatform.garmin => _garmin.checkUpload(entry.remoteId!),
      };
    } else {
      final File payloadFile = File(entry.payloadPath);
      if (!await payloadFile.exists()) {
        result = const FitnessUploadResult.failure(
          message: 'The queued workout file is missing.',
        );
      } else {
        final Uint8List bytes = await payloadFile.readAsBytes();
        result = await switch (entry.platform) {
          FitnessPlatform.strava => _strava.uploadFit(
            bytes: bytes,
            fileName: entry.fileName,
            externalId: entry.workoutId,
            sportType: entry.sportType,
          ),
          FitnessPlatform.garmin => _garmin.uploadActivity(
            bytes: bytes,
            fileName: entry.fileName,
            externalId: entry.workoutId,
            sportType: entry.sportType,
            dataType: entry.dataType,
          ),
        };
      }
    }

    final DateTime now = _clock();
    if (result.succeeded) {
      entry = entry.copyWith(
        status: FitnessUploadStatus.succeeded,
        updatedAt: now,
        attempts: entry.attempts + 1,
        remoteId: result.remoteId,
        clearError: true,
        clearNextAttempt: true,
      );
      final File payloadFile = File(entry.payloadPath);
      if (await payloadFile.exists()) {
        await payloadFile.delete();
      }
      entry = entry.copyWith(payloadPath: '');
    } else if (result.processing && result.remoteId != null) {
      entry = entry.copyWith(
        status: FitnessUploadStatus.processing,
        updatedAt: now,
        attempts: entry.attempts + 1,
        remoteId: result.remoteId,
        nextAttemptAt: result.retryAt ?? now.add(const Duration(seconds: 15)),
        clearError: true,
      );
    } else {
      final int attempts = entry.attempts + 1;
      entry = entry.copyWith(
        status: FitnessUploadStatus.failed,
        updatedAt: now,
        attempts: attempts,
        nextAttemptAt: result.retryAt ?? now.add(_backoffDuration(attempts)),
        errorMessage: result.message ?? 'Upload failed.',
      );
      if (result.authenticationRequired) {
        _connectionStatuses[entry.platform] = FitnessConnectionStatus.error;
        _connectionErrors[entry.platform] = result.message;
      }
    }
    await _replaceAndSave(entry);
  }

  GameSummary _privacyFilteredSummary(GameSummary summary) {
    if (_shareHeartRate) {
      return summary;
    }
    return GameSummary(
      duration: summary.duration,
      distanceMeters: summary.distanceMeters,
      averageSpeedKph: summary.averageSpeedKph,
      maxSpeedKph: summary.maxSpeedKph,
      coins: summary.coins,
      score: summary.score,
      maxCombo: summary.maxCombo,
      obstaclesCleared: summary.obstaclesCleared,
      restingHeartRateBpm: null,
      activeEnergyCalories: summary.activeEnergyCalories,
      workoutStepCount: summary.workoutStepCount,
      usedWearableData: false,
      metricSamples: summary.metricSamples
          .map(
            (WorkoutMetricSample sample) => WorkoutMetricSample(
              recordedAt: sample.recordedAt,
              elapsed: sample.elapsed,
              speedKph: sample.speedKph,
              inclinePercent: sample.inclinePercent,
              distanceMeters: sample.distanceMeters,
              heartRateBpm: 0,
              heartRateSource: HeartRateSource.none,
              activeEnergyCalories: sample.activeEnergyCalories,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _loadEntries() async {
    final File index = _indexFile;
    if (!await index.exists()) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(await index.readAsString());
      if (decoded is! List<Object?>) {
        return;
      }
      for (final Object? item in decoded) {
        if (item is Map<String, Object?>) {
          FitnessExportEntry entry = FitnessExportEntry.fromJson(item);
          if (entry.status == FitnessUploadStatus.uploading) {
            entry = entry.copyWith(status: FitnessUploadStatus.queued);
          }
          _entries.add(entry);
        }
      }
    } on Object {
      // A corrupt history file must not prevent the app from starting.
      _entries.clear();
    }
  }

  Future<void> _saveEntries() async {
    _pruneHistory();
    await _indexFile.writeAsString(
      jsonEncode(
        _entries
            .map((FitnessExportEntry entry) => entry.toJson())
            .toList(growable: false),
      ),
      flush: true,
    );
  }

  void _pruneHistory() {
    if (_entries.length <= _maximumHistoryEntries) {
      return;
    }
    final List<FitnessExportEntry> succeeded =
        _entries
            .where(
              (FitnessExportEntry entry) =>
                  entry.status == FitnessUploadStatus.succeeded,
            )
            .toList()
          ..sort(
            (FitnessExportEntry a, FitnessExportEntry b) =>
                a.updatedAt.compareTo(b.updatedAt),
          );
    final int removeCount = math.min(
      _entries.length - _maximumHistoryEntries,
      succeeded.length,
    );
    final Set<String> removeIds = succeeded
        .take(removeCount)
        .map((FitnessExportEntry entry) => entry.id)
        .toSet();
    _entries.removeWhere(
      (FitnessExportEntry entry) => removeIds.contains(entry.id),
    );
  }

  Future<void> _replaceAndSave(FitnessExportEntry entry) async {
    final int index = _entries.indexWhere(
      (FitnessExportEntry candidate) => candidate.id == entry.id,
    );
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
    await _saveEntries();
    _scheduleNextRetry();
    _notify();
  }

  FitnessExportEntry? _currentEntry(String id) {
    for (final FitnessExportEntry entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  File get _indexFile =>
      File('${_storageDirectory!.path}${Platform.pathSeparator}history.json');

  FitnessExportPreferences get _prefs =>
      _preferences ??= SharedPreferencesFitnessExportPreferences();

  Duration _backoffDuration(int attempts) {
    final int exponent = math.min(attempts - 1, 10);
    final int seconds = math.min(30 * math.pow(2, exponent).toInt(), 21600);
    return Duration(seconds: seconds);
  }

  String _sportType(MachineKind machineKind, FitnessPlatform platform) {
    if (platform == FitnessPlatform.strava) {
      return switch (machineKind) {
        MachineKind.treadmill => 'Run',
        MachineKind.indoorBike => 'Ride',
        MachineKind.rower => 'Rowing',
        MachineKind.crossTrainer => 'Elliptical',
        MachineKind.unknown || MachineKind.simulator => 'Workout',
      };
    }
    return switch (machineKind) {
      MachineKind.treadmill => 'running',
      MachineKind.indoorBike => 'cycling',
      MachineKind.rower => 'rowing',
      MachineKind.crossTrainer => 'elliptical',
      MachineKind.unknown || MachineKind.simulator => 'fitness',
    };
  }

  String _safeName(String input) =>
      input.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '-');

  String _platformLabel(FitnessPlatform platform) => switch (platform) {
    FitnessPlatform.strava => 'Strava',
    FitnessPlatform.garmin => 'Garmin',
  };

  String _friendlyError(Object error) {
    if (error is FitnessServiceException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPending());
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _scheduleNextRetry() {
    _nextRetryTimer?.cancel();
    DateTime? earliest;
    for (final FitnessExportEntry entry in _entries) {
      final DateTime? nextAttemptAt = entry.nextAttemptAt;
      if (!entry.isPending ||
          nextAttemptAt == null ||
          !isConnected(entry.platform)) {
        continue;
      }
      if (earliest == null || nextAttemptAt.isBefore(earliest)) {
        earliest = nextAttemptAt;
      }
    }
    if (earliest == null || _disposed) {
      return;
    }
    final Duration delay = earliest.difference(_clock());
    _nextRetryTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(syncPending()),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _nextRetryTimer?.cancel();
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _strava.dispose();
    _garmin.dispose();
    super.dispose();
  }
}

abstract interface class FitnessExportPreferences {
  Future<bool?> getBool(String key);
  Future<String?> getString(String key);
  Future<void> setBool(String key, bool value);
  Future<void> setString(String key, String value);
}

class SharedPreferencesFitnessExportPreferences
    implements FitnessExportPreferences {
  SharedPreferencesFitnessExportPreferences({SharedPreferencesAsync? delegate})
    : _delegate = delegate ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _delegate;

  @override
  Future<bool?> getBool(String key) => _delegate.getBool(key);

  @override
  Future<String?> getString(String key) => _delegate.getString(key);

  @override
  Future<void> setBool(String key, bool value) => _delegate.setBool(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _delegate.setString(key, value);
}
