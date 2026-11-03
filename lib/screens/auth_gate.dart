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

  bool _offline = false;

  Future<void> _decide() async {
    if (_offline) setState(() => _offline = false);

    final refreshToken = await TokenStorage.getRefreshToken();
    if (!mounted) return;

    if (refreshToken == null) {
      // No session was ever stored (or it was already cleared) — straight
      // to login, nothing to refresh.
      _replaceWith(const LoginScreen());
      return;
    }

    final outcome = await ApiClient.refreshSession();
    if (!mounted) return;

    if (outcome == RefreshOutcome.rejected) {
      // The server rejected the refresh token (expired, revoked by a login
      // on another device, or the account was blocked). refreshSession has
      // already cleared the tokens; sessionExpired is handled by MyApp, so
      // just show the login screen here.
      _replaceWith(const LoginScreen());
      return;
    }

    if (outcome == RefreshOutcome.unreachable) {
      // Offline or the server is down: we can't tell whether the session is
      // still good, so keep it and let the user retry rather than logging
      // them out.
      setState(() => _offline = true);
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
      // MainShell no longer has a const constructor — its default key
      // comes from a global GlobalKey variable (see main_shell.dart),
      // which isn't a compile-time constant.
      _replaceWith(MainShell());
    } else {
      // New accounts are created with the placeholder first name "User";
      // don't prefill that into the onboarding form.
      final firstName = user.firstName == 'User' ? '' : user.firstName;
      _replaceWith(
        PersonalDetailsScreen(
          data: OnboardingData(
            firstName: firstName,
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
    if (_offline) {
      return Scaffold(
        backgroundColor: const Color(0xFF0E0E1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
              const SizedBox(height: 16),
              const Text(
                "Can't reach Teztrader",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _decide, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return const Scaffold(
      backgroundColor: Color(0xFF0E0E1A),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      ),
    );
  }
}