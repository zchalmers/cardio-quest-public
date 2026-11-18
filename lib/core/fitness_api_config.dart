/// Compile-time API configuration for fitness platform integrations.
///
/// Native app binaries cannot keep a client secret truly secret. For a
/// production multi-user deployment, point the token exchange at your backend
/// and keep provider secrets there. Direct exchange is supported here for
/// development and single-user builds because both requested providers issue
/// integrations with different deployment requirements.
///
/// Example:
/// flutter run \
///   --dart-define=STRAVA_CLIENT_ID=12345 \
///   --dart-define=STRAVA_CLIENT_SECRET=secret \
///   --dart-define=STRAVA_REDIRECT_URI=cardioquest://oauth/strava
abstract final class FitnessApiConfig {
  static const String callbackScheme = 'cardioquest';

  static const StravaApiConfig strava = StravaApiConfig(
    clientId: String.fromEnvironment('STRAVA_CLIENT_ID'),
    clientSecret: String.fromEnvironment('STRAVA_CLIENT_SECRET'),
    redirectUri: String.fromEnvironment(
      'STRAVA_REDIRECT_URI',
      defaultValue: 'cardioquest://cardioquest.app/oauth/strava',
    ),
  );

  /// Garmin Connect activity ingestion is only exposed to approved partners.
  /// Garmin supplies the OAuth and upload endpoints after approval; provide
  /// those issued URLs with --dart-define. Garmin's public Health and Activity
  /// APIs read data synced from Garmin devices and are not consumer upload
  /// endpoints. Connect IQ records FIT files on Garmin hardware, so it also
  /// cannot upload a phone-generated Cardio Quest workout.
  static const GarminApiConfig garmin = GarminApiConfig(
    clientId: String.fromEnvironment('GARMIN_CLIENT_ID'),
    clientSecret: String.fromEnvironment('GARMIN_CLIENT_SECRET'),
    redirectUri: String.fromEnvironment(
      'GARMIN_REDIRECT_URI',
      defaultValue: 'cardioquest://cardioquest.app/oauth/garmin',
    ),
    authorizationUrl: String.fromEnvironment('GARMIN_AUTHORIZATION_URL'),
    tokenUrl: String.fromEnvironment('GARMIN_TOKEN_URL'),
    revocationUrl: String.fromEnvironment('GARMIN_REVOCATION_URL'),
    profileUrl: String.fromEnvironment('GARMIN_PROFILE_URL'),
    uploadUrl: String.fromEnvironment('GARMIN_UPLOAD_URL'),
    uploadStatusUrlTemplate: String.fromEnvironment('GARMIN_UPLOAD_STATUS_URL'),
    scopes: String.fromEnvironment(
      'GARMIN_SCOPES',
      defaultValue: 'activity:write profile:read',
    ),
    uploadFormat: String.fromEnvironment(
      'GARMIN_UPLOAD_FORMAT',
      defaultValue: 'fit',
    ),
    uploadFileField: String.fromEnvironment(
      'GARMIN_UPLOAD_FILE_FIELD',
      defaultValue: 'file',
    ),
  );
}

class StravaApiConfig {
  const StravaApiConfig({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });

  final String clientId;
  final String clientSecret;
  final String redirectUri;

  bool get isConfigured =>
      clientId.trim().isNotEmpty &&
      clientSecret.trim().isNotEmpty &&
      Uri.tryParse(redirectUri)?.hasScheme == true;
}

class GarminApiConfig {
  const GarminApiConfig({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    required this.authorizationUrl,
    required this.tokenUrl,
    required this.revocationUrl,
    required this.profileUrl,
    required this.uploadUrl,
    required this.uploadStatusUrlTemplate,
    required this.scopes,
    required this.uploadFormat,
    required this.uploadFileField,
  });

  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String authorizationUrl;
  final String tokenUrl;
  final String revocationUrl;
  final String profileUrl;
  final String uploadUrl;
  final String uploadStatusUrlTemplate;
  final String scopes;
  final String uploadFormat;
  final String uploadFileField;

  bool get isConfigured =>
      clientId.trim().isNotEmpty &&
      Uri.tryParse(redirectUri)?.hasScheme == true &&
      _isHttps(authorizationUrl) &&
      _isHttps(tokenUrl) &&
      _isHttps(uploadUrl);

  bool get usesTcx => uploadFormat.toLowerCase() == 'tcx';

  bool _isHttps(String value) {
    final Uri? uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.hasAuthority;
  }
}
