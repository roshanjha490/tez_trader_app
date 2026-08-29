import 'package:dio/dio.dart';

/// Dedicated Dio client for endpoints that run BEFORE the user is logged in
/// (send OTP, verify OTP, etc). These endpoints:
///   - live directly under the domain root, no `/api` prefix
///   - never need an Authorization header (no token exists yet)
///
/// For anything AFTER login, use [ApiClient] instead (see api_client.dart),
/// which points at `/api` and auto-attaches the JWT + handles refresh.
class AuthApiClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.swissvermont.com', // no /api prefix here
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}