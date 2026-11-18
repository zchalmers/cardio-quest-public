import 'dart:async';

import '../models/machine_models.dart';

enum WearablePermissionStatus { notDetermined, authorized, denied, unavailable }

class WearableHeartRateSample {
  const WearableHeartRateSample({
    required this.bpm,
    required this.recordedAt,
    required this.receivedAt,
  });

  final int bpm;
  final DateTime recordedAt;
  final DateTime receivedAt;
}

/// No-op wearable data source.
///
/// HealthKit cannot function on free Apple ID sideloaded builds because the
/// `com.apple.developer.healthkit` entitlement is stripped by SideStore.
/// Any HealthKit API call without that entitlement causes an immediate
/// SIGKILL — no try/catch can intercept it.
///
/// This stub preserves the full API surface so that machine_service,
/// health_data_merger, and the rest of the app compile and run without
/// changes. All methods report "unavailable" safely.
class WearableService {
  WearableService({this.debugLogging = false});

  // Configuration knobs preserved so existing call-sites still compile.
  // ignore: unused_field
  final bool debugLogging;
  static const Duration pollInterval = Duration(seconds: 2);
  static const Duration heartRateLookback = Duration(minutes: 5);
  static const Duration summaryRefreshInterval = Duration(minutes: 1);

  final StreamController<WearableHeartRateSample> _heartRateController =
      StreamController<WearableHeartRateSample>.broadcast(sync: true);
  final StreamController<WearableMetrics> _metricsController =
      StreamController<WearableMetrics>.broadcast(sync: true);

  WearablePermissionStatus _permissionStatus =
      WearablePermissionStatus.unavailable;
  WearableMetrics? _currentMetrics;
  String? _lastError;
  bool _disposed = false;

  Stream<WearableHeartRateSample> get heartRateStream =>
      _heartRateController.stream;
  Stream<WearableMetrics> get metricsStream => _metricsController.stream;
  WearablePermissionStatus get permissionStatus => _permissionStatus;
  WearableMetrics? get currentMetrics => _currentMetrics;
  bool get isMonitoring => false;
  bool get activityRecognitionAuthorized => true; // no-op — always safe
  bool get isAvailable => false;
  String? get lastError => _lastError;

  Future<WearablePermissionStatus> initialize({
    bool requestAuthorization = true,
  }) async {
    if (_disposed) {
      return WearablePermissionStatus.unavailable;
    }
    _permissionStatus = WearablePermissionStatus.unavailable;
    _lastError =
        'Wearable health data is only available with a paid Apple Developer account '
        '(HealthKit entitlement) or via Android Health Connect.';
    return _permissionStatus;
  }

  Future<WearablePermissionStatus> requestPermissions() async {
    if (_disposed) {
      return WearablePermissionStatus.unavailable;
    }
    return _permissionStatus;
  }

  Future<bool> startMonitoring() async {
    if (_disposed) {
      return false;
    }
    _permissionStatus = WearablePermissionStatus.unavailable;
    return false;
  }

  void stopMonitoring() {}

  Future<WearableMetrics?> refresh({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    return null;
  }

  Future<void> openHealthConnectInstall() async {}

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    stopMonitoring();
    unawaited(_heartRateController.close());
    unawaited(_metricsController.close());
  }
}
