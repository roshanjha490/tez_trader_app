import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/onboarding_data.dart';

import '../../services/auth_api_client.dart';
import '../../services/token_storage.dart';

import '../main_shell.dart';
import '../onboarding/personal_details_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  static const int _otpLength = 6;
  static const int _resendSeconds = 30;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  bool _isVerifying = false;
  bool _isResending = false;
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  // Two independently-drifting colored glows — indigo and purple — that
  // layer over the dark base to create a moving two-tone background.
  late final AnimationController _indigoController;
  late final Animation<Alignment> _indigoAlignment;

  late final AnimationController _purpleController;
  late final Animation<Alignment> _purpleAlignment;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Auto-focus the first OTP box as soon as the screen loads, so the
    // user can start typing right away without tapping the field first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });

    _indigoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _indigoAlignment =
        AlignmentTween(
          begin: const Alignment(-0.9, -0.8),
          end: const Alignment(0.5, 0.9),
        ).animate(
          CurvedAnimation(parent: _indigoController, curve: Curves.easeInOut),
        );

    _purpleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    _purpleAlignment =
        AlignmentTween(
          begin: const Alignment(0.9, 0.8),
          end: const Alignment(-0.5, -0.9),
        ).animate(
          CurvedAnimation(parent: _purpleController, curve: Curves.easeInOut),
        );
  }

  void _startResendTimer() {
    _secondsLeft = _resendSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _indigoController.dispose();
    _purpleController.dispose();
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  bool get _isOtpComplete => _enteredOtp.length == _otpLength;

  final List<KeyEventResult> _ = [];

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _selectAll(int index) {
    _controllers[index].selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controllers[index].text.length,
    );
  }

  KeyEventResult _handleKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        // Box is already empty: jump back and clear the previous box too.
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        _selectAll(index - 1);
        setState(() {});
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleVerify() async {
    if (!_isOtpComplete || _isVerifying) return;

    setState(() => _isVerifying = true);

    try {
      final response = await AuthApiClient.dio.post(
        '/auth/verifyOTP',
        data: {'mobile': widget.phoneNumber, 'otp': _enteredOtp},
      );

      if (!mounted) return;

      final data = response.data as Map;
      if (data['success'] == true) {
        await TokenStorage.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );

        final profileCompleted = data['profileCompleted'] as bool? ?? false;

        if (!mounted) return;
        if (profileCompleted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PersonalDetailsScreen(data: OnboardingData()),
            ),
            (route) => false,
          );
        }
      } else {
        _showError(
          data['message']?.toString() ??
              'Verification failed. Please try again.',
        );
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final message = responseData is Map
          ? (responseData['message'] ?? 'Invalid or expired OTP.')
          : 'Invalid or expired OTP.';
      _showError(message.toString());
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      await AuthApiClient.dio.post(
        '/auth/sendOTP',
        data: {'mobile': widget.phoneNumber},
      );
      if (mounted) _startResendTimer();
    } catch (e) {
      if (mounted) _showError('Failed to resend OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verifyEnabled = _isOtpComplete && !_isVerifying;

    return Scaffold(
      body: Stack(
        children: [
          // Dark base so the indigo/purple glows have something moody to sit on.
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: [
                  Color(0xFF17142E),
                  Color(0xFF0E0C1C),
                  Color(0xFF0A0A12),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Indigo glow, drifting on its own path. (Tailwind indigo-500/30)
          AnimatedBuilder(
            animation: _indigoController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _indigoAlignment.value,
                    radius: 1.1,
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.30),
                      const Color(0xFF6366F1).withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
            },
          ),

          // Purple glow, drifting on a different path/speed so the two blend
          // and shift relative to each other as they move.
          // (Tailwind purple-600/20)
          AnimatedBuilder(
            animation: _purpleController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _purpleAlignment.value,
                    radius: 1.1,
                    colors: [
                      const Color(0xFF9333EA).withOpacity(0.20),
                      const Color(0xFF9333EA).withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Verify your number',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      text: 'Enter the 6-digit code sent to ',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                      children: [
                        TextSpan(
                          text: '+91 ${widget.phoneNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // OTP boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (index) {
                      return SizedBox(
                        width: 46,
                        height: 56,
                        child: KeyboardListener(
                          focusNode: FocusNode(
                            skipTraversal: true,
                          ), // separate raw-key listener node
                          onKeyEvent: (event) => _handleKey(index, event),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onTap: () => _selectAll(index),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.35),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6C63FF),
                                ),
                              ),
                            ),
                            onChanged: (value) => _onDigitChanged(index, value),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 30),

                  // Resend
                  Row(
                    children: [
                      const Text(
                        "Didn't receive the code? ",
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                      GestureDetector(
                        onTap: (_secondsLeft == 0 && !_isResending)
                            ? _handleResend
                            : null,
                        child: Text(
                          _secondsLeft == 0
                              ? (_isResending ? 'Sending...' : 'Resend')
                              : 'Resend in ${_secondsLeft}s',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _secondsLeft == 0
                                ? const Color(0xFF6C63FF)
                                : Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Verify button
                  // Verify button — "Secure Login" pill style
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: verifyEnabled
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: verifyEnabled ? _handleVerify : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: _isVerifying
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Secure Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: verifyEnabled
                                                ? Colors.black87
                                                : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.verified_user_rounded,
                                          size: 18,
                                          color: verifyEnabled
                                              ? Colors.black87
                                              : Colors.black45,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
