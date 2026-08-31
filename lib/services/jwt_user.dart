import 'package:jwt_decoder/jwt_decoder.dart';

/// Represents the logged-in user, decoded straight from the access token's
/// JWT payload — mirrors how you're already doing it in the Next.js frontend.
///
/// IMPORTANT: this decode is NOT cryptographically verified on-device (nor
/// does it need to be). The signature is checked server-side on every
/// authenticated request; this is purely for reading fields to render in UI.
/// Never trust this class's data for authorization decisions — the backend
/// is always the source of truth for what a token grants.
class UserSession {
  final int id;
  final String firstName;
  final String? lastName;
  final String? email;
  final String mobile;
  final String? profileImage;
  final String? coverImage;
  final String type;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserSession({
    required this.id,
    required this.firstName,
    this.lastName,
    this.email,
    required this.mobile,
    this.profileImage,
    this.coverImage,
    required this.type,
    required this.profileCompleted,
    this.createdAt,
    this.lastLogin,
  });

  /// Reads an int from a payload value that the backend might have encoded
  /// as a real int, a JSON number that decoded as double, or (in some
  /// backends) a numeric string. Previously this class did a hard
  /// `payload['id'] as int`, which throws if the value ever arrives as
  /// anything else — and that thrown exception was being swallowed by
  /// `TokenStorage.getCurrentUser()`'s catch block and (in the old
  /// `AuthGate`) treated as "no session", wiping a perfectly valid refresh
  /// token. Being lenient here avoids that failure mode.
  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory UserSession.fromAccessToken(String accessToken) {
    final payload = JwtDecoder.decode(accessToken);
    return UserSession(
      id: _readInt(payload['id']),
      firstName: (payload['first_name'] as String?) ?? '',
      lastName: payload['last_name'] as String?,
      email: payload['email'] as String?,
      mobile: payload['mobile']?.toString() ?? '',
      profileImage: payload['profile_image'] as String?,
      coverImage: payload['cover_image'] as String?,
      type: (payload['type'] as String?) ?? 'users',
      profileCompleted: (payload['profileCompleted'] as bool?) ?? false,
      createdAt: payload['created_at'] != null
          ? DateTime.tryParse(payload['created_at'].toString())
          : null,
      lastLogin: payload['last_login'] != null
          ? DateTime.tryParse(payload['last_login'].toString())
          : null,
    );
  }
}