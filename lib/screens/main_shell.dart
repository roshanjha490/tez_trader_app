import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'markets_screen.dart';
import 'discover.dart';
import 'profile_screen.dart';
import '../theme/app_colors.dart';
import 'dart:ui';

/// Top-level app shell shown after auth. Owns the bottom navigation and the
/// shared top bar (centered wordmark + notifications), and swaps between the
/// four primary tabs without losing each tab's state.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    HomeScreen(),
    MarketsScreen(),
    DiscoverScreen(),
    ProfileScreen(),
  ];

  static const _backgroundColor = AppColors.background;
  static const _accentColor = Color(0xFF6C63FF);

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: _buildTopBar(),
      body: Stack(
        children: [
          Container(color: AppColors.background),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.5, -0.7),
                  radius: 0.9,
                  colors: [
                    AppColors.blueGlow.withOpacity(0.20),
                    AppColors.blueGlow.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.5),
                  radius: 1.1,
                  colors: [
                    AppColors.purpleGlow.withOpacity(0.20),
                    AppColors.purpleGlow.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Emerald glow — center-ish
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.2, 0.0),
                  radius: 0.7,
                  colors: [
                    AppColors.emeraldGlow.withOpacity(0.10),
                    AppColors.emeraldGlow.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            // 1. Wrap the IndexedStack with our new ActiveTab provider!
            child: ActiveTab(
              index: _selectedIndex,
              child: IndexedStack(index: _selectedIndex, children: _tabs),
            ),
            ),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onTabTapped,
        accentColor: _accentColor,
      ),
    );
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
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
      title: const Text(
        'TEZ TRADER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: navigate to notifications screen once it exists.
          },
          icon: const Icon(Icons.notifications_rounded, color: Colors.white70),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color accentColor;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.accentColor,
  });

  static const _items = [
    _NavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItemData(
      icon: Icons.show_chart_rounded,
      activeIcon: Icons.show_chart_rounded,
      label: 'Markets',
    ),
    _NavItemData(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Discover',
    ),
    _NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // SafeArea (top: false) pads the bar by however tall the device's
    // bottom system inset actually is — the 3-button Android nav bar,
    // a gesture-pill inset, or nothing on devices without either. Without
    // this, a fixed bottom padding (like the old `14`) isn't enough on
    // button-nav devices and the pill ends up sitting under/behind the
    // system buttons, as seen in the screenshot.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF171727),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = index == selectedIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? accentColor : Colors.white54,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? accentColor : Colors.white54,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Inherited widget to broadcast the active tab index down the tree.
/// This allows child screens inside the IndexedStack to know when they
/// are visible so they can automatically connect/disconnect WebSockets or re-fetch APIs.
class ActiveTab extends InheritedWidget {
  final int index;

  const ActiveTab({super.key, required this.index, required super.child});

  static int of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveTab>()?.index ?? 0;
  }

  @override
  bool updateShouldNotify(ActiveTab oldWidget) => index != oldWidget.index;
}
