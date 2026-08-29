import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/selectable_tile.dart';
import 'experience_confirmation_screen.dart';

class FinancialProfileScreen extends StatefulWidget {
  final OnboardingData data;

  const FinancialProfileScreen({super.key, required this.data});

  @override
  State<FinancialProfileScreen> createState() => _FinancialProfileScreenState();
}

class _FinancialProfileScreenState extends State<FinancialProfileScreen> {
  static const _occupations = [
    'Private Sector',
    'Public Sector',
    'Business',
    'Government',
    'Student',
    'Farmer',
    'Professional',
    'Retired',
    'Housewife',
  ];

  static const _tradingStyles = [
    'Scalping',
    'Intraday',
    'Positional',
    'Swing'
  ];

  String? _occupation;
  String? _tradingStyle;

  @override
  void initState() {
    super.initState();
    _occupation = widget.data.occupation;
    _tradingStyle = widget.data.tradingStyle;
  }

  bool get _isValid => _occupation != null && _tradingStyle != null;

  void _handleNext() {
    if (!_isValid) return;
    widget.data
      ..occupation = _occupation
      ..tradingStyle = _tradingStyle;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExperienceConfirmationScreen(data: widget.data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      currentStep: 1,
      title: 'Financial Profile',
      subtitle: 'Help us understand your financial background.',
      nextEnabled: _isValid,
      onNext: _handleNext,
      onBack: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Occupation', style: TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _occupations
                .map((o) => SelectableTile(
                      label: o,
                      selected: _occupation == o,
                      onTap: () => setState(() => _occupation = o),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text('Trading Style', style: TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _tradingStyles
                .map((band) => SelectableTile(
                      label: band,
                      selected: _tradingStyle == band,
                      onTap: () => setState(() => _tradingStyle = band),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}