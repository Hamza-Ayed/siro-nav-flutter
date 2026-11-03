import '../models/nav_config.dart';

/// Result of an API Key validation attempt.
class AuthResult {
  final bool isValid;
  final String? tenantId;
  final String? planName;
  final String? errorCode;
  final String? errorMessage;

  const AuthResult({
    required this.isValid,
    this.tenantId,
    this.planName,
    this.errorCode,
    this.errorMessage,
  });

  factory AuthResult.success({String? tenantId, String? planName}) {
    return AuthResult(
      isValid: true,
      tenantId: tenantId,
      planName: planName,
    );
  }

  factory AuthResult.failure(String code, String message) {
    return AuthResult(
      isValid: false,
      errorCode: code,
      errorMessage: message,
    );
  }
}

/// Gating and licensing controller for Siro Navigation SDK.
///
/// The key is checked locally for shape only (present, no spaces). Subscription
/// status and quota are enforced by the server on every routing request: a
/// revoked, inactive or exhausted key gets HTTP 401/403 from `/api/maps/route`,
/// which the SDK turns into an error. There is no separate verification endpoint.
class ApiKeyValidator {
  final NavConfig config;

  ApiKeyValidator({required this.config});

  Future<AuthResult> validate() async {
    final key = config.apiKey.trim();

    if (key.isEmpty) {
      return AuthResult.failure(
        'ERR_MISSING_API_KEY',
        'Siro Navigation SDK requires a valid API key.',
      );
    }

    // Keys are opaque tokens issued by the server (for example `in_mob_…`), so
    // only the shape is checked here. Which keys are valid is the server's call.
    if (RegExp(r'\s').hasMatch(key)) {
      return AuthResult.failure(
        'ERR_INVALID_API_KEY_FORMAT',
        'Invalid API key format. A key must not contain spaces.',
      );
    }

    return AuthResult.success(planName: 'pending_server_check');
  }

  void dispose() {}
}
