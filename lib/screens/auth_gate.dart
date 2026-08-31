import 'package:flutter/material.dart';

import '../models/onboarding_data.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import 'main_shell.dart';
import 'auth/login_screen.dart';
import 'onboarding/personal_details_screen.dart';

/// Runs once when the app launches. Checks for a stored session and routes
/// straight to the right screen, so returning users skip the login screen
/// entirely instead of re-entering their phone number every time.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (!mounted) return;

    if (refreshToken == null) {
      // No session was ever stored (or it was already cleared) — straight
      // to login, nothing to refresh.
      _replaceWith(const LoginScreen());
      return;
    }
final refreshed = await ApiClient.forceRefresh();
    if (!mounted) return;

    if (!refreshed) {
      // The refresh token itself was rejected (expired/revoked) or the
      // request failed outright. Only NOW is it safe to clear tokens —
      // we know for certain the session is actually dead rather than
      // guessing from a decode error.
      await TokenStorage.clearTokens();
      _replaceWith(const LoginScreen());
      return;
    }

    final user = await TokenStorage.getCurrentUser();
    if (!mounted) return;

    if (user == null) {

      // We just successfully refreshed, so this really shouldn't happen —
      // but if the freshly-saved access token still fails to decode for
      // some reason, don't silently proceed with a null user either.
      await TokenStorage.clearTokens();
      _replaceWith(const LoginScreen());
      return;
    }

    if (user.profileCompleted) {
      _replaceWith(const MainShell());
    } else {
      _replaceWith(
        PersonalDetailsScreen(
          data: OnboardingData(
            firstName: user.firstName,
            lastName: user.lastName ?? '',
            email: user.email ?? '',
          ),
        ),
      );
    }
  }

  void _replaceWith(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0E0E1A),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      ),
    );
  }
}