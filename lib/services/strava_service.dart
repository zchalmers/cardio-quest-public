import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../core/fitness_api_config.dart';
import 'fitness_export_models.dart';

class StravaService {
  StravaService({
    StravaApiConfig config = FitnessApiConfig.strava,
    FlutterSecureStorage? secureStorage,
    http.Client? client,
    DateTime Function()? clock,
  }) : _config = config,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const String _tokenKey = 'fitness.strava.tokens.v1';
  static const String _profileKey = 'fitness.strava.profile.v1';
  static final Uri _authorizationEndpoint = Uri(
    scheme: 'https',
    host: 'www.strava.com',
    path: '/oauth/mobile/authorize',
  );
  static final Uri _tokenEndpoint = Uri(
    scheme: 'https',
    host: 'www.strava.com',
    path: '/oauth/token',
  );
  static final Uri _revokeEndpoint = Uri(
    scheme: 'https',
    host: 'www.strava.com',
    path: '/oauth/revoke',
  );
  static const String _apiRoot = 'https://www.strava.com/api/v3';

  final StravaApiConfig _config;
  final FlutterSecureStorage _secureStorage;
  final http.Client _client;
  final DateTime Function() _clock;
  final _StravaRateLimiter _rateLimiter = _StravaRateLimiter();

  OAuthTokenSet? _tokens;
  FitnessAccountProfile? _profile;

  bool get isConfigured => _config.isConfigured;
  bool get isConnected => _tokens != null;
  FitnessAccountProfile? get profile => _profile;

  Future<void> initialize() async {
    try {
      final String? encodedTokens = await _secureStorage.read(key: _tokenKey);
      final String? encodedProfile = await _secureStorage.read(
        key: _profileKey,
      );
      if (encodedTokens != null) {
        _tokens = OAuthTokenSet.fromJson(_decodeObject(encodedTokens));
        if (_tokens!.accessToken.isEmpty && _tokens!.refreshToken.isEmpty) {
          throw const FormatException('Stored Strava token is empty.');
        }
      }
      if (encodedProfile != null) {
        _profile = FitnessAccountProfile.fromJson(
          _decodeObject(encodedProfile),
        );
      }
    } on Object {
      // Keychain access can legitimately change when SideStore assigns a new
      // application identifier. Treat inaccessible old credentials as signed
      // out instead of allowing startup initialization to fail.
      _tokens = null;
      _profile = null;
      try {
        await _clearLocalCredentials();
      } on Object {
        // The keychain itself may be unavailable; in-memory state is enough.
      }
    }
  }

  Future<FitnessAccountProfile> connect() async {
    if (!isConfigured) {
      throw const FitnessServiceException(
        'Strava is not configured. Add STRAVA_CLIENT_ID and '
        'STRAVA_CLIENT_SECRET to this build.',
      );
    }

    final String state = _randomUrlSafe(32);
    final Uri authorizationUri = _authorizationEndpoint.replace(
      queryParameters: <String, String>{
        'client_id': _config.clientId,
        'redirect_uri': _config.redirectUri,
        'response_type': 'code',
        'approval_prompt': 'auto',
        'scope': 'read,activity:write',
        'state': state,
      },
    );
    final String callback = await FlutterWebAuth2.authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: Uri.parse(_config.redirectUri).scheme,
    );
    final Uri callbackUri = Uri.parse(callback);
    if (callbackUri.queryParameters['state'] != state) {
      throw const FitnessServiceException(
        'Strava sign-in could not be verified. Please try again.',
      );
    }
    final String? error = callbackUri.queryParameters['error'];
    if (error != null) {
      throw FitnessServiceException(
        error == 'access_denied'
            ? 'Strava connection was cancelled.'
            : 'Strava authorization failed: $error',
      );
    }
    final String? code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const FitnessServiceException(
        'Strava did not return an authorization code.',
      );
    }
    final String grantedScope = callbackUri.queryParameters['scope'] ?? '';
    if (!grantedScope.split(',').contains('activity:write') &&
        !grantedScope.split(' ').contains('activity:write')) {
      throw const FitnessServiceException(
        'Cardio Quest needs Strava activity:write permission to upload '
        'completed workouts.',
      );
    }

    final http.Response response = await _client.post(
      _tokenEndpoint,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'client_id': _config.clientId,
        'client_secret': _config.clientSecret,
        'code': code,
        'grant_type': 'authorization_code',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FitnessServiceException(
        _apiError(response, fallback: 'Strava token exchange failed.'),
      );
    }
    final Map<String, Object?> body = _decodeObject(response.body);
    _tokens = _tokensFromResponse(body, fallbackScope: grantedScope);
    if (_tokens!.accessToken.isEmpty || _tokens!.refreshToken.isEmpty) {
      throw const FitnessServiceException(
        'Strava returned an incomplete token response.',
      );
    }
    final Object? athleteValue = body['athlete'];
    if (athleteValue is Map<String, Object?>) {
      _profile = _profileFromAthlete(athleteValue);
    } else {
      _profile = await _fetchProfile();
    }
    await _persistCredentials();
    return _profile!;
  }

  Future<void> disconnect() async {
    final OAuthTokenSet? tokens = _tokens;
    if (tokens == null) {
      await _clearLocalCredentials();
      return;
    }
    if (isConfigured) {
      final String credentials = base64Encode(
        utf8.encode('${_config.clientId}:${_config.clientSecret}'),
      );
      final http.Response response = await _client.post(
        _revokeEndpoint,
        headers: <String, String>{
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: <String, String>{
          'token': tokens.refreshToken,
          'token_type_hint': 'refresh_token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FitnessServiceException(
          _apiError(
            response,
            fallback:
                'Strava could not be disconnected. Check your connection '
                'and try again.',
          ),
        );
      }
    }
    await _clearLocalCredentials();
  }

  Future<FitnessUploadResult> uploadFit({
    required Uint8List bytes,
    required String fileName,
    required String externalId,
    required String sportType,
    String name = 'Cardio Quest',
  }) async {
    try {
      final String accessToken = await _validAccessToken();
      _rateLimiter.ensureAvailable(_clock());
      final http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse('$_apiRoot/uploads'))
            ..headers['Authorization'] = 'Bearer $accessToken'
            ..headers['Accept'] = 'application/json'
            ..fields.addAll(<String, String>{
              'name': name,
              'description': 'Completed with Cardio Quest',
              'trainer': '1',
              'commute': '0',
              'data_type': 'fit',
              'external_id': externalId,
              'sport_type': sportType,
            })
            ..files.add(
              http.MultipartFile.fromBytes('file', bytes, filename: fileName),
            );
      final http.Response response = await _send(request);
      if (response.statusCode == 401) {
        return const FitnessUploadResult.failure(
          message: 'Strava authorization expired. Reconnect Strava.',
          authenticationRequired: true,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _failureFromResponse(
          response,
          fallback: 'Strava rejected the workout upload.',
        );
      }
      final Map<String, Object?> body = _decodeObject(response.body);
      final String uploadId =
          body['id_str']?.toString() ?? body['id']?.toString() ?? '';
      if (uploadId.isEmpty) {
        return const FitnessUploadResult.failure(
          message: 'Strava accepted the file but returned no upload ID.',
        );
      }
      // Persist the accepted ID before polling. If the app is interrupted
      // after this point, the queue checks this upload instead of submitting a
      // duplicate activity.
      return FitnessUploadResult.processing(
        remoteId: uploadId,
        message: 'Strava accepted the workout and is processing it.',
        retryAt: _clock().add(const Duration(seconds: 1)),
      );
    } on FitnessServiceException catch (error) {
      return FitnessUploadResult.failure(
        message: error.message,
        retryAt: error.retryAt,
        authenticationRequired: error.authenticationRequired,
      );
    } on Object {
      return const FitnessUploadResult.failure(
        message: 'Strava is unreachable. The workout is queued for retry.',
      );
    }
  }

  Future<FitnessUploadResult> checkUpload(String uploadId) async {
    try {
      final String accessToken = await _validAccessToken();
      _rateLimiter.ensureAvailable(_clock());
      final http.Request request =
          http.Request('GET', Uri.parse('$_apiRoot/uploads/$uploadId'))
            ..headers['Authorization'] = 'Bearer $accessToken'
            ..headers['Accept'] = 'application/json';
      final http.Response response = await _send(request);
      if (response.statusCode == 401) {
        return const FitnessUploadResult.failure(
          message: 'Strava authorization expired. Reconnect Strava.',
          authenticationRequired: true,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _failureFromResponse(
          response,
          fallback: 'Could not check the Strava upload.',
        );
      }
      final Map<String, Object?> body = _decodeObject(response.body);
      final String? error = _nullableString(body['error']);
      if (error != null) {
        if (error.toLowerCase().contains('duplicate of activity')) {
          return const FitnessUploadResult.success(
            remoteId: 'duplicate',
            message: 'This workout was already uploaded to Strava.',
          );
        }
        return FitnessUploadResult.failure(message: error);
      }
      final String? activityId = _nullableString(body['activity_id']);
      if (activityId != null) {
        return FitnessUploadResult.success(
          remoteId: activityId,
          message: 'Uploaded to Strava',
        );
      }
      return FitnessUploadResult.processing(
        remoteId: uploadId,
        message: body['status']?.toString() ?? 'Strava is processing the file.',
        retryAt: _clock().add(const Duration(seconds: 5)),
      );
    } on FitnessServiceException catch (error) {
      return FitnessUploadResult.failure(
        message: error.message,
        retryAt: error.retryAt,
        authenticationRequired: error.authenticationRequired,
      );
    } on Object {
      return FitnessUploadResult.processing(
        remoteId: uploadId,
        message: 'Upload accepted; status check will retry when online.',
        retryAt: _clock().add(const Duration(minutes: 1)),
      );
    }
  }

  Future<String> _validAccessToken() async {
    OAuthTokenSet? tokens = _tokens;
    if (tokens == null) {
      throw const FitnessServiceException(
        'Connect Strava before sharing workouts.',
        authenticationRequired: true,
      );
    }
    if (!tokens.expiresWithin(const Duration(hours: 1), now: _clock())) {
      return tokens.accessToken;
    }
    if (!isConfigured) {
      throw const FitnessServiceException(
        'Strava credentials are missing from this build.',
        authenticationRequired: true,
      );
    }
    final http.Response response = await _client.post(
      _tokenEndpoint,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'client_id': _config.clientId,
        'client_secret': _config.clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refreshToken,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 400 || response.statusCode == 401) {
        throw const FitnessServiceException(
          'Strava authorization expired. Reconnect Strava.',
          authenticationRequired: true,
        );
      }
      throw FitnessServiceException(
        _apiError(response, fallback: 'Strava token refresh failed.'),
      );
    }
    tokens = _tokensFromResponse(
      _decodeObject(response.body),
      fallbackScope: tokens.scope,
    );
    _tokens = tokens;
    await _persistCredentials();
    return tokens.accessToken;
  }

  Future<FitnessAccountProfile> _fetchProfile() async {
    final String accessToken = _tokens!.accessToken;
    final http.Request request =
        http.Request('GET', Uri.parse('$_apiRoot/athlete'))
          ..headers['Authorization'] = 'Bearer $accessToken'
          ..headers['Accept'] = 'application/json';
    final http.Response response = await _send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const FitnessAccountProfile(id: '', displayName: 'Strava athlete');
    }
    return _profileFromAthlete(_decodeObject(response.body));
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    _rateLimiter.ensureAvailable(_clock());
    final http.StreamedResponse streamed = await _client.send(request);
    final http.Response response = await http.Response.fromStream(streamed);
    _rateLimiter.observe(response.headers, _clock());
    if (response.statusCode == 429) {
      throw FitnessServiceException(
        'Strava rate limit reached. The workout remains queued.',
        retryAt: _rateLimiter.nextAvailableAt(_clock(), response.headers),
      );
    }
    return response;
  }

  OAuthTokenSet _tokensFromResponse(
    Map<String, Object?> body, {
    required String fallbackScope,
  }) {
    final int expiresAtSeconds = _asInt(body['expires_at']);
    final int expiresInSeconds = _asInt(body['expires_in']);
    return OAuthTokenSet(
      accessToken: body['access_token']?.toString() ?? '',
      refreshToken: body['refresh_token']?.toString() ?? '',
      expiresAt: expiresAtSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              expiresAtSeconds * 1000,
              isUtc: true,
            )
          : _clock().toUtc().add(
              Duration(seconds: expiresInSeconds > 0 ? expiresInSeconds : 3600),
            ),
      scope: body['scope']?.toString() ?? fallbackScope,
      tokenType: body['token_type']?.toString() ?? 'Bearer',
    );
  }

  FitnessAccountProfile _profileFromAthlete(Map<String, Object?> athlete) {
    final String firstName = athlete['firstname']?.toString() ?? '';
    final String lastName = athlete['lastname']?.toString() ?? '';
    final String name = '$firstName $lastName'.trim();
    return FitnessAccountProfile(
      id: athlete['id']?.toString() ?? '',
      displayName: name.isNotEmpty
          ? name
          : athlete['username']?.toString() ?? 'Strava athlete',
      avatarUrl:
          _nullableString(athlete['profile_medium']) ??
          _nullableString(athlete['profile']),
    );
  }

  Future<void> _persistCredentials() async {
    final OAuthTokenSet? tokens = _tokens;
    final FitnessAccountProfile? profile = _profile;
    if (tokens != null) {
      await _secureStorage.write(
        key: _tokenKey,
        value: jsonEncode(tokens.toJson()),
      );
    }
    if (profile != null) {
      await _secureStorage.write(
        key: _profileKey,
        value: jsonEncode(profile.toJson()),
      );
    }
  }

  Future<void> _clearLocalCredentials() async {
    _tokens = null;
    _profile = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _profileKey);
  }

  FitnessUploadResult _failureFromResponse(
    http.Response response, {
    required String fallback,
  }) {
    final String message = _apiError(response, fallback: fallback);
    if (message.toLowerCase().contains('duplicate of activity')) {
      return const FitnessUploadResult.success(
        remoteId: 'duplicate',
        message: 'This workout was already uploaded to Strava.',
      );
    }
    return FitnessUploadResult.failure(
      message: message,
      retryAt: response.statusCode >= 500
          ? _clock().add(const Duration(minutes: 2))
          : null,
      authenticationRequired: response.statusCode == 401,
    );
  }

  String _apiError(http.Response response, {required String fallback}) {
    try {
      final Map<String, Object?> body = _decodeObject(response.body);
      final String? message =
          _nullableString(body['message']) ?? _nullableString(body['error']);
      if (message != null) {
        return message;
      }
    } on Object {
      // Provider error bodies are not guaranteed to be JSON.
    }
    return '$fallback (HTTP ${response.statusCode})';
  }

  void dispose() {
    _client.close();
  }
}

class _StravaRateLimiter {
  int _shortLimit = 100;
  int _dailyLimit = 1000;
  int _shortUsage = 0;
  int _dailyUsage = 0;
  DateTime? _shortResetAt;
  DateTime? _dailyResetAt;

  void observe(Map<String, String> headers, DateTime now) {
    _resetExpiredWindows(now);
    final List<int> limits = _pair(headers['x-ratelimit-limit']);
    final List<int> usage = _pair(headers['x-ratelimit-usage']);
    if (limits.length == 2) {
      _shortLimit = limits[0];
      _dailyLimit = limits[1];
    }
    if (usage.length == 2) {
      _shortUsage = usage[0];
      _dailyUsage = usage[1];
    } else {
      _shortUsage += 1;
      _dailyUsage += 1;
    }
    _shortResetAt = _nextQuarterHour(now);
    _dailyResetAt = _nextUtcMidnight(now);
  }

  void ensureAvailable(DateTime now) {
    _resetExpiredWindows(now);
    if (_shortUsage >= _shortLimit || _dailyUsage >= _dailyLimit) {
      throw FitnessServiceException(
        'Strava rate limit reached. The workout remains queued.',
        retryAt: nextAvailableAt(now, const <String, String>{}),
      );
    }
  }

  DateTime nextAvailableAt(DateTime now, Map<String, String> headers) {
    final int? retryAfter = int.tryParse(headers['retry-after'] ?? '');
    if (retryAfter != null) {
      return now.add(Duration(seconds: retryAfter));
    }
    if (_dailyUsage >= _dailyLimit) {
      return (_dailyResetAt ?? _nextUtcMidnight(now)).add(
        const Duration(minutes: 1),
      );
    }
    return (_shortResetAt ?? _nextQuarterHour(now)).add(
      const Duration(seconds: 5),
    );
  }

  void _resetExpiredWindows(DateTime now) {
    final DateTime? shortResetAt = _shortResetAt;
    if (shortResetAt != null && !now.isBefore(shortResetAt)) {
      _shortUsage = 0;
      _shortResetAt = _nextQuarterHour(now);
    }
    final DateTime? dailyResetAt = _dailyResetAt;
    if (dailyResetAt != null && !now.isBefore(dailyResetAt)) {
      _dailyUsage = 0;
      _dailyResetAt = _nextUtcMidnight(now);
    }
  }

  DateTime _nextQuarterHour(DateTime now) {
    final DateTime hour = DateTime(now.year, now.month, now.day, now.hour);
    final int nextQuarter = ((now.minute ~/ 15) + 1) * 15;
    return hour.add(Duration(minutes: nextQuarter));
  }

  DateTime _nextUtcMidnight(DateTime now) {
    final DateTime utc = now.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
    ).add(const Duration(days: 1)).toLocal();
  }

  List<int> _pair(String? value) {
    if (value == null) {
      return const <int>[];
    }
    return value
        .split(',')
        .map((String item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList(growable: false);
  }
}

Map<String, Object?> _decodeObject(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  throw const FormatException('Expected a JSON object.');
}

String _randomUrlSafe(int byteCount) {
  final Random random = Random.secure();
  return base64Url
      .encode(List<int>.generate(byteCount, (int _) => random.nextInt(256)))
      .replaceAll('=', '');
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

String? _nullableString(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? null : text;
}
