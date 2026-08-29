import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../widgets/stock_ribbon.dart';
import 'main_shell.dart';

String _capitalize(String value) {
  if (value == null || value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

/// The "Overview" tab — this is where the ticker bar, watchlists, and
/// portfolio summary from the dashboard design will eventually live.
/// For now it carries over the welcome state from the old placeholder
/// dashboard so the shell isn't empty.
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
    
    // Whenever this tab becomes visible (Index 0), re-fetch the API data!
    if (ActiveTab.of(context) == 0) {
      _userFuture = TokenStorage.getCurrentUser();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. The Real-Time Ticker Ribbon at the very top
        const StockRibbon(),

        // 2. The Scrollable Dashboard Content
        Expanded(
          child: FutureBuilder(
            future: _userFuture,
            builder: (context, snapshot) {
              final user = snapshot.data;
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    // --- Placeholders for Future Widgets ---
                    // _buildPlaceholderCard('Portfolio Summary', Icons.pie_chart_outline),
                    // const SizedBox(height: 16),
                    // _buildPlaceholderCard('Active Watchlists', Icons.list_alt_rounded),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // A helper method to draw glassmorphic placeholder cards
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