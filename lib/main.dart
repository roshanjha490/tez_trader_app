import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'screens/auth_gate.dart';

void main() {
  ApiClient.init(); // attaches the auth header + 401 refresh interceptor
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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