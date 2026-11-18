import 'dart:math' as math;

abstract final class GameConstants {
  static const double walkThresholdKph = 3;
  static const double sprintThresholdKph = 8;
  static const double maximumDisplaySpeedKph = 20;
  static const double maximumInclinePercent = 20;

  static const double playerScreenX = 0.22;
  static const double gravity = 1900;
  static const double jumpVelocity = -730;
  static const double coyoteTimeSeconds = 0.1;

  static const double baseWorldSpeed = 80;
  static const double worldSpeedPerKph = 25;
  static const double comboToleranceKph = 0.65;
  static const double comboBuildSeconds = 4.5;
  static const double maximumCombo = 20;

  static const double coinRadius = 14;
  static const double playerCollisionWidth = 38;
  static const double playerCollisionHeight = 68;

  static const Duration ftmsConnectTimeout = Duration(seconds: 12);
  static const Duration staleMetricsAfter = Duration(seconds: 3);

  static double worldSpeedFor(double speedKph) {
    if (speedKph < 0.15) {
      return 0;
    }
    return baseWorldSpeed + speedKph * worldSpeedPerKph;
  }

  static double normalizedSpeed(double speedKph) =>
      (speedKph / maximumDisplaySpeedKph).clamp(0, 1).toDouble();

  static double terrainSlopeFor(double inclinePercent) =>
      math.tan(math.atan(inclinePercent.clamp(-10, 20).toDouble() / 100));
}

abstract final class BleUuids {
  static const String fitnessMachineService =
      '00001826-0000-1000-8000-00805f9b34fb';
  static const String treadmillData = '00002acd-0000-1000-8000-00805f9b34fb';
}
