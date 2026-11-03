import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/app_navigation.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth_gate.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() {
  ApiClient.init(); // attaches the auth header + 401 refresh interceptor
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  /// The server ended the session mid-use (token revoked, login on another
  /// device, blocked account): drop everything and go back to login.
  void _onSessionExpired() {
    final event = sessionExpired.value;
    if (event == null) return;
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(notice: event.message)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Teztrader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0E1A),
      ),
      // AuthGate checks for a stored session on launch and routes straight
      // to Login / Onboarding / Dashboard, instead of always starting at
      // LoginScreen.
      home: const AuthGate(),
    );
  }
}