import 'package:flutter/foundation.dart';

enum FitnessPlatform { strava, garmin }

enum FitnessConnectionStatus {
  unavailable,
  disconnected,
  connecting,
  connected,
  error,
}

enum FitnessUploadStatus { queued, uploading, processing, succeeded, failed }

@immutable
class FitnessAccountProfile {
  const FitnessAccountProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };

  factory FitnessAccountProfile.fromJson(Map<String, Object?> json) {
    return FitnessAccountProfile(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Connected account',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

@immutable
class OAuthTokenSet {
  const OAuthTokenSet({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.scope = '',
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String scope;
  final String tokenType;

  bool expiresWithin(Duration duration, {DateTime? now}) =>
      expiresAt.isBefore((now ?? DateTime.now()).add(duration));

  Map<String, Object?> toJson() => <String, Object?>{
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'scope': scope,
    'tokenType': tokenType,
  };

  factory OAuthTokenSet.fromJson(Map<String, Object?> json) {
    return OAuthTokenSet(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      scope: json['scope']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
    );
  }
}

@immutable
class FitnessUploadResult {
  const FitnessUploadResult.success({required this.remoteId, this.message})
    : succeeded = true,
      processing = false,
      retryAt = null,
      authenticationRequired = false;

  const FitnessUploadResult.processing({
    required this.remoteId,
    this.message,
    this.retryAt,
  }) : succeeded = false,
       processing = true,
       authenticationRequired = false;

  const FitnessUploadResult.failure({
    required this.message,
    this.retryAt,
    this.authenticationRequired = false,
  }) : succeeded = false,
       processing = false,
       remoteId = null;

  final bool succeeded;
  final bool processing;
  final String? remoteId;
  final String? message;
  final DateTime? retryAt;
  final bool authenticationRequired;
}

class FitnessServiceException implements Exception {
  const FitnessServiceException(
    this.message, {
    this.retryAt,
    this.authenticationRequired = false,
  });

  final String message;
  final DateTime? retryAt;
  final bool authenticationRequired;

  @override
  String toString() => message;
}

@immutable
class FitnessExportEntry {
  const FitnessExportEntry({
    required this.id,
    required this.workoutId,
    required this.platform,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.endedAt,
    required this.machineKindName,
    required this.fileName,
    required this.dataType,
    required this.sportType,
    required this.payloadPath,
    this.attempts = 0,
    this.nextAttemptAt,
    this.remoteId,
    this.errorMessage,
  });

  final String id;
  final String workoutId;
  final FitnessPlatform platform;
  final FitnessUploadStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime endedAt;
  final String machineKindName;
  final String fileName;
  final String dataType;
  final String sportType;
  final String payloadPath;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? remoteId;
  final String? errorMessage;

  bool get isPending =>
      status == FitnessUploadStatus.queued ||
      status == FitnessUploadStatus.uploading ||
      status == FitnessUploadStatus.processing ||
      status == FitnessUploadStatus.failed;

  FitnessExportEntry copyWith({
    FitnessUploadStatus? status,
    DateTime? updatedAt,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    String? remoteId,
    String? errorMessage,
    bool clearError = false,
    String? payloadPath,
  }) {
    return FitnessExportEntry(
      id: id,
      workoutId: workoutId,
      platform: platform,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endedAt: endedAt,
      machineKindName: machineKindName,
      fileName: fileName,
      dataType: dataType,
      sportType: sportType,
      payloadPath: payloadPath ?? this.payloadPath,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: clearNextAttempt
          ? null
          : nextAttemptAt ?? this.nextAttemptAt,
      remoteId: remoteId ?? this.remoteId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'workoutId': workoutId,
    'platform': platform.name,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'machineKindName': machineKindName,
    'fileName': fileName,
    'dataType': dataType,
    'sportType': sportType,
    'payloadPath': payloadPath,
    'attempts': attempts,
    'nextAttemptAt': nextAttemptAt?.toUtc().toIso8601String(),
    'remoteId': remoteId,
    'errorMessage': errorMessage,
  };

  factory FitnessExportEntry.fromJson(Map<String, Object?> json) {
    return FitnessExportEntry(
      id: json['id']?.toString() ?? '',
      workoutId: json['workoutId']?.toString() ?? '',
      platform: FitnessPlatform.values.byName(
        json['platform']?.toString() ?? FitnessPlatform.strava.name,
      ),
      status: FitnessUploadStatus.values.byName(
        json['status']?.toString() ?? FitnessUploadStatus.failed.name,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      endedAt:
          DateTime.tryParse(json['endedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      machineKindName: json['machineKindName']?.toString() ?? 'unknown',
      fileName: json['fileName']?.toString() ?? 'cardio-quest.fit',
      dataType: json['dataType']?.toString() ?? 'fit',
      sportType: json['sportType']?.toString() ?? 'Workout',
      payloadPath: json['payloadPath']?.toString() ?? '',
      attempts: _asInt(json['attempts']),
      nextAttemptAt: DateTime.tryParse(json['nextAttemptAt']?.toString() ?? ''),
      remoteId: json['remoteId']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
