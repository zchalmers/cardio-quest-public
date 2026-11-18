import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

import '../core/constants.dart';
import '../models/machine_models.dart';
import 'health_data_merger.dart';
import 'heart_rate_zones.dart';
import 'wearable_service.dart';

/// Read-only bridge between flutter_ftms and the game.
///
/// The service deliberately never requests Fitness Machine Control Point
/// access. It only scans, connects, and subscribes to machine data.
class MachineService extends ChangeNotifier {
  MachineService({
    WearableService? wearableService,
    HealthDataMerger? dataMerger,
    HeartRateZoneEngine? heartRateZoneEngine,
  }) : _wearableService = wearableService,
       _dataMerger = dataMerger ?? HealthDataMerger(),
       _ownsDataMerger = dataMerger == null,
       _heartRateZoneEngine =
           heartRateZoneEngine ??
           HeartRateZoneEngine(estimatedMaxHeartRate: 190),
       _ownsHeartRateZoneEngine = heartRateZoneEngine == null {
    _bindHealthData();
    _bindBluetooth();
  }

  @visibleForTesting
  MachineService.withoutBluetooth({
    WearableService? wearableService,
    HealthDataMerger? dataMerger,
    HeartRateZoneEngine? heartRateZoneEngine,
  }) : _wearableService = wearableService,
       _dataMerger = dataMerger ?? HealthDataMerger(),
       _ownsDataMerger = dataMerger == null,
       _heartRateZoneEngine =
           heartRateZoneEngine ??
           HeartRateZoneEngine(estimatedMaxHeartRate: 190),
       _ownsHeartRateZoneEngine = heartRateZoneEngine == null {
    _bindHealthData();
  }

  void _bindHealthData() {
    _unifiedMetricsSubscription = _dataMerger.metricsStream.listen(
      _handleUnifiedMetrics,
    );
    final WearableService? wearable = _wearableService;
    if (wearable != null) {
      _wearableMetricsSubscription = wearable.metricsStream.listen(
        _dataMerger.addWearableMetrics,
        onError: _handleWearableStreamError,
      );
      final WearableMetrics? currentWearableMetrics = wearable.currentMetrics;
      if (currentWearableMetrics != null) {
        _dataMerger.addWearableMetrics(currentWearableMetrics);
      }
    }
    _dataMerger.addMachineMetrics(_machineMetrics);
  }

  void _bindBluetooth() {
    _scanResultsSubscription = FTMS.scanResults.listen(
      _handleScanResults,
      onError: _handleStreamError,
    );
    _scanStateSubscription = FTMS.isScanning.listen((bool scanning) {
      _isScanning = scanning;
      notifyListeners();
    });
    _bluetoothStateSubscription = FTMS.bluetoothState.listen(
      _handleBluetoothState,
    );
    unawaited(_restoreConnectedDevices());
  }

  final Map<String, BluetoothDevice> _nativeDevices =
      <String, BluetoothDevice>{};

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _scanStateSubscription;
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<WearableMetrics>? _wearableMetricsSubscription;
  StreamSubscription<MachineMetrics>? _unifiedMetricsSubscription;

  final WearableService? _wearableService;
  final HealthDataMerger _dataMerger;
  final bool _ownsDataMerger;
  final HeartRateZoneEngine _heartRateZoneEngine;
  final bool _ownsHeartRateZoneEngine;

  List<MachineDevice> _devices = <MachineDevice>[];
  MachineDevice? _selectedDevice;
  BluetoothDevice? _connectedNativeDevice;
  MachineMetrics _machineMetrics = const MachineMetrics();
  MachineMetrics _metrics = const MachineMetrics();
  WorkoutState _state = WorkoutState.disconnected;
  bool _isScanning = false;
  bool _simulatorEnabled = false;
  String? _errorMessage;
  DateTime? _lastMetricAt;

  final List<WorkoutMetricSample> _workoutSamples = <WorkoutMetricSample>[];
  DateTime? _workoutStartedAt;
  DateTime? _activeSegmentStartedAt;
  DateTime? _lastWorkoutSampleAt;
  Duration _accumulatedActiveDuration = Duration.zero;
  double _machineDistanceAtWorkoutStart = 0;
  double? _wearableEnergyAtWorkoutStart;
  int? _wearableStepsAtWorkoutStart;
  double _heartRateSum = 0;
  int _heartRateSampleCount = 0;
  int _maximumHeartRate = 0;
  int _wearableHeartRateSampleCount = 0;
  bool _usedWearableData = false;
  double? _lastRecordedHrvSdnn;
  double? _lastRecordedHrvRmssd;

  List<MachineDevice> get devices => List.unmodifiable(_devices);
  MachineDevice? get selectedDevice => _selectedDevice;
  MachineMetrics get metrics => _metrics;
  Stream<MachineMetrics> get metricsStream => _dataMerger.metricsStream;
  WearableService? get wearableService => _wearableService;
  HeartRateZoneEngine get heartRateZoneEngine => _heartRateZoneEngine;
  WorkoutState get state => _state;
  bool get isScanning => _isScanning;
  bool get simulatorEnabled => _simulatorEnabled;
  bool get hasLiveMachine =>
      _connectedNativeDevice != null &&
      _state != WorkoutState.disconnected &&
      !_simulatorEnabled;
  String? get errorMessage => _errorMessage;
  List<WorkoutMetricSample> get workoutSamples =>
      List<WorkoutMetricSample>.unmodifiable(_workoutSamples);
  Map<HeartRateZone, Duration> get heartRateZoneDurations =>
      _heartRateZoneEngine.zoneDurations;
  HeartRateVariabilityStats get heartRateVariability =>
      _heartRateZoneEngine.variability;
  HeartRateRecoveryStats get heartRateRecovery => _heartRateZoneEngine.recovery;
  int get averageHeartRateBpm => _heartRateSampleCount == 0
      ? 0
      : (_heartRateSum / _heartRateSampleCount).round();
  int get maximumHeartRateBpm => _maximumHeartRate;
  int? get restingHeartRateBpm => _metrics.restingHeartRateBpm;
  int get wearableHeartRateSampleCount => _wearableHeartRateSampleCount;
  bool get usedWearableData => _usedWearableData;
  double get workoutActiveEnergyCalories {
    final double? current = _metrics.activeEnergyCalories;
    final double? baseline = _wearableEnergyAtWorkoutStart;
    if (current == null || baseline == null) {
      return 0;
    }
    return (current - baseline).clamp(0, double.infinity).toDouble();
  }

  int get workoutStepCount {
    final int? current = _metrics.stepCount;
    final int? baseline = _wearableStepsAtWorkoutStart;
    if (current == null || baseline == null) {
      return 0;
    }
    return (current - baseline).clamp(0, 0x7fffffff).toInt();
  }

  Future<void> startScan() async {
    _errorMessage = null;
    try {
      final bool supported = await FTMS.isBluetoothEnabled();
      if (!supported) {
        throw StateError('Bluetooth LE is not supported on this device.');
      }
      final BluetoothAdapterState adapterState = await FTMS.bluetoothState.first
          .timeout(const Duration(seconds: 2));
      if (adapterState != BluetoothAdapterState.on) {
        throw StateError('Bluetooth adapter is off.');
      }
      await FTMS.scanForBluetoothDevices();
    } on Object catch (error) {
      _errorMessage = _friendlyBluetoothError(error);
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(MachineDevice device) async {
    final BluetoothDevice? nativeDevice = _nativeDevices[device.id];
    if (nativeDevice == null) {
      _errorMessage = 'That machine is no longer in range. Scan again.';
      notifyListeners();
      return;
    }

    await _connectionSubscription?.cancel();
    if (_connectedNativeDevice != null &&
        _connectedNativeDevice!.remoteId.str != nativeDevice.remoteId.str) {
      await FTMS.disconnectFromFTMSDevice(_connectedNativeDevice!);
    }

    _simulatorEnabled = false;
    _selectedDevice = device;
    _connectedNativeDevice = nativeDevice;
    _state = WorkoutState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      await FTMS.connectToFTMSDevice(nativeDevice);
      await nativeDevice.connectionState
          .where(
            (BluetoothConnectionState connectionState) =>
                connectionState == BluetoothConnectionState.connected,
          )
          .first
          .timeout(GameConstants.ftmsConnectTimeout);

      _connectionSubscription = nativeDevice.connectionState.listen(
        _handleConnectionState,
        onError: _handleStreamError,
      );

      final DeviceDataType? dataType = await FTMS.getDeviceDataType(
        nativeDevice,
      );
      if (dataType != null) {
        _selectedDevice = device.copyWith(kind: _kindFromDataType(dataType));
      }

      await FTMS.useDeviceDataCharacteristic(
        nativeDevice,
        _handleDeviceData,
        preferredDeviceDataType: _preferredTypeFor(
          _selectedDevice?.kind ?? MachineKind.unknown,
        ),
      );

      _state = WorkoutState.connectedIdle;
      notifyListeners();
    } on TimeoutException {
      await FTMS.disconnectFromFTMSDevice(nativeDevice);
      _connectedNativeDevice = null;
      _state = WorkoutState.disconnected;
      _errorMessage =
          'The connection timed out. Move closer and make sure no other app '
          'is using the machine.';
      notifyListeners();
    } on Object catch (error) {
      _state = WorkoutState.disconnected;
      _errorMessage = _friendlyBluetoothError(error);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    final BluetoothDevice? device = _connectedNativeDevice;
    _connectedNativeDevice = null;
    _selectedDevice = null;
    _simulatorEnabled = false;
    _setMachineMetrics(const MachineMetrics());
    _state = WorkoutState.disconnected;
    notifyListeners();

    if (device != null) {
      try {
        await FTMS.disconnectFromFTMSDevice(device);
      } on Object catch (error) {
        debugPrint('FTMS disconnect warning: $error');
      }
    }
  }

  Future<void> enableSimulator() async {
    if (_connectedNativeDevice != null) {
      await disconnect();
    }
    _simulatorEnabled = true;
    _selectedDevice = const MachineDevice(
      id: 'touch-simulator',
      name: 'Touch controls',
      rssi: 0,
      kind: MachineKind.simulator,
    );
    _setMachineMetrics(
      MachineMetrics(
        speedKph: 5,
        cadenceRpm: 140,
        heartRateBpm: 122,
        heartRateRecordedAt: DateTime.now(),
        receivedAt: DateTime.now(),
        isSimulated: true,
      ),
    );
    _state = WorkoutState.connectedIdle;
    _errorMessage = null;
    notifyListeners();
  }

  void setFallbackSpeed(double speedKph) {
    if (!_simulatorEnabled) {
      return;
    }
    final double speed = speedKph
        .clamp(0, GameConstants.maximumDisplaySpeedKph)
        .toDouble();
    final double cadence = speed < 0.1 ? 0 : 92 + speed * 9;
    final int heartRate = speed < 0.1 ? 84 : (94 + speed * 6).round();
    final DateTime now = DateTime.now();
    _setMachineMetrics(
      _machineMetrics.copyWith(
        speedKph: speed,
        cadenceRpm: cadence,
        heartRateBpm: heartRate.clamp(0, 195).toInt(),
        heartRateRecordedAt: now,
        receivedAt: now,
        isSimulated: true,
      ),
    );
    notifyListeners();
  }

  void setFallbackIncline(double inclinePercent) {
    if (!_simulatorEnabled) {
      return;
    }
    _setMachineMetrics(
      _machineMetrics.copyWith(
        inclinePercent: inclinePercent
            .clamp(0, GameConstants.maximumInclinePercent)
            .toDouble(),
        receivedAt: DateTime.now(),
        isSimulated: true,
      ),
    );
    notifyListeners();
  }

  void beginWorkout() {
    if (_state == WorkoutState.paused) {
      resumeWorkout();
      return;
    }
    if (_state == WorkoutState.connectedIdle || _simulatorEnabled) {
      _startWorkoutTracking();
      _state = WorkoutState.running;
      notifyListeners();
    }
  }

  void pauseWorkout() {
    if (_state == WorkoutState.running) {
      final DateTime now = DateTime.now();
      _captureWorkoutMetrics(_metrics, at: now, force: true);
      _closeActiveSegment(now);
      _heartRateZoneEngine.pause(at: now);
      _state = WorkoutState.paused;
      notifyListeners();
    }
  }

  void resumeWorkout() {
    if (_state == WorkoutState.paused) {
      final DateTime now = DateTime.now();
      _activeSegmentStartedAt = now;
      _heartRateZoneEngine.resume(at: now);
      _state = WorkoutState.running;
      notifyListeners();
    }
  }

  void completeWorkout() {
    if (_state == WorkoutState.running || _state == WorkoutState.paused) {
      final DateTime now = DateTime.now();
      if (_state == WorkoutState.running) {
        _captureWorkoutMetrics(_metrics, at: now, force: true);
        _closeActiveSegment(now);
      }
      _heartRateZoneEngine.finish(at: now);
      _heartRateZoneEngine.beginRecovery(at: now);
    }
    _state = WorkoutState.complete;
    notifyListeners();
  }

  void resetWorkout() {
    _resetWorkoutTracking();
    _state = _selectedDevice == null
        ? WorkoutState.disconnected
        : WorkoutState.connectedIdle;
    notifyListeners();
  }

  Future<void> _restoreConnectedDevices() async {
    try {
      final List<BluetoothDevice> connected = await FTMS.listDevices();
      if (connected.isEmpty) {
        return;
      }
      for (final BluetoothDevice nativeDevice in connected) {
        final String id = nativeDevice.remoteId.str;
        _nativeDevices[id] = nativeDevice;
        final String name = nativeDevice.platformName.trim().isEmpty
            ? 'FTMS cardio machine'
            : nativeDevice.platformName.trim();
        _upsertDevice(MachineDevice(id: id, name: name, rssi: 0));
      }
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Unable to restore connected FTMS devices: $error');
    }
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final ScanResult result in results) {
      final BluetoothDevice nativeDevice = result.device;
      final String id = nativeDevice.remoteId.str;
      _nativeDevices[id] = nativeDevice;
      final String advertisedName = result.advertisementData.advName.trim();
      final String platformName = nativeDevice.platformName.trim();
      final String name = advertisedName.isNotEmpty
          ? advertisedName
          : platformName.isNotEmpty
          ? platformName
          : 'FTMS machine';
      final DeviceDataType? dataType = FTMS.getDeviceDataTypeWithoutConnecting(
        nativeDevice,
      );
      _upsertDevice(
        MachineDevice(
          id: id,
          name: name,
          rssi: result.rssi,
          kind: dataType == null
              ? MachineKind.unknown
              : _kindFromDataType(dataType),
        ),
      );
    }
    _devices.sort(
      (MachineDevice a, MachineDevice b) => b.rssi.compareTo(a.rssi),
    );
    notifyListeners();
  }

  void _upsertDevice(MachineDevice device) {
    final int index = _devices.indexWhere(
      (MachineDevice existing) => existing.id == device.id,
    );
    if (index == -1) {
      _devices = <MachineDevice>[..._devices, device];
    } else {
      _devices[index] = device;
    }
  }

  void _handleDeviceData(DeviceData data) {
    final DateTime now = DateTime.now();
    final double? reportedSpeed = _valueByName(
      data,
      DeviceDataParameterName.instSpeed.name,
    );
    final double? reportedIncline = _valueByName(
      data,
      DeviceDataParameterName.inclination.name,
    );
    final double? bikeCadence = _valueByName(
      data,
      DeviceDataParameterName.instCadence.name,
    );
    final double? stepCadence = _valueByName(
      data,
      DeviceDataParameterName.stepPerMinute.name,
    );
    final double? reportedDistance = _valueByName(
      data,
      DeviceDataParameterName.totalDistance.name,
    );
    final double? reportedHeartRate = _valueByName(
      data,
      DeviceDataParameterName.heartRate.name,
    );

    double integratedDistance = _machineMetrics.totalDistanceMeters;
    if (reportedDistance == null && _lastMetricAt != null) {
      final double seconds =
          now.difference(_lastMetricAt!).inMilliseconds / 1000;
      integratedDistance +=
          _machineMetrics.speedKph / 3.6 * seconds.clamp(0, 2).toDouble();
    }
    _lastMetricAt = now;

    _setMachineMetrics(
      MachineMetrics(
        speedKph: (reportedSpeed ?? _machineMetrics.speedKph)
            .clamp(0, 80)
            .toDouble(),
        inclinePercent: (reportedIncline ?? _machineMetrics.inclinePercent)
            .clamp(-20, 40)
            .toDouble(),
        cadenceRpm: (bikeCadence ?? stepCadence ?? _machineMetrics.cadenceRpm)
            .clamp(0, 300)
            .toDouble(),
        totalDistanceMeters: (reportedDistance ?? integratedDistance)
            .clamp(0, double.infinity)
            .toDouble(),
        heartRateBpm:
            (reportedHeartRate?.round() ?? _machineMetrics.heartRateBpm)
                .clamp(0, 255)
                .toInt(),
        heartRateRecordedAt: reportedHeartRate == null
            ? _machineMetrics.heartRateRecordedAt
            : now,
        receivedAt: now,
      ),
    );
    notifyListeners();
  }

  double? _valueByName(DeviceData data, String name) {
    for (final DeviceDataParameterValue parameter
        in data.getDeviceDataParameterValues()) {
      if (parameter.name.name == name) {
        return parameter.value * parameter.factor.toDouble();
      }
    }
    return null;
  }

  void _handleConnectionState(BluetoothConnectionState connectionState) {
    if (connectionState != BluetoothConnectionState.disconnected) {
      return;
    }
    if (_simulatorEnabled) {
      return;
    }
    _connectedNativeDevice = null;
    _state = WorkoutState.disconnected;
    _setMachineMetrics(const MachineMetrics());
    _errorMessage = 'The cardio machine disconnected.';
    notifyListeners();
  }

  void _handleBluetoothState(BluetoothAdapterState adapterState) {
    if (adapterState == BluetoothAdapterState.on) {
      return;
    }
    if (_state == WorkoutState.connecting) {
      _state = WorkoutState.disconnected;
    }
    if (!_simulatorEnabled) {
      _errorMessage = 'Turn on Bluetooth to discover cardio machines.';
    }
    notifyListeners();
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _errorMessage = _friendlyBluetoothError(error);
    notifyListeners();
  }

  void _handleWearableStreamError(Object error, StackTrace stackTrace) {
    // Do not expose or log the underlying health exception; it may contain
    // sensitive provider details. FTMS continues without wearable data.
    notifyListeners();
  }

  void _setMachineMetrics(MachineMetrics metrics) {
    _machineMetrics = metrics;
    _dataMerger.addMachineMetrics(metrics);
  }

  void _handleUnifiedMetrics(MachineMetrics metrics) {
    _metrics = metrics;
    if (_state == WorkoutState.running) {
      _captureWorkoutMetrics(metrics, at: DateTime.now());
    } else if (_state == WorkoutState.complete &&
        metrics.heartRateBpm >= 25 &&
        metrics.heartRateBpm <= 250) {
      _heartRateZoneEngine.addSample(metrics.heartRateBpm, at: DateTime.now());
    }
    notifyListeners();
  }

  void _startWorkoutTracking() {
    _resetWorkoutTracking();
    final DateTime now = DateTime.now();
    _workoutStartedAt = now;
    _activeSegmentStartedAt = now;
    _machineDistanceAtWorkoutStart = _machineMetrics.totalDistanceMeters;
    _wearableEnergyAtWorkoutStart = _metrics.activeEnergyCalories;
    _wearableStepsAtWorkoutStart = _metrics.stepCount;
    _heartRateZoneEngine.start(at: now);
    _captureWorkoutMetrics(_metrics, at: now, force: true);
  }

  void _captureWorkoutMetrics(
    MachineMetrics metrics, {
    required DateTime at,
    bool force = false,
  }) {
    if (_workoutStartedAt == null) {
      return;
    }
    final DateTime? lastAt = _lastWorkoutSampleAt;
    if (!force &&
        lastAt != null &&
        at.difference(lastAt) < const Duration(seconds: 1)) {
      return;
    }
    _lastWorkoutSampleAt = at;

    final int heartRate = metrics.heartRateBpm;
    if (heartRate >= 25 && heartRate <= 250) {
      _heartRateZoneEngine.addSample(heartRate, at: at);
      _heartRateSum += heartRate;
      _heartRateSampleCount += 1;
      if (heartRate > _maximumHeartRate) {
        _maximumHeartRate = heartRate;
      }
      if (metrics.heartRateSource == HeartRateSource.wearable) {
        _wearableHeartRateSampleCount += 1;
        _usedWearableData = true;
      }
    }
    final double? hrv = metrics.hrvSdnnMilliseconds;
    if (hrv != null && hrv != _lastRecordedHrvSdnn) {
      _heartRateZoneEngine.addHrvSample(hrv);
      _lastRecordedHrvSdnn = hrv;
      _usedWearableData = true;
    }
    final double? rmssd = metrics.hrvRmssdMilliseconds;
    if (rmssd != null && rmssd != _lastRecordedHrvRmssd) {
      _heartRateZoneEngine.addRmssdSample(rmssd);
      _lastRecordedHrvRmssd = rmssd;
      _usedWearableData = true;
    }
    if (metrics.wearableDataAvailable) {
      _usedWearableData = true;
    }

    _workoutSamples.add(
      WorkoutMetricSample(
        recordedAt: at,
        elapsed: _activeDurationAt(at),
        speedKph: metrics.speedKph,
        inclinePercent: metrics.inclinePercent,
        distanceMeters:
            (metrics.totalDistanceMeters - _machineDistanceAtWorkoutStart)
                .clamp(0, double.infinity)
                .toDouble(),
        heartRateBpm: heartRate,
        heartRateSource: metrics.heartRateSource,
        activeEnergyCalories: workoutActiveEnergyCalories,
      ),
    );
  }

  Duration _activeDurationAt(DateTime at) {
    final DateTime? activeSegmentStartedAt = _activeSegmentStartedAt;
    if (activeSegmentStartedAt == null || at.isBefore(activeSegmentStartedAt)) {
      return _accumulatedActiveDuration;
    }
    return _accumulatedActiveDuration + at.difference(activeSegmentStartedAt);
  }

  void _closeActiveSegment(DateTime at) {
    final DateTime? activeSegmentStartedAt = _activeSegmentStartedAt;
    if (activeSegmentStartedAt != null &&
        !at.isBefore(activeSegmentStartedAt)) {
      _accumulatedActiveDuration += at.difference(activeSegmentStartedAt);
    }
    _activeSegmentStartedAt = null;
  }

  void _resetWorkoutTracking() {
    _workoutSamples.clear();
    _workoutStartedAt = null;
    _activeSegmentStartedAt = null;
    _lastWorkoutSampleAt = null;
    _accumulatedActiveDuration = Duration.zero;
    _machineDistanceAtWorkoutStart = 0;
    _wearableEnergyAtWorkoutStart = null;
    _wearableStepsAtWorkoutStart = null;
    _heartRateSum = 0;
    _heartRateSampleCount = 0;
    _maximumHeartRate = 0;
    _wearableHeartRateSampleCount = 0;
    _usedWearableData = false;
    _lastRecordedHrvSdnn = null;
    _lastRecordedHrvRmssd = null;
    _heartRateZoneEngine.reset();
  }

  MachineKind _kindFromDataType(DeviceDataType type) {
    return switch (type) {
      DeviceDataType.treadmill => MachineKind.treadmill,
      DeviceDataType.indoorBike => MachineKind.indoorBike,
      DeviceDataType.crossTrainer => MachineKind.crossTrainer,
      DeviceDataType.rower => MachineKind.rower,
    };
  }

  DeviceDataType? _preferredTypeFor(MachineKind kind) {
    return switch (kind) {
      MachineKind.treadmill => DeviceDataType.treadmill,
      MachineKind.indoorBike => DeviceDataType.indoorBike,
      MachineKind.crossTrainer => DeviceDataType.crossTrainer,
      MachineKind.rower => DeviceDataType.rower,
      MachineKind.unknown || MachineKind.simulator => null,
    };
  }

  String _friendlyBluetoothError(Object error) {
    final String message = error.toString();
    if (message.toLowerCase().contains('permission')) {
      return 'Bluetooth permission is required to find your cardio machine.';
    }
    if (message.toLowerCase().contains('adapter') ||
        message.toLowerCase().contains('bluetooth')) {
      return 'Bluetooth is unavailable. Check that it is turned on.';
    }
    return 'Could not connect to the machine. Please try again.';
  }

  @override
  void dispose() {
    final StreamSubscription<List<ScanResult>>? scanResultsSubscription =
        _scanResultsSubscription;
    final StreamSubscription<bool>? scanStateSubscription =
        _scanStateSubscription;
    final StreamSubscription<BluetoothAdapterState>?
    bluetoothStateSubscription = _bluetoothStateSubscription;
    if (scanResultsSubscription != null) {
      unawaited(scanResultsSubscription.cancel());
    }
    if (scanStateSubscription != null) {
      unawaited(scanStateSubscription.cancel());
    }
    if (bluetoothStateSubscription != null) {
      unawaited(bluetoothStateSubscription.cancel());
    }
    final StreamSubscription<BluetoothConnectionState>? connectionSubscription =
        _connectionSubscription;
    if (connectionSubscription != null) {
      unawaited(connectionSubscription.cancel());
    }
    final StreamSubscription<WearableMetrics>? wearableMetricsSubscription =
        _wearableMetricsSubscription;
    if (wearableMetricsSubscription != null) {
      unawaited(wearableMetricsSubscription.cancel());
    }
    final StreamSubscription<MachineMetrics>? unifiedMetricsSubscription =
        _unifiedMetricsSubscription;
    if (unifiedMetricsSubscription != null) {
      unawaited(unifiedMetricsSubscription.cancel());
    }
    if (_ownsDataMerger) {
      _dataMerger.dispose();
    }
    if (_ownsHeartRateZoneEngine) {
      _heartRateZoneEngine.dispose();
    }
    super.dispose();
  }
}
