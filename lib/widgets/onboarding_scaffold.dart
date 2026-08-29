import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../screens/auth/login_screen.dart';

/// Shared chrome for the 3-step onboarding wizard (Personal Details,
/// Financial Profile, Experience & Confirmation). Adapted from the
/// design mockups to a full-width mobile layout, matching the style of
/// login_screen.dart / otp_screen.dart rather than a floating desktop card.
class OnboardingScaffold extends StatelessWidget {
  static const int totalSteps = 3;

  final int currentStep; // 0, 1, or 2
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool nextEnabled;
  final bool isNextLoading;

  const OnboardingScaffold({
    super.key,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    required this.onNext,
    this.nextLabel = 'Next',
    required this.nextEnabled,
    this.isNextLoading = false,
  });

  Future<void> _handleLogout(BuildContext context) async {
    await TokenStorage.clearTokens();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = nextEnabled && !isNextLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.6, -0.7),
            radius: 1.4,
            colors: [
              Color(0xFF2A2450),
              Color(0xFF141225),
              Color(0xFF0A0A12),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout, size: 16, color: Colors.white70),
                    label: const Text('Logout', style: TextStyle(color: Colors.white70)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _StepDots(currentStep: currentStep, totalSteps: totalSteps),
                const SizedBox(height: 30),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 30),
                Expanded(child: SingleChildScrollView(child: child)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (onBack != null) ...[
                      Expanded(child: _BackButton(onTap: onBack!)),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      flex: onBack != null ? 2 : 1,
                      child: _NextButton(
                        label: nextLabel,
                        enabled: canSubmit,
                        loading: isNextLoading,
                        onTap: nextEnabled ? onNext : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepDots({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final dots = <Widget>[];
    for (var i = 0; i < totalSteps; i++) {
      final reached = i <= currentStep;
      dots.add(
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? Colors.white : Colors.white24,
          ),
        ),
      );
      if (i != totalSteps - 1) {
        dots.add(
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: i < currentStep ? Colors.white : Colors.white24,
            ),
          ),
        );
      }
    }
    return Row(children: dots);
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Back',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  const _NextButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: enabled
            ? const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFF0917C)],
              )
            : null,
        color: enabled ? null : Colors.white.withOpacity(0.06),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: enabled ? Colors.white : Colors.white38,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}