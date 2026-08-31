import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../services/sockets.dart';
import '../widgets/stock_ribbon.dart';
import 'main_shell.dart';

String _capitalize(String value) {
  if (value == null || value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<dynamic>? _userFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (ActiveTab.of(context) == 0) {
      _userFuture = TokenStorage.getCurrentUser();
    }
  }

  // Pull-to-refresh handler: re-reads the cached user (cheap, local) and
  // force-reconnects the live ticker socket so StockRibbon gets a fresh
  // initial_snapshot instead of just sitting on stale prices.
  Future<void> _handleRefresh() async {
    final refreshed = TokenStorage.getCurrentUser();
    await Future.wait([
      refreshed,
      sectorsSocket.forceReconnect(),
    ]);
    if (mounted) {
      setState(() {
        _userFuture = refreshed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _userFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF171727),
          // No edgeOffset needed anymore — the ribbon is now the first
          // sliver INSIDE this scroll view, so the indicator naturally
          // appears above it, and the drag gesture starting anywhere
          // (even directly over the ribbon) is captured by this same
          // CustomScrollView instead of being lost to a sibling widget.
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. The Real-Time Ticker Ribbon — now part of the scroll,
              // so pulling down while your finger is over it still drags
              // the whole page and triggers refresh.
              const SliverToBoxAdapter(child: StockRibbon()),

              // 2. The Rest of the Dashboard Content
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      user != null ? 'Welcome, ${_capitalize(user.firstName)}' : 'Welcome',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Here is your live market overview.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderCard(String title, IconData icon) {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}