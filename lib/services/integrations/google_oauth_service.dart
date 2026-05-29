import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// Google OAuth2 service for installed apps.
///
/// Implements the OAuth2 flow for installed applications using
/// Gmail client ID and secret from [ApiKeys].
/// Supports token persistence via [StorageService].
class GoogleOauthService {
  GoogleOauthService({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _tokenKey = 'google_oauth_token';
  static const _scopes = [
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
    'openid',
    'email',
    'profile',
  ];

  // Google OAuth endpoints
  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';

  // ── Public API ──

  /// Initiates the OAuth2 authentication flow.
  ///
  /// Returns the authorization URL that should be opened in a browser.
  /// After the user grants access, the authorization code is exchanged
  /// for tokens via [handleAuthCode].
  Future<AuthResult> authenticate() async {
    _ensureConfigured();

    final state = _generateState();
    final redirectUri = _getRedirectUri();

    final authUrl = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': ApiKeys.gmailClientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
    });

    return AuthResult(
      authUrl: authUrl.toString(),
      state: state,
      redirectUri: redirectUri,
    );
  }

  /// Handles the authorization code returned from the OAuth flow.
  ///
  /// Exchanges the code for access and refresh tokens,
  /// then persists them locally.
  Future<TokenInfo> handleAuthCode(String code, String state) async {
    _ensureConfigured();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenEndpoint,
        data: {
          'client_id': ApiKeys.gmailClientId,
          'client_secret': ApiKeys.gmailClientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': _getRedirectUri(),
        },
        options: Options(headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
      );

      final data = response.data!;
      final tokenInfo = _parseTokenResponse(data);

      // Persist tokens
      await _saveTokenInfo(tokenInfo);

      return tokenInfo;
    } on DioException catch (e) {
      throw OAuthException('Auth code exchange failed: ${e.message}');
    }
  }

  /// Gets the current access token, refreshing if necessary.
  ///
  /// Returns null if not authenticated.
  Future<String?> getAccessToken() async {
    final tokenInfo = _loadTokenInfo();
    if (tokenInfo == null) return null;

    // Check if token is still valid (with 5-minute buffer)
    final expiry = tokenInfo.expiryTime;
    if (DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 5)))) {
      return tokenInfo.accessToken;
    }

    // Try to refresh
    final refreshed = await refreshToken();
    return refreshed?.accessToken;
  }

  /// Refreshes the access token using the stored refresh token.
  ///
  /// Returns updated token info, or null if refresh fails.
  Future<TokenInfo?> refreshToken() async {
    final tokenInfo = _loadTokenInfo();
    if (tokenInfo == null || tokenInfo.refreshToken == null) return null;

    _ensureConfigured();

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenEndpoint,
        data: {
          'client_id': ApiKeys.gmailClientId,
          'client_secret': ApiKeys.gmailClientSecret,
          'refresh_token': tokenInfo.refreshToken,
          'grant_type': 'refresh_token',
        },
        options: Options(headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
      );

      final data = response.data!;
      final newTokenInfo = _parseTokenResponse(data, existingRefreshToken: tokenInfo.refreshToken);

      await _saveTokenInfo(newTokenInfo);
      return newTokenInfo;
    } on DioException catch (e) {
      throw OAuthException('Token refresh failed: ${e.message}');
    }
  }

  /// Checks if the user is currently authenticated.
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// Revokes authentication and clears stored tokens.
  Future<void> revokeAuth() async {
    final tokenInfo = _loadTokenInfo();

    if (tokenInfo != null) {
      try {
        await _dio.post<Map<String, dynamic>>(
          'https://oauth2.googleapis.com/revoke',
          data: {'token': tokenInfo.accessToken},
          options: Options(headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          }),
        );
      } catch (_) {
        // Revocation failed, but we still clear local tokens
      }
    }

    await _storage.delete(_tokenKey);
  }

  /// Gets the authenticated user's email and profile info.
  Future<UserProfile?> getUserProfile() async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://www.googleapis.com/oauth2/v2/userinfo',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final data = response.data!;
      return UserProfile(
        email: data['email'] as String? ?? '',
        name: data['name'] as String? ?? '',
        givenName: data['given_name'] as String? ?? '',
        familyName: data['family_name'] as String? ?? '',
        pictureUrl: data['picture'] as String? ?? '',
        locale: data['locale'] as String? ?? 'en',
      );
    } on DioException catch (_) {
      return null;
    }
  }

  // ── Private helpers ──

  void _ensureConfigured() {
    if (!ApiKeys.hasGmail) {
      throw OAuthException('Gmail OAuth not configured. Set GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET.');
    }
  }

  String _generateState() {
    // Generate a random state string for CSRF protection
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'owj_${timestamp}_${timestamp.hashCode.abs()}';
  }

  String _getRedirectUri() {
    // For installed apps, use the loopback redirect
    return 'http://127.0.0.1:8080';
    // Alternative: use urn:ietf:wg:oauth:2.0:oob for copy-paste flow
  }

  TokenInfo _parseTokenResponse(Map<String, dynamic> data, {String? existingRefreshToken}) {
    final expiresIn = data['expires_in'] as int? ?? 3600;
    return TokenInfo(
      accessToken: data['access_token'] as String? ?? '',
      refreshToken: data['refresh_token'] as String? ?? existingRefreshToken,
      tokenType: data['token_type'] as String? ?? 'Bearer',
      scope: data['scope'] as String? ?? _scopes.join(' '),
      expiryTime: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<void> _saveTokenInfo(TokenInfo tokenInfo) async {
    await _storage.setJson(_tokenKey, {
      'accessToken': tokenInfo.accessToken,
      'refreshToken': tokenInfo.refreshToken,
      'tokenType': tokenInfo.tokenType,
      'scope': tokenInfo.scope,
      'expiryTime': tokenInfo.expiryTime.toIso8601String(),
    });
  }

  TokenInfo? _loadTokenInfo() {
    final json = _storage.getJson(_tokenKey);
    if (json == null) return null;

    return TokenInfo(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      scope: json['scope'] as String? ?? '',
      expiryTime: DateTime.tryParse(json['expiryTime'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ── Data models ──

class AuthResult {
  final String authUrl;
  final String state;
  final String redirectUri;

  const AuthResult({
    required this.authUrl,
    required this.state,
    required this.redirectUri,
  });
}

class TokenInfo {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final String scope;
  final DateTime expiryTime;

  const TokenInfo({
    required this.accessToken,
    this.refreshToken,
    required this.tokenType,
    required this.scope,
    required this.expiryTime,
  });

  bool get isExpired => DateTime.now().isAfter(expiryTime);
  bool get hasRefreshToken => refreshToken != null && refreshToken!.isNotEmpty;
}

class UserProfile {
  final String email;
  final String name;
  final String givenName;
  final String familyName;
  final String pictureUrl;
  final String locale;

  const UserProfile({
    required this.email,
    required this.name,
    required this.givenName,
    required this.familyName,
    required this.pictureUrl,
    required this.locale,
  });
}

class OAuthException implements Exception {
  final String message;
  OAuthException(this.message);
  @override
  String toString() => 'OAuthException: $message';
}
