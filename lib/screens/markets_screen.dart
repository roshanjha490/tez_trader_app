import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/sockets.dart';
import 'tabs/sectors_tab.dart';
import 'tabs/shoutbox_tab.dart';
import 'main_shell.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  StreamSubscription? _dataSub;
  StreamSubscription<bool>? _statusSub;
  bool _isConnected = false;

  bool _isActive = false;

  // React State equivalents
  List<dynamic> _strategies = [];
  List<dynamic> _breakouts = [];
  Map<String, dynamic>? _movers;
  Map<String, dynamic>? _sentiment;

  @override
  void initState() {
    super.initState();

    _statusSub = marketsSocket.statusStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });
    _isConnected = marketsSocket.isConnected;

    _dataSub = marketsSocket.stream.listen((message) {
      final payload = jsonDecode(message);
      final type = payload['type'];
      final data = payload['data'];

      if (!mounted) return;
      setState(() {
        // -- Strategy Handlers --
        if (type == 'initial_strategies' || type == 'strategy_price_update') {
          _strategies = data;
        } else if (type == 'strategy_update') {
          // Filter out the old version, prepend the new one
          _strategies.removeWhere((s) => s['symbol'] == data['symbol']);
          _strategies.insert(0, data);
        }
        // -- Breakout Handlers --
        else if (type == 'breakout_tick') {
          _breakouts.insert(0, data);
          if (_breakouts.length > 50) _breakouts.removeLast();
        }
        // -- Top Movers --
        else if (type == 'top_movers') {
          _movers = data;
        }
        // -- Market Sentiment --
        else if (type == 'market_sentiment') {
          _sentiment = data;
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we are currently on the Markets Tab (Index 1)
    final isNowActive = ActiveTab.of(context) == 1;

    if (isNowActive && !_isActive) {
      _isActive = true;
      marketsSocket.acquire(); // Connect!
    } else if (!isNowActive && _isActive) {
      _isActive = false;
      marketsSocket.release(); // Disconnect!
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _statusSub?.cancel();

    // 5. ONLY RELEASE IF WE ARE CURRENTLY ACTIVE
    if (_isActive) {
      marketsSocket.release();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19), // Dark Theme
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              const Text(
                'Markets',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // Show a live pulsing dot when connected!
              Icon(
                Icons.circle,
                size: 10,
                color: _isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: "Strategies"),
              Tab(text: "Top Movers"),
              Tab(text: "Live Breakout"),
              Tab(text: "Shoutbox"),
              Tab(text: "Sectors"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Strategies Tab
            _buildStrategiesTab(),

            // 2. Top Movers Tab
            _buildMoversTab(),

            // 3. Live Breakout Tab
            _buildBreakoutsTab(),

            const ShoutboxTab(),

            // 6. Sectors
            const SectorsTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET BUILDERS FOR EACH TAB
  // ==========================================

  Widget _buildStrategiesTab() {
    if (_strategies.isEmpty) {
      return const Center(
        child: Text(
          "No active setups found today.",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // 1. Sort strategies by time (descending) just like Next.js
    final sortedStrategies = List<dynamic>.from(_strategies);
    sortedStrategies.sort((a, b) {
      final timeA = a['time']?.toString() ?? '';
      final timeB = b['time']?.toString() ?? '';
      return timeB.compareTo(timeA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedStrategies.length,
      itemBuilder: (context, index) {
        final strategy = sortedStrategies[index];

        // 2. Extract Data Safely
        final time = strategy['time']?.toString() ?? '--:--';
        final symbol = strategy['symbol']?.toString() ?? 'Unknown';
        final strategyName = strategy['strategy']?.toString() ?? '';
        final signal = strategy['signal']?.toString() ?? 'N/A';
        final price = strategy['price']?.toString() ?? '0.00';
        final status = strategy['status']?.toString() ?? 'Waiting';
        final pnl = strategy['pnl']?.toString() ?? '0.00%';

        // 3. Dynamic Color Logic (Matched to React code)
        Color signalColor = Colors.white54;
        if (signal == 'BULLISH') signalColor = Colors.greenAccent;
        if (signal == 'BEARISH') signalColor = Colors.redAccent;

        Color pnlColor = Colors.white54;
        if (pnl.contains('+')) pnlColor = Colors.greenAccent;
        if (pnl.contains('-') && pnl.length > 1) pnlColor = Colors.redAccent;

        // Status Pill Styling
        Color statusBgColor = Colors.orangeAccent.withOpacity(0.1);
        Color statusTextColor = Colors.orangeAccent;
        Color statusBorderColor = Colors.orangeAccent.withOpacity(0.3);

        if (status == 'Active') {
          statusBgColor = Colors.blueAccent.withOpacity(0.1);
          statusTextColor = Colors.blueAccent;
          statusBorderColor = Colors.blueAccent.withOpacity(0.3);
        } else if (status == 'Exited') {
          statusBgColor = Colors.white54.withOpacity(0.1);
          statusTextColor = Colors.white54;
          statusBorderColor = Colors.white54.withOpacity(0.3);
        }

        // 4. Build the Custom Mobile Data Card
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03), // Subtle glass effect
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE: Symbol, Time, Strategy, and Signal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          symbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strategyName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      signal,
                      style: TextStyle(
                        color: signalColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // RIGHT SIDE: Price, Live P&L, Status Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹$price',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace', // Monospace for numbers
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pnl,
                    style: TextStyle(
                      color: pnlColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // The Status Badge/Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      border: Border.all(color: statusBorderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoversTab() {
    if (_movers == null) {
      return const Center(
        child: Text(
          "Scanning for movers...",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final gainers = _movers!['gainers'] as List<dynamic>? ?? [];
    final losers = _movers!['losers'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_sentiment != null) ...[
          // Header Stats (Advances / Unchanged / Declines)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Advances (Left)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Advances: ${_sentiment!['advances']}",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "(${_sentiment!['advances_pct']}%)",
                    style: TextStyle(
                      color: Colors.greenAccent.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              // Unchanged (Middle)
              Text(
                "Unchanged: ${_sentiment!['unchanged']}",
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
              // Declines (Right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Declines: ${_sentiment!['declines']}",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    "(${_sentiment!['declines_pct']}%)",
                    style: TextStyle(
                      color: Colors.redAccent.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Percentage Bar Chart
          Builder(
            builder: (context) {
              final int advancesPct = (_sentiment!['advances_pct'] ?? 0)
                  .toInt();
              final int declinesPct = (_sentiment!['declines_pct'] ?? 0)
                  .toInt();
              int unchangedPct = 100 - advancesPct - declinesPct;
              if (unchangedPct < 0) unchangedPct = 0;

              return Container(
                height: 12,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.white12, // Fallback background
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    if (advancesPct > 0)
                      Expanded(
                        flex: advancesPct,
                        child: Container(color: Colors.greenAccent),
                      ),
                    if (unchangedPct > 0)
                      Expanded(
                        flex: unchangedPct,
                        child: Container(color: Colors.grey[600]),
                      ),
                    if (declinesPct > 0)
                      Expanded(
                        flex: declinesPct,
                        child: Container(color: Colors.redAccent),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Total Pool Footer
          Center(
            child: Text(
              "TOTAL MARKET POOL: ${_sentiment!['total']} STOCKS",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
        ],

        const Text(
          "TOP GAINERS",
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...gainers.map(
          (g) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              g['symbol'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Text(
              '+${g['pct_change']}%',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 16),

        const Text(
          "TOP LOSERS",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...losers.map(
          (l) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l['symbol'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Text(
              '${l['pct_change']}%',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakoutsTab() {
    if (_breakouts.isEmpty) {
      return const Center(
        child: Text(
          "No breakouts yet",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      itemCount: _breakouts.length,
      itemBuilder: (context, index) {
        final tick = _breakouts[index];
        final isHigh = tick['type'] == 'DAILY_HIGH';

        return ListTile(
          leading: Icon(
            isHigh ? Icons.trending_up : Icons.trending_down,
            color: isHigh ? Colors.green : Colors.red,
          ),
          title: Text(
            tick['symbol'] ?? '',
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            "Triggered at ${tick['time']}",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Text(
            '₹${tick['price']}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
