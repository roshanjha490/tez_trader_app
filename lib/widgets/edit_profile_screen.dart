import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/token_storage.dart';
import '../services/api_client.dart'; // Adjust this import path as needed

enum EditStep { form, otp }

class EditProfileScreen extends StatefulWidget {
  final dynamic user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _accentColor = Color(0xFF6C63FF);
  static const _cardColor = Color(0xFF1E1E2A);
  static const _backgroundColor = Color(0xFF0E0E1A);

  EditStep _step = EditStep.form;
  bool _isLoading = false;
  String? _error;
  String? _infoMessage;

  // Form Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  // OTP State
  final int _otpLength = 6;
  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _otpFocusNodes;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user?.lastName ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');

    _otpControllers = List.generate(_otpLength, (_) => TextEditingController());
    _otpFocusNodes = List.generate(_otpLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  bool get _hasChanges {
    return _firstNameController.text.trim() != (widget.user?.firstName ?? '') ||
           _lastNameController.text.trim() != (widget.user?.lastName ?? '') ||
           _emailController.text.trim() != (widget.user?.email ?? '');
  }

  // --- API LOGIC --- //

  Future<void> _handleRequestOtp() async {
    setState(() => _error = null);

    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      setState(() => _error = 'First and last name are required');
      return;
    }
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    if (!_hasChanges) {
      setState(() => _error = 'Change at least one field before saving');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/user/update-profile/request-otp',
        data: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
        },
      );

      final data = response.data;
      
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Failed to send OTP');
      }

      setState(() {
        _infoMessage = data['message'] ?? 'OTP sent to your registered mobile number';
        _step = EditStep.otp;
        for (var c in _otpControllers) {
          c.clear();
        }
      });
      
      _startCooldown();
      FocusScope.of(context).requestFocus(_otpFocusNodes[0]);

    } on DioException catch (e) {
      // Extract specific backend error message if available
      final errorMessage = e.response?.data?['message'] ?? 'Failed to connect to server';
      setState(() => _error = errorMessage);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _error = null);

    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != _otpLength) {
      setState(() => _error = 'Enter the $_otpLength-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/user/update-profile/verify-otp',
        data: {
          'otp': otp,
        },
      );

      final data = response.data;

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Invalid or expired OTP');
      }

      // If the backend returns a fresh token containing updated user claims/email
      if (data['token'] != null) {
        await TokenStorage.saveTokens(accessToken: data['token']);
      }

      if (!mounted) return;
      
      // Pop the screen and return true to indicate success to ProfileScreen
      Navigator.pop(context, true);

    } on DioException catch (e) {
      final errorMessage = e.response?.data?['message'] ?? 'Verification failed. Try again.';
      setState(() => _error = errorMessage);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDING --- //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: _step == EditStep.otp
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _isLoading ? null : () => setState(() => _step = EditStep.form),
              )
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _step == EditStep.form ? 'Edit Profile' : 'Verify OTP',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              
              if (_infoMessage != null && _step == EditStep.otp)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _infoMessage!,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),

              Expanded(
                child: _step == EditStep.form ? _buildForm() : _buildOtpVerification(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: 'First Name',
                icon: Icons.person_outline,
                controller: _firstNameController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                label: 'Last Name',
                controller: _lastNameController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Email Address',
          icon: Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: 'Mobile Number',
          icon: Icons.phone_android,
          controller: TextEditingController(text: widget.user?.mobile ?? 'Not provided'),
          readOnly: true,
          suffixText: "Locked",
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleRequestOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save & Verify', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOtpVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_otpLength, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: _cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _accentColor),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < _otpLength - 1) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
                  }
                  if (value.isEmpty && index > 0) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleVerifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Verify & Update', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: (_cooldown > 0 || _isLoading) ? null : _handleRequestOtp,
            child: Text(
              _cooldown > 0 ? 'Resend OTP in ${_cooldown}s' : 'Resend OTP',
              style: TextStyle(color: (_cooldown > 0) ? Colors.white38 : _accentColor),
            ),
          ),
        ),
      ],
    );
  }

  // --- REUSABLE TEXT FIELD --- //
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(color: readOnly ? Colors.white38 : Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: _cardColor,
            prefixIcon: icon != null ? Icon(icon, color: Colors.white38, size: 20) : null,
            suffixText: suffixText,
            suffixStyle: const TextStyle(color: Colors.white24, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: readOnly ? Colors.transparent : _accentColor),
            ),
          ),
        ),
      ],
    );
  }
}