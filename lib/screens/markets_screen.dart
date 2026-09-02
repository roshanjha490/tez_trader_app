import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/sockets.dart';
import '../services/app_navigation.dart';
import 'tabs/sectors_tab.dart';
import 'tabs/shoutbox_tab.dart';
import 'main_shell.dart';
import 'dart:ui';

class MarketsScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? initialSector;

  const MarketsScreen({super.key, this.initialTabIndex = 0, this.initialSector});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

// Index of the "Sectors" sub-tab within this screen's TabBar/TabBarView.
const int _sectorsSubTabIndex = 6;

class _MarketsScreenState extends State<MarketsScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _dataSub;
  StreamSubscription<bool>? _statusSub;
  bool _isConnected = false;

  bool _isActive = false;

  // Explicit TabController (replaces DefaultTabController) so the Sectors
  // sub-tab can be selected programmatically at any time — e.g. when the
  // Home tab's Sector Performance card requests a specific sector — not
  // just once at construction. MarketsScreen is created ONCE and kept
  // alive inside MainShell's IndexedStack, so `initState`/`initialIndex`
  // only ever runs a single time; a later request needs a live controller
  // to `animateTo()`, it can't rely on rebuilding with a new initialIndex.
  late final TabController _tabController;

  // React State equivalents — one list per strategy type now.
  List<dynamic> _reversalStrategies = [];
  List<dynamic> _railwayStrategies = [];
  List<dynamic> _rajdhaniStrategies = [];
  List<dynamic> _breakouts = [];
  Map<String, dynamic>? _movers;
  Map<String, dynamic>? _sentiment;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    sectorTabRequest.addListener(_handleSectorTabRequest);

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
        // -- Reversal Strategy --
        if (type == 'initial_reversal_strategies' ||
            type == 'reversal_price_update') {
          _reversalStrategies = List<dynamic>.from(data);
        } else if (type == 'reversal_strategies_update') {
          final updated = List<dynamic>.from(_reversalStrategies)
            ..removeWhere((s) => s['symbol'] == data['symbol']);
          updated.insert(0, data);
          _reversalStrategies = updated;
        }
        // -- Railway Strategy --
        else if (type == 'initial_railway_strategies' ||
            type == 'railway_price_update') {
          _railwayStrategies = List<dynamic>.from(data);
        } else if (type == 'railway_strategies_update') {
          final updated = List<dynamic>.from(_railwayStrategies)
            ..removeWhere((s) => s['symbol'] == data['symbol']);
          updated.insert(0, data);
          _railwayStrategies = updated;
        }
        // -- Rajdhani Strategy --
        else if (type == 'initial_rajdhani_strategies' ||
            type == 'rajdhani_price_update') {
          _rajdhaniStrategies = List<dynamic>.from(data);
        } else if (type == 'rajdhani_strategies_update') {
          final updated = List<dynamic>.from(_rajdhaniStrategies)
            ..removeWhere((s) => s['symbol'] == data['symbol']);
          updated.insert(0, data);
          _rajdhaniStrategies = updated;
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

  void _handleSectorTabRequest() {
    if (sectorTabRequest.value != null) {
      _tabController.animateTo(_sectorsSubTabIndex);
    }
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
    sectorTabRequest.removeListener(_handleSectorTabRequest);
    _tabController.dispose();
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
    return Scaffold(
      backgroundColor: Colors.transparent,
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
            Icon(
              Icons.circle,
              size: 10,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
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
          tabs: const [
            Tab(text: "Rajdhani"),
            Tab(text: "Railway"),
            Tab(text: "Reversal"),
            Tab(text: "Top Movers"),
            Tab(text: "Live Breakout"),
            Tab(text: "Shoutbox"),
            Tab(text: "Sectors"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStrategiesTab(_rajdhaniStrategies),
          _buildStrategiesTab(_railwayStrategies),
          _buildStrategiesTab(_reversalStrategies),
          _buildMoversTab(),
          _buildBreakoutsTab(),
          const ShoutboxTab(),
          SectorsTab(initialSector: widget.initialSector),
        ],
      ),
    );
  }

  // Pull-to-refresh for the socket-driven tabs just forces the shared
  // marketsSocket to reconnect — that re-triggers the initial_* payloads
  // for whichever channels are subscribed, refilling all three strategy
  // lists, movers, and breakouts at once.
  Future<void> _handleMarketsRefresh() => marketsSocket.forceReconnect();

  Widget _buildStrategiesTab(List<dynamic> strategies) {
    final sortedStrategies = List<dynamic>.from(strategies);
    sortedStrategies.sort((a, b) {
      final timeA = a['time']?.toString() ?? '';
      final timeB = b['time']?.toString() ?? '';
      return timeB.compareTo(timeA);
    });

    return RefreshIndicator(
      onRefresh: _handleMarketsRefresh,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF111827),
      child: sortedStrategies.isEmpty
          ? ListView(
              // A bare Center() isn't scrollable, so RefreshIndicator has
              // nothing to attach the drag gesture to. Wrapping the empty
              // message in a ListView with AlwaysScrollableScrollPhysics
              // keeps pull-to-refresh working even with zero rows.
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Text(
                    "No active setups found today.",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: sortedStrategies.length,
              itemBuilder: (context, index) {
                final strategy = sortedStrategies[index];

                final time = strategy['time']?.toString() ?? '--:--';
                final symbol = strategy['symbol']?.toString() ?? 'Unknown';
                final strategyName = strategy['strategy']?.toString() ?? '';
                final signal = strategy['signal']?.toString() ?? 'N/A';
                final price = strategy['price']?.toString() ?? '0.00';
                final status = strategy['status']?.toString() ?? 'Waiting';
                final pnl = strategy['pnl']?.toString() ?? '0.00%';

                Color signalColor = Colors.white54;
                if (signal == 'BULLISH') signalColor = Colors.greenAccent;
                if (signal == 'BEARISH') signalColor = Colors.redAccent;

                Color pnlColor = Colors.white54;
                if (pnl.contains('+')) pnlColor = Colors.greenAccent;
                if (pnl.contains('-') && pnl.length > 1)
                  pnlColor = Colors.redAccent;

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

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹$price',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
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
            ),
    );
  }

  Widget _buildMoversTab() {
    return RefreshIndicator(
      onRefresh: _handleMarketsRefresh,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF111827),
      child: _movers == null
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Text(
                    "Scanning for movers...",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_sentiment != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                      Text(
                        "Unchanged: ${_sentiment!['unchanged']}",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
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
                          color: Colors.white12,
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
                ],

                // Gainers / Losers side-by-side glass panels
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMoversColumn(
                      title: "TOP GAINERS",
                      dotColor: Colors.greenAccent,
                      items: _movers!['gainers'] as List<dynamic>? ?? [],
                      isGain: true,
                    ),
                    const SizedBox(height: 12),
                    _buildMoversColumn(
                      title: "TOP LOSERS",
                      dotColor: Colors.redAccent,
                      items: _movers!['losers'] as List<dynamic>? ?? [],
                      isGain: false,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildMoversColumn({
    required String title,
    required Color dotColor,
    required List<dynamic> items,
    required bool isGain,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: dotColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final pct = item['pct_change']?.toString() ?? '0.00';
            final price = item['price'] ?? item['ltp'] ?? '0.00';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['symbol'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${isGain ? '+' : ''}$pct%',
                        style: TextStyle(
                          color: isGain ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBreakoutsTab() {
    return RefreshIndicator(
      onRefresh: _handleMarketsRefresh,
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF111827),
      child: _breakouts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Text(
                    "No breakouts yet",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: _breakouts.length,
              itemBuilder: (context, index) {
                final tick = _breakouts[index];
                final isHigh = tick['type'] == 'DAILY_HIGH';
                final breakColor = isHigh
                    ? Colors.greenAccent
                    : Colors.redAccent;

                final pctChange =
                    (tick['pct_change'] as num?)?.toDouble() ?? 0.0;
                final isPos = pctChange >= 0;
                final pctColor = isPos ? Colors.greenAccent : Colors.redAccent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: symbol, badge, timestamp
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  tick['symbol'] ?? '',
                                  style: TextStyle(
                                    color: breakColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: breakColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: breakColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isHigh
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        size: 12,
                                        color: breakColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isHigh ? 'HIGH BREAK' : 'LOW BREAK',
                                        style: TextStyle(
                                          color: breakColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Triggered at ${tick['time']}",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right: price + % change
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${tick['price']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${isPos ? '+' : ''}${pctChange.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: pctColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}