import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  AuthState(this.status);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(AuthStatus.unknown)) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await TokenStorage.getAccessToken();
    state = AuthState(token != null ? AuthStatus.authenticated : AuthStatus.unauthenticated);
  }

  Future<void> login(String accessToken, String refreshToken) async {
    await TokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    state = AuthState(AuthStatus.authenticated);
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    state = AuthState(AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());