import 'dart:ui';

import 'package:flutter/material.dart';

/// The frosted, translucent top bar MainShell uses. Pair it with
/// `Scaffold(extendBodyBehindAppBar: true)` and `AppBackground(underAppBar: true)`
/// so pushed screens show the same glows behind the header as the shell does.
class ThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const ThemedAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
          ),
        ),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      actions: actions,
    );
  }
}
