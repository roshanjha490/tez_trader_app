import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tez_trader_app/screens/main_shell.dart';

import '../services/sockets.dart';

class StockRibbon extends StatefulWidget {
  const StockRibbon({super.key});

  @override
  State<StockRibbon> createState() => _StockRibbonState();
}

class _StockRibbonState extends State<StockRibbon> {
  StreamSubscription<Map<String, dynamic>>? _pricesSub;
  Map<String, dynamic> _livePrices = {};
  bool _isDataLoaded = false;

  bool _isActive = false;

  // Controls the infinite marquee scrolling
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  // Delays before the auto-marquee resumes after the user manually
  // swipes/drags the ribbon (or flings it and lets it settle).
  Timer? _resumeTimer;

  static const double _cardHeight = 116;

  @override
  void initState() {
    super.initState();

    _pricesSub = sectorsPrices.stream.listen((prices) {
      if (!mounted) return;
      final justLoaded = !_isDataLoaded;
      final filtered = Map<String, dynamic>.fromEntries(
        prices.entries.where((e) => !isTrackingInstrument(e.key)),
      );
      setState(() {
        _livePrices = filtered;
        _isDataLoaded = true;
      });
      // Only start the marquee if the user is currently on the Home tab
      if (justLoaded && _isActive) _startMarquee();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we are currently on the Home Tab (Index 0)
    final isNowActive = ActiveTab.of(context) == 0;

    if (isNowActive && !_isActive) {
      _isActive = true;
      sectorsSocket.acquire(); // Connect!

      // If we already have cached data, immediately show it and start scrolling
      if (sectorsPrices.hasSnapshot) {
        _livePrices = Map<String, dynamic>.fromEntries(
          sectorsPrices.current.entries.where((e) => !isTrackingInstrument(e.key)),
        );
        _isDataLoaded = true;
        _startMarquee();
      }
    } else if (!isNowActive && _isActive) {
      _isActive = false;
      sectorsSocket.release(); // Disconnect!

      // Stop the animation from consuming CPU while off-screen
      _scrollTimer?.cancel();
      _resumeTimer?.cancel();
    }
  }

  void _startMarquee() {
    // Smooth, continuous scrolling logic
    _scrollTimer?.cancel();
    if (!_isActive) return; // Safety check

    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.offset +
              2.4, // Adjust speed by changing this number
          duration: const Duration(milliseconds: 30),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _resumeTimer?.cancel();
    _scrollController.dispose();
    _pricesSub?.cancel();

    if (_isActive) {
      sectorsSocket.release();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return SizedBox(
        height: _cardHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
            ),
          ),
        ),
      );
    }

    final symbols = _livePrices.keys.toList();

    return SizedBox(
      height: _cardHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _scrollTimer?.cancel();
            _resumeTimer?.cancel();
          } else if (notification is ScrollEndNotification) {
            _resumeTimer?.cancel();
            _resumeTimer = Timer(const Duration(seconds: 3), _startMarquee);
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final symbol = symbols[index % symbols.length];
            final data = _livePrices[symbol] as Map<String, dynamic>? ?? {};
            return _LiveStockCard(symbol: symbol, data: data);
          },
        ),
      ),
    );
  }
}

/// A single compact ticker card: symbol + LTP + % change up top, then a
/// small open/high/low/volume strip beneath — all sourced live from the
/// `/ltp-stocks` websocket payload (ltp, pct_change, daily_open, daily_high,
/// daily_low, volume).
class _LiveStockCard extends StatelessWidget {
  const _LiveStockCard({required this.symbol, required this.data});

  final String symbol;
  final Map<String, dynamic> data;

  double _num(String key) => (data[key] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final ltp = _num('ltp');
    final pctChange = _num('pct_change');
    final dayOpen = _num('daily_open');
    final dayHigh = _num('daily_high');
    final dayLow = _num('daily_low');
    final prevClose = _num('prev_close');
    final isPositive = pctChange >= 0;
    final changeColor = isPositive ? Colors.greenAccent : Colors.redAccent;

    return MediaQuery(
      // Locks text scaling to 1.0 for this ticker only. Ribbon cards have a
      // fixed height/width; if the device's system font-size (accessibility
      // "larger text") setting is above 1.0x, every Text widget here grows
      // slightly and can push the layout past its fixed bounds even though
      // it fits perfectly at default scale. This keeps the ribbon immune to
      // that setting without affecting text size anywhere else in the app.
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Symbol + % change chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    symbol,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: changeColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${pctChange.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // LTP
            Text(
              '₹${ltp.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            // Open / High row
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'O',
                    value: dayOpen.toStringAsFixed(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniStat(
                    label: 'H',
                    value: dayHigh.toStringAsFixed(1),
                    valueColor: Colors.greenAccent.withOpacity(0.85),
                  ),
                ),
              ],
            ),
            // Low / Close row
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'L',
                    value: dayLow.toStringAsFixed(1),
                    valueColor: Colors.redAccent.withOpacity(0.85),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MiniStat(
                    label: 'C',
                    value: prevClose.toStringAsFixed(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontSize: 9.5, color: Colors.white38),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.white60,
              ),
            ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}
