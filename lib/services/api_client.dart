import 'package:dio/dio.dart';

import 'auth_api_client.dart';
import 'token_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ApiClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.swissvermont.com/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
                final refreshed = await _refreshToken();
                
                if (refreshed) {
                  // Fetch the shiny new token we just saved
                  token = await TokenStorage.getAccessToken(); 
                } else {
                  // Refresh failed (e.g., refresh token is also dead)
                  await TokenStorage.clearTokens();
                  token = null; 
                }
              }
            } catch (e) {
              await TokenStorage.clearTokens();
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

            final refreshed = await _refreshToken();


            if (refreshed) {
              final newToken = await TokenStorage.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } else {
              await TokenStorage.clearTokens();
            }

          }
          handler.next(error);
        },
      ),
    );
  }

  static Future<bool> _refreshToken() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await AuthApiClient.dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.data['success'] != true) return false;

      await TokenStorage.saveTokens(
        accessToken: response.data['accessToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}