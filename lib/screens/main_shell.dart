import '../widgets/notification_bell.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'markets_screen.dart';
import 'discover.dart';
import 'profile_screen.dart';
import '../theme/app_colors.dart';
import '../services/app_navigation.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../services/alerts_service.dart';

/// Stable key so code elsewhere (e.g. requestSectorTab) can reach the one
/// live MainShell instance without needing a BuildContext that's actually
/// inside MainShell's own tree.
final GlobalKey<_MainShellState> _mainShellKey = GlobalKey<_MainShellState>();

/// Switches MainShell's bottom-nav tab from anywhere in the app.
void switchMainShellTab(int index) {
  _mainShellKey.currentState?.selectTab(index);
}

/// Top-level app shell shown after auth. Owns the bottom navigation and the
/// shared top bar (centered wordmark + notifications), and swaps between the
/// four primary tabs without losing each tab's state.
class MainShell extends StatefulWidget {
  // Not `const` anymore: the default key comes from a global variable
  // (_mainShellKey), which isn't a compile-time constant. Every existing
  // `const MainShell()` call site needs to drop the `const`.
  MainShell({Key? key}) : super(key: key ?? _mainShellKey);

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

  // Markets is tab index 1 in `_tabs` above.
  static const int _marketsTabIndex = 1;

  @override
  void initState() {
    super.initState();
    sectorTabRequest.addListener(_handleSectorTabRequest);
    urgentAlert.addListener(_handleUrgentAlert);
    AlertsService.instance.start();
  }

  @override
  void dispose() {
    sectorTabRequest.removeListener(_handleSectorTabRequest);
    urgentAlert.removeListener(_handleUrgentAlert);
    AlertsService.instance.stop();
    super.dispose();
  }

  /// Admin-pushed URGENT_BROADCAST: loud, impossible-to-miss modal.
  void _handleUrgentAlert() {
    final alert = urgentAlert.value;
    if (alert == null || !mounted) return;

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A0F14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('URGENT ALERT', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(alert.message, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Acknowledge & Dismiss'),
          ),
        ],
      ),
    );
  }

  void _handleSectorTabRequest() {
    if (sectorTabRequest.value != null) {
      selectTab(_marketsTabIndex);
    }
  }

  /// Public so it can be triggered both by bottom-nav taps and by
  /// switchMainShellTab() from outside this widget's own tree.
  void selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _onTabTapped(int index) => selectTab(index);

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
        const NotificationBell(),
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