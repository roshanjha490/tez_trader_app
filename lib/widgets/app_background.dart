import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The same slate-950 base with blue / purple / emerald glows that MainShell
/// paints behind its tabs, so screens pushed on top of the shell (post view,
/// mentor profile, notifications) keep the app's look.
class AppBackground extends StatelessWidget {
  final Widget child;

  /// Set when the Scaffold uses extendBodyBehindAppBar, so [child] starts
  /// below the app bar while the glows still paint behind it.
  final bool underAppBar;

  const AppBackground({super.key, required this.child, this.underAppBar = false});

  Widget _glow(Alignment center, double radius, Color color, double opacity) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [color.withOpacity(opacity), color.withOpacity(0)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.background),
        _glow(const Alignment(-0.5, -0.7), 0.9, AppColors.blueGlow, 0.20),
        _glow(const Alignment(0, 0.5), 1.1, AppColors.purpleGlow, 0.20),
        _glow(const Alignment(-0.2, 0.0), 0.7, AppColors.emeraldGlow, 0.10),
        underAppBar
            ? Padding(
                // With extendBodyBehindAppBar, Scaffold already reports the status bar
                // plus the app bar height as the body's top padding.
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                // The padding above already clears the status bar, so scroll
                // views inside must not add it a second time.
                child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
              )
            : child,
      ],
    );
  }
}
