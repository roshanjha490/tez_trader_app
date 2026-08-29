import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tez_trader_app/services/auth_api_client.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isValidNumber = false;

  // Two independently-drifting colored glows — one pink, one purple —
  // that layer over the dark base to create a moving two-tone background.
  late final AnimationController _pinkController;
  late final Animation<Alignment> _pinkAlignment;

  late final AnimationController _purpleController;
  late final Animation<Alignment> _purpleAlignment;

  // Controls the looping "wave" shimmer sweep on the terms text.
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);

    _pinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _pinkAlignment = AlignmentTween(
      begin: const Alignment(-0.9, -0.8),
      end: const Alignment(0.5, 0.9),
    ).animate(
      CurvedAnimation(parent: _pinkController, curve: Curves.easeInOut),
    );

    _purpleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);

    _purpleAlignment = AlignmentTween(
      begin: const Alignment(0.9, 0.8),
      end: const Alignment(-0.5, -0.9),
    ).animate(
      CurvedAnimation(parent: _purpleController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  void _onPhoneChanged() {
    final isValid = _phoneController.text.length == 10;
    if (isValid != _isValidNumber) {
      setState(() => _isValidNumber = isValid);
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _pinkController.dispose();
    _purpleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    if (!_isValidNumber || _isLoading) return;

    final phone = _phoneController.text.trim();
    setState(() => _isLoading = true);

    try {
      final response = await AuthApiClient.dio.post(
        '/auth/sendOTP',
        data: {'mobile': phone},
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(phoneNumber: phone),
          ),
        );
      } else {
        _showError('Failed to send OTP. Please try again.');
      }
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Failed to send OTP. Please try again.')
          : 'Failed to send OTP. Please try again.';
      _showError(message.toString());
    } catch (e) {
      _showError('Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonEnabled = _isValidNumber && !_isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // Dark base so the pink/purple glows have something moody to sit on.
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
            animation: _pinkController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: _pinkAlignment.value,
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
              children: [
                const SizedBox(height: 60),

                // Logo / App name
                const Text(
                  'TEZTRADER',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'By Way2Laabh',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 60),

                // Headline
                const Text.rich(
                  TextSpan(
                    text: 'Welcome to the Future of ',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(
                        text: 'Trading',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                const Text(
                  'Trade Smart • Trade Fast',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white54,
                  ),
                ),

                const SizedBox(height: 60),

                // Label
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter your mobile number',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),

                // Phone input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        '+91',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Container(height: 24, width: 1, color: Colors.white24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          // Digit-only input, capped at 10 characters
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'Mobile number',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Get Started button — gradient fill
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: buttonEnabled
                            ? const [Color(0xFF6366F1), Color(0xFF9333EA)]
                            : [
                                const Color(0xFF6366F1).withOpacity(0.35),
                                const Color(0xFF9333EA).withOpacity(0.35),
                              ],
                      ),
                      boxShadow: buttonEnabled
                          ? [
                              BoxShadow(
                                color: const Color(0xFF9333EA).withOpacity(0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: buttonEnabled ? _handleGetStarted : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: buttonEnabled
                                          ? Colors.white
                                          : Colors.white60,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Terms — shimmering wave highlight sweeps across
                _ShimmerWaveText(controller: _shimmerController),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}

/// Wraps the terms & conditions text in a ShaderMask whose gradient slides
/// left-to-right on a loop, producing a soft "wave of light" brightening
/// effect passing over the text.
class _ShimmerWaveText extends StatelessWidget {
  const _ShimmerWaveText({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.white54,
                Colors.white54,
                Colors.white,
                Colors.white54,
                Colors.white54,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlidingGradientTransform(
                // Slides the band from fully left-off-screen to fully
                // right-off-screen, then loops.
                slidePercent: controller.value * 3 - 1,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: const Text.rich(
        TextSpan(
          text: 'I agree to the ',
          style: TextStyle(fontSize: 12, color: Colors.white54),
          children: [
            TextSpan(
              text: 'Terms & Conditions',
              style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.white70),
            ),
            TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: Colors.white70),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}