import 'dart:async';
import 'package:flutter/material.dart';

import '../services/token_storage.dart';
import '../services/sockets.dart';
import '../widgets/stock_ribbon.dart';
import '../widgets/index_cards.dart';
import '../widgets/watchlist_widget.dart';
import '../widgets/sector_performance_card.dart';
import 'main_shell.dart';

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<dynamic>? _userFuture;

  StreamSubscription<Map<String, dynamic>>? _pricesSub;
  Map<String, dynamic> _livePrices = {};
  bool _isDataLoaded = false;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _pricesSub = sectorsPrices.stream.listen((prices) {
      if (!mounted) return;
      setState(() {
        _livePrices = prices;
        _isDataLoaded = true;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isNowActive = ActiveTab.of(context) == 0;

    if (isNowActive && !_isActive) {
      _isActive = true;
      _userFuture = TokenStorage.getCurrentUser();
      sectorsSocket.acquire();

      if (sectorsPrices.hasSnapshot) {
        _livePrices = sectorsPrices.current;
        _isDataLoaded = true;
      }
    } else if (!isNowActive && _isActive) {
      _isActive = false;
      sectorsSocket.release();
    }
  }

  @override
  void dispose() {
    _pricesSub?.cancel();
    if (_isActive) sectorsSocket.release();
    super.dispose();
  }

  // Pull-to-refresh: re-reads the cached user and force-reconnects the
  // live ticker socket so everything (ribbon, indices, watchlist, sectors)
  // gets a fresh initial_snapshot instead of sitting on stale prices.
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
    final trackingPrices = Map<String, dynamic>.fromEntries(
      _livePrices.entries.where((e) => isTrackingInstrument(e.key)),
    );

    return FutureBuilder(
      future: _userFuture,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF6C63FF),
          backgroundColor: const Color(0xFF171727),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Live ticker ribbon (normal stocks only)
              const SliverToBoxAdapter(child: StockRibbon()),

              // 2. Rest of the dashboard
              SliverPadding(
                // Decreased horizontal padding from 24 to 16
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // 3. Index cards (NIFTY 50, BANK NIFTY, SENSEX, etc.)
                    IndexCardsRow(trackingPrices: trackingPrices, isDataLoaded: _isDataLoaded),
                    const SizedBox(height: 24),

                    // 4. Watchlist
                    WatchlistWidget(livePrices: _livePrices),
                    const SizedBox(height: 24),

                    // 5. Sector performance (tap a row -> Markets > Sectors)
                    SectorPerformanceCard(livePrices: _livePrices),
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
}