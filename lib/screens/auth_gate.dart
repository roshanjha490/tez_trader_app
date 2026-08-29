import 'package:flutter/material.dart';

import '../models/onboarding_data.dart';
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
    final hasSession = await TokenStorage.hasSession();
    if (!mounted) return;

    if (!hasSession) {
      _replaceWith(const LoginScreen());
      return;
    }

    final user = await TokenStorage.getCurrentUser();
    if (!mounted) return;

    if (user == null) {
      // Access token missing/corrupt but a refresh token exists — ApiClient's
      // interceptor will attempt a refresh on the first authenticated call,
      // but we don't have a fresh access token to decode yet, so send the
      // user back to login rather than guessing.
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