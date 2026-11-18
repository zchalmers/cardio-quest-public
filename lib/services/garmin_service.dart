import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../core/fitness_api_config.dart';
import 'fitness_export_models.dart';

/// OAuth 2.0 and activity upload adapter for an approved Garmin partner.
///
/// Garmin does not publish a consumer activity-upload endpoint. Approved
/// Garmin Connect Developer Program partners receive tenant-specific endpoint
/// documentation. This adapter is fully operational once those HTTPS URLs and
/// scopes are supplied through [GarminApiConfig]. It intentionally never calls
/// the unofficial Garmin Connect web endpoints.
class GarminService {
  GarminService({
    GarminApiConfig config = FitnessApiConfig.garmin,
    FlutterSecureStorage? secureStorage,
    http.Client? client,
    DateTime Function()? clock,
  }) : _config = config,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  static const String _tokenKey = 'fitness.garmin.tokens.v1';
  static const String _profileKey = 'fitness.garmin.profile.v1';

  final GarminApiConfig _config;
  final FlutterSecureStorage _secureStorage;
  final http.Client _client;
  final DateTime Function() _clock;

  OAuthTokenSet? _tokens;
  FitnessAccountProfile? _profile;

  bool get isConfigured => _config.isConfigured;
  bool get isConnected => _tokens != null;
  bool get usesTcx => _config.usesTcx;
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
          throw const FormatException('Stored Garmin token is empty.');
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
        'Garmin upload requires approved partner endpoints. Add the Garmin '
        'OAuth and upload URLs issued for your application.',
      );
    }
    final String state = _randomUrlSafe(32);
    final String verifier = _randomUrlSafe(64);
    final String challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final Uri baseAuthorizationUri = Uri.parse(_config.authorizationUrl);
    final Uri authorizationUri = baseAuthorizationUri.replace(
      queryParameters: <String, String>{
        ...baseAuthorizationUri.queryParameters,
        'client_id': _config.clientId,
        'redirect_uri': _config.redirectUri,
        'response_type': 'code',
        'scope': _config.scopes,
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );
    final String callback = await FlutterWebAuth2.authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: Uri.parse(_config.redirectUri).scheme,
    );
    final Uri callbackUri = Uri.parse(callback);
    if (callbackUri.queryParameters['state'] != state) {
      throw const FitnessServiceException(
        'Garmin sign-in could not be verified. Please try again.',
      );
    }
    final String? error = callbackUri.queryParameters['error'];
    if (error != null) {
      throw FitnessServiceException(
        error == 'access_denied'
            ? 'Garmin connection was cancelled.'
            : 'Garmin authorization failed: $error',
      );
    }
    final String? code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const FitnessServiceException(
        'Garmin did not return an authorization code.',
      );
    }
    final Map<String, String> tokenFields = <String, String>{
      'client_id': _config.clientId,
      if (_config.clientSecret.isNotEmpty)
        'client_secret': _config.clientSecret,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': _config.redirectUri,
      'grant_type': 'authorization_code',
    };
    final http.Response response = await _client.post(
      Uri.parse(_config.tokenUrl),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: tokenFields,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FitnessServiceException(
        _apiError(response, fallback: 'Garmin token exchange failed.'),
      );
    }
    _tokens = _tokensFromResponse(_decodeTokenBody(response));
    if (_tokens!.accessToken.isEmpty) {
      throw const FitnessServiceException(
        'Garmin returned an incomplete token response.',
      );
    }
    _profile = await _fetchProfile();
    await _persistCredentials();
    return _profile!;
  }

  Future<void> disconnect() async {
    final OAuthTokenSet? tokens = _tokens;
    if (tokens != null && _config.revocationUrl.isNotEmpty) {
      final Map<String, String> body = <String, String>{
        'token': tokens.refreshToken.isNotEmpty
            ? tokens.refreshToken
            : tokens.accessToken,
        'token_type_hint': tokens.refreshToken.isNotEmpty
            ? 'refresh_token'
            : 'access_token',
        'client_id': _config.clientId,
        if (_config.clientSecret.isNotEmpty)
          'client_secret': _config.clientSecret,
      };
      final http.Response response = await _client.post(
        Uri.parse(_config.revocationUrl),
        headers: const <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FitnessServiceException(
          _apiError(
            response,
            fallback:
                'Garmin could not be disconnected. Check your connection '
                'and try again.',
          ),
        );
      }
    }
    await _clearLocalCredentials();
  }

  Future<FitnessUploadResult> uploadActivity({
    required Uint8List bytes,
    required String fileName,
    required String externalId,
    required String sportType,
    required String dataType,
    String name = 'Cardio Quest',
  }) async {
    if (!isConfigured) {
      return const FitnessUploadResult.failure(
        message:
            'Garmin partner upload endpoints are not configured in this build.',
      );
    }
    try {
      final String accessToken = await _validAccessToken();
      final http.MultipartRequest request =
          http.MultipartRequest('POST', Uri.parse(_config.uploadUrl))
            ..headers['Authorization'] = 'Bearer $accessToken'
            ..headers['Accept'] = 'application/json'
            ..fields.addAll(<String, String>{
              'name': name,
              'external_id': externalId,
              'activity_type': sportType,
              'data_type': dataType,
            })
            ..files.add(
              http.MultipartFile.fromBytes(
                _config.uploadFileField,
                bytes,
                filename: fileName,
              ),
            );
      final http.StreamedResponse streamed = await _client.send(request);
      final http.Response response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401) {
        return const FitnessUploadResult.failure(
          message: 'Garmin authorization expired. Reconnect Garmin.',
          authenticationRequired: true,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return FitnessUploadResult.failure(
          message: _apiError(
            response,
            fallback: 'Garmin rejected the workout upload.',
          ),
          retryAt: response.statusCode == 429 || response.statusCode >= 500
              ? _retryAt(response)
              : null,
        );
      }

      final Map<String, Object?> body = response.body.trim().isEmpty
          ? const <String, Object?>{}
          : _decodeObject(response.body);
      final String remoteId =
          _firstString(body, const <String>[
            'activity_id',
            'activityId',
            'upload_id',
            'uploadId',
            'id',
          ]) ??
          externalId;
      if (response.statusCode == 202 &&
          _config.uploadStatusUrlTemplate.isNotEmpty) {
        return FitnessUploadResult.processing(
          remoteId: remoteId,
          message: 'Garmin accepted the workout and is processing it.',
          retryAt: _clock().add(const Duration(seconds: 15)),
        );
      }
      return FitnessUploadResult.success(
        remoteId: remoteId,
        message: 'Uploaded to Garmin',
      );
    } on FitnessServiceException catch (error) {
      return FitnessUploadResult.failure(
        message: error.message,
        retryAt: error.retryAt,
        authenticationRequired: error.authenticationRequired,
      );
    } on Object {
      return const FitnessUploadResult.failure(
        message: 'Garmin is unreachable. The workout is queued for retry.',
      );
    }
  }

  Future<FitnessUploadResult> checkUpload(String uploadId) async {
    if (_config.uploadStatusUrlTemplate.isEmpty) {
      return FitnessUploadResult.success(
        remoteId: uploadId,
        message: 'Garmin accepted the workout.',
      );
    }
    try {
      final String accessToken = await _validAccessToken();
      final String url = _config.uploadStatusUrlTemplate.replaceAll(
        '{id}',
        Uri.encodeComponent(uploadId),
      );
      final http.Response response = await _client.get(
        Uri.parse(url),
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return FitnessUploadResult.failure(
          message: _apiError(
            response,
            fallback: 'Could not check the Garmin upload.',
          ),
          retryAt: response.statusCode == 429 || response.statusCode >= 500
              ? _retryAt(response)
              : null,
          authenticationRequired: response.statusCode == 401,
        );
      }
      final Map<String, Object?> body = _decodeObject(response.body);
      final String status =
          _firstString(body, const <String>[
            'status',
            'state',
          ])?.toLowerCase() ??
          '';
      final String? error = _firstString(body, const <String>[
        'error',
        'error_description',
        'message',
      ]);
      if (status == 'failed' || status == 'error') {
        return FitnessUploadResult.failure(
          message: error ?? 'Garmin could not process the workout.',
        );
      }
      if (<String>{
        'complete',
        'completed',
        'ready',
        'success',
      }.contains(status)) {
        return FitnessUploadResult.success(
          remoteId:
              _firstString(body, const <String>[
                'activity_id',
                'activityId',
                'id',
              ]) ??
              uploadId,
          message: 'Uploaded to Garmin',
        );
      }
      return FitnessUploadResult.processing(
        remoteId: uploadId,
        message: 'Garmin is processing the workout.',
        retryAt: _clock().add(const Duration(seconds: 15)),
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
        message: 'Garmin status check will retry when online.',
        retryAt: _clock().add(const Duration(minutes: 1)),
      );
    }
  }

  Future<String> _validAccessToken() async {
    OAuthTokenSet? tokens = _tokens;
    if (tokens == null) {
      throw const FitnessServiceException(
        'Connect Garmin before sharing workouts.',
        authenticationRequired: true,
      );
    }
    if (!tokens.expiresWithin(const Duration(minutes: 5), now: _clock())) {
      return tokens.accessToken;
    }
    if (tokens.refreshToken.isEmpty) {
      throw const FitnessServiceException(
        'Garmin authorization expired. Reconnect Garmin.',
        authenticationRequired: true,
      );
    }
    final http.Response response = await _client.post(
      Uri.parse(_config.tokenUrl),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'client_id': _config.clientId,
        if (_config.clientSecret.isNotEmpty)
          'client_secret': _config.clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': tokens.refreshToken,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 400 || response.statusCode == 401) {
        throw const FitnessServiceException(
          'Garmin authorization expired. Reconnect Garmin.',
          authenticationRequired: true,
        );
      }
      throw FitnessServiceException(
        _apiError(response, fallback: 'Garmin token refresh failed.'),
      );
    }
    final Map<String, Object?> body = _decodeTokenBody(response);
    final OAuthTokenSet refreshed = _tokensFromResponse(body);
    if (refreshed.refreshToken.isEmpty) {
      tokens = OAuthTokenSet(
        accessToken: refreshed.accessToken,
        refreshToken: tokens.refreshToken,
        expiresAt: refreshed.expiresAt,
        scope: refreshed.scope.isEmpty ? tokens.scope : refreshed.scope,
        tokenType: refreshed.tokenType,
      );
    } else {
      tokens = refreshed;
    }
    _tokens = tokens;
    await _persistCredentials();
    return tokens.accessToken;
  }

  Future<FitnessAccountProfile> _fetchProfile() async {
    if (_config.profileUrl.isEmpty) {
      return const FitnessAccountProfile(id: '', displayName: 'Garmin account');
    }
    try {
      final http.Response response = await _client.get(
        Uri.parse(_config.profileUrl),
        headers: <String, String>{
          'Authorization': 'Bearer ${_tokens!.accessToken}',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const FitnessAccountProfile(
          id: '',
          displayName: 'Garmin account',
        );
      }
      final Map<String, Object?> body = _decodeObject(response.body);
      return FitnessAccountProfile(
        id: _firstString(body, const <String>['user_id', 'userId', 'id']) ?? '',
        displayName:
            _firstString(body, const <String>[
              'display_name',
              'displayName',
              'full_name',
              'fullName',
              'name',
              'username',
            ]) ??
            'Garmin account',
        avatarUrl: _firstString(body, const <String>[
          'avatar_url',
          'avatarUrl',
          'profile_image_url',
        ]),
      );
    } on Object {
      return const FitnessAccountProfile(id: '', displayName: 'Garmin account');
    }
  }

  OAuthTokenSet _tokensFromResponse(Map<String, Object?> body) {
    final int expiresIn = _asInt(body['expires_in']);
    return OAuthTokenSet(
      accessToken: body['access_token']?.toString() ?? '',
      refreshToken: body['refresh_token']?.toString() ?? '',
      expiresAt: _clock().toUtc().add(
        Duration(seconds: expiresIn > 0 ? expiresIn : 3600),
      ),
      scope: body['scope']?.toString() ?? _config.scopes,
      tokenType: body['token_type']?.toString() ?? 'Bearer',
    );
  }

  Map<String, Object?> _decodeTokenBody(http.Response response) {
    if (response.body.trimLeft().startsWith('{')) {
      return _decodeObject(response.body);
    }
    return Uri.splitQueryString(response.body).map<String, Object?>(
      (String key, String value) => MapEntry<String, Object?>(key, value),
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

  DateTime _retryAt(http.Response response) {
    final int? retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    return _clock().add(
      Duration(seconds: retryAfter ?? (response.statusCode == 429 ? 900 : 120)),
    );
  }

  String _apiError(http.Response response, {required String fallback}) {
    try {
      final Map<String, Object?> body = _decodeObject(response.body);
      return _firstString(body, const <String>[
            'error_description',
            'message',
            'error',
          ]) ??
          '$fallback (HTTP ${response.statusCode})';
    } on Object {
      return '$fallback (HTTP ${response.statusCode})';
    }
  }

  void dispose() {
    _client.close();
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

String? _firstString(Map<String, Object?> source, List<String> keys) {
  for (final String key in keys) {
    final String value = source[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return null;
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
