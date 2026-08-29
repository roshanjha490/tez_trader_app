import 'package:flutter/material.dart';

import '../../models/onboarding_data.dart';
import '../../widgets/onboarding_scaffold.dart';
import 'financial_profile_screen.dart';

class PersonalDetailsScreen extends StatefulWidget {
  final OnboardingData data;

  const PersonalDetailsScreen({super.key, required this.data});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.data.firstName);
    _lastNameController = TextEditingController(text: widget.data.lastName);
    _emailController = TextEditingController(text: widget.data.email);
    for (final c in [_firstNameController, _lastNameController, _emailController]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final email = _emailController.text.trim();
    return _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        email.contains('@') &&
        email.contains('.');
  }

  void _handleNext() {
    if (!_isValid) return;
    widget.data
      ..firstName = _firstNameController.text.trim()
      ..lastName = _lastNameController.text.trim()
      ..email = _emailController.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinancialProfileScreen(data: widget.data),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 16),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      currentStep: 0,
      title: 'Personal Details',
      subtitle: 'Information required to personalize your experience.',
      nextEnabled: _isValid,
      onNext: _handleNext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(label: 'First Name', controller: _firstNameController, hintText: 'John',),
          _buildField(label: 'Last Name', controller: _lastNameController, hintText: 'Doe',),
          _buildField(
            label: 'Email Address',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hintText: 'john.doe@example.com',
            suffixIcon: const Icon(Icons.mail_outline, color: Color(0xFF6C63FF), size: 20),
          ),
        ],
      ),
    );
  }
}