import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../services/api_client.dart';
import '../../services/token_storage.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/selectable_tile.dart';
import '../main_shell.dart';

class ExperienceConfirmationScreen extends StatefulWidget {
  final OnboardingData data;

  const ExperienceConfirmationScreen({super.key, required this.data});

  @override
  State<ExperienceConfirmationScreen> createState() => _ExperienceConfirmationScreenState();
}

class _ExperienceConfirmationScreenState extends State<ExperienceConfirmationScreen> {
  static const _experienceOptions = [
    'No Experience',
    'Less than 1 year',
    '1 - 5 years',
    'Above 5 years',
  ];

  String? _tradingExperience;
  bool _confirmAccurate = false;
  bool _agreeTerms = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tradingExperience = widget.data.tradingExperience;
    _confirmAccurate = widget.data.confirmAccurate;
    _agreeTerms = widget.data.agreeTerms;
  }

  bool get _isValid =>
      _tradingExperience != null &&
      _confirmAccurate &&
      _agreeTerms;

  Future<void> _handleProceed() async {
    if (!_isValid || _isSubmitting) return;

    widget.data
      ..tradingExperience = _tradingExperience
      ..confirmAccurate = _confirmAccurate
      ..agreeTerms = _agreeTerms;

    setState(() => _isSubmitting = true);

    try {
      // NOTE: confirm this route with your backend — guessed to match your
      // authenticated (/api-prefixed) routes. ApiClient's interceptor will
      // attach the Authorization header automatically.
      final response = await ApiClient.dio.post(
        '/user/completeProfile',
        data: widget.data.toCompleteProfilePayload(),
      );

      if (!mounted) return;

      final responseData = response.data as Map;
      if (responseData['success'] == true) {
        // completeProfile's backend response key is "token", not
        // "accessToken" like verifyOTP — mapped here to keep TokenStorage's
        // API consistent. refreshToken is untouched (backend doesn't
        // return one here, and it doesn't need to change).
        await TokenStorage.saveTokens(accessToken: responseData['token'] as String);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      } else {
        _showError(responseData['message']?.toString() ?? 'Something went wrong. Please try again.');
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final message = responseData is Map
          ? (responseData['message'] ?? 'Something went wrong. Please try again.')
          : 'Something went wrong. Please try again.';
      _showError(message.toString());
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              side: const BorderSide(color: Colors.white38),
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Color(0xFF6C63FF)
                    : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      currentStep: 2,
      title: 'Experience & Confirmation',
      subtitle: 'Final details to complete your profile setup.',
      nextEnabled: _isValid,
      isNextLoading: _isSubmitting,
      nextLabel: 'Proceed',
      onNext: _handleProceed,
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trading Experience', style: TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _experienceOptions
                .map((o) => SelectableTile(
                      label: o,
                      selected: _tradingExperience == o,
                      onTap: () => setState(() => _tradingExperience = o),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                _buildCheckbox(
                  value: _confirmAccurate,
                  onChanged: (v) => setState(() => _confirmAccurate = v ?? false),
                  label: const Text(
                    'I confirm that all the details provided above are accurate and complete.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
                _buildCheckbox(
                  value: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                  label: const Text(
                    'I agree to the Terms of Service and Privacy Policy for creating my account.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}