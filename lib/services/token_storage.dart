import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'jwt_user.dart';

/// Persists access/refresh tokens in the platform keychain/keystore
/// (Keychain on iOS, EncryptedSharedPreferences/Keystore on Android) —
/// deliberately NOT shared_preferences, since these are sensitive secrets.
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  /// Save tokens after login (verifyOTP) or after a refresh.
  /// [refreshToken] is optional because the refresh endpoint only returns
  /// a new accessToken — it doesn't rotate the refreshToken.
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  static Future<bool> hasSession() async {
    final token = await getRefreshToken();
    return token != null;
  }

  /// Decodes the CURRENT access token into a [UserSession]. No separate
  /// "profile" storage needed — user fields live inside the JWT itself and
  /// stay fresh automatically each time a new access token is issued.
  static Future<UserSession?> getCurrentUser() async {
    final token = await getAccessToken();
    if (token == null) return null;
    try {
      return UserSession.fromAccessToken(token);
    } catch (_) {
      return null;
    }
  }
}