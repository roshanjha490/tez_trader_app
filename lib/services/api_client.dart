import 'package:dio/dio.dart';

import 'app_navigation.dart';
import 'auth_api_client.dart';
import 'token_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// How a refresh attempt ended. [rejected] means the server said the session
/// is dead (expired, revoked by a login on another device, or the user is
/// blocked); [unreachable] means we couldn't tell (offline, timeout, 5xx), so
/// the stored session must be kept.
enum RefreshOutcome { refreshed, rejected, unreachable }

class ApiClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.teztrader.com/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Origin': apiOrigin},
    ),
  );

  static void init() {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {

          String? token = await TokenStorage.getAccessToken();

          if (token != null) {
            try {
              final expirationDate = JwtDecoder.getExpirationDate(token);
              final timeUntilExpiration = expirationDate.difference(DateTime.now());

              // If it's expired, or expiring in the next 10 seconds, refresh it now!
              if (timeUntilExpiration.inSeconds < 10) {
                final outcome = await refreshSession();

                if (outcome == RefreshOutcome.refreshed) {
                  // Fetch the shiny new token we just saved
                  token = await TokenStorage.getAccessToken();
                } else if (outcome == RefreshOutcome.rejected) {
                  // Refresh token is dead; refreshSession already cleared
                  // the session and told the app to go back to login.
                  token = null;
                }
                // unreachable: keep the old token and let the request run.
              }
            } catch (e) {
              // Undecodable access token: drop it, the request goes out
              // unauthenticated and the 401 path below will refresh.
              token = null;
            }
          }

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          handler.next(options);

        },
        onError: (DioException error, handler) async {
          // If access token expired (401), try refreshing once
          if (error.response?.statusCode == 401) {

            final failedToken = error.requestOptions.headers['Authorization']?.replaceAll('Bearer ', '');

            final currentToken = await TokenStorage.getAccessToken();

            if (failedToken != currentToken && currentToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $currentToken';
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }

            final refreshed = await forceRefresh();

            if (refreshed) {
              final newToken = await TokenStorage.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }

          }
          handler.next(error);
        },
      ),
    );
  }

  static Future<bool> forceRefresh() async =>
      await refreshSession() == RefreshOutcome.refreshed;

  /// Exchanges the stored refresh token for a new access token. The refresh
  /// token is bound to this device ('mobile' platform) on the server, so a
  /// login elsewhere on mobile makes it come back 403 "Session revoked".
  static Future<RefreshOutcome> refreshSession() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) return RefreshOutcome.rejected;

    try {
      final response = await AuthApiClient.dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final accessToken = response.data['accessToken'];
      if (response.data['success'] != true || accessToken is! String) {
        return RefreshOutcome.unreachable;
      }

      await TokenStorage.saveTokens(accessToken: accessToken);
      return RefreshOutcome.refreshed;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        final data = e.response?.data;
        await endSession(data is Map ? data['message']?.toString() : null);
        return RefreshOutcome.rejected;
      }
      return RefreshOutcome.unreachable;
    } catch (_) {
      return RefreshOutcome.unreachable;
    }
  }

  /// Clears the stored session and tells the app to return to the login
  /// screen (see [sessionExpired] in app_navigation.dart).
  static Future<void> endSession([String? message]) async {
    await TokenStorage.clearTokens();
    notifySessionExpired(message);
  }
}
