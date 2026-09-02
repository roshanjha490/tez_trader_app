import 'package:flutter/material.dart';
import '../screens/tabs/sectors_tab.dart' show SECTORS;
import '../screens/markets_screen.dart';
import 'dart:ui';

class SectorPerformanceCard extends StatefulWidget {
  final Map<String, dynamic> livePrices;

  const SectorPerformanceCard({super.key, required this.livePrices});

  @override
  State<SectorPerformanceCard> createState() => _SectorPerformanceCardState();
}

class _SectorPerformanceCardState extends State<SectorPerformanceCard> {
  bool _showGainers = true;

  List<MapEntry<String, double>> _computePerformance() {
    final performances = <MapEntry<String, double>>[];
    SECTORS.forEach((sector, symbols) {
      double total = 0;
      int count = 0;
      for (final sym in symbols) {
        final data = widget.livePrices[sym];
        if (data != null && data['pct_change'] != null) {
          total += (data['pct_change'] as num).toDouble();
          count++;
        }
      }
      if (count > 0) performances.add(MapEntry(sector, total / count));
    });
    return performances;
  }

  @override
  Widget build(BuildContext context) {
    final performances = _computePerformance();

    final gainers = (List<MapEntry<String, double>>.from(
      performances,
    )..sort((a, b) => b.value.compareTo(a.value))).take(4).toList();
    final losers = (List<MapEntry<String, double>>.from(
      performances,
    )..sort((a, b) => a.value.compareTo(b.value))).take(4).toList();

    final displayed = _showGainers ? gainers : losers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sector Performance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _toggleButton(
                      'Gainers',
                      _showGainers,
                      Colors.greenAccent,
                      () => setState(() => _showGainers = true),
                    ),
                    _toggleButton(
                      'Losers',
                      !_showGainers,
                      Colors.redAccent,
                      () => setState(() => _showGainers = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Scanning live sectors...',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ...displayed.map((entry) {
              final isPositive = entry.value >= 0;
              return Container(
                decoration: const BoxDecoration(
                  // Gives the bottom border only
                  border: Border(
                    bottom: BorderSide(color: Colors.white12, width: 1.0),
                  ),
                ),
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10.0,
                      sigmaY: 10.0,
                    ), // Requires dart:ui
                    child: Container( // Frosted glass translucent fill
                      child: Material(
                        color: Colors
                            .transparent, // Required to keep the InkWell ripple visible
                        child: InkWell(
                          // onTap: () => Navigator.of(context).push(
                          //   MaterialPageRoute(
                          //     builder: (_) => MarketsScreen(
                          //       initialTabIndex: 6,
                          //       initialSector: entry.key,
                          //     ),
                          //   ),
                          // ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 16,
                            ), // Increased padding
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14, // Increased font size
                                    ),
                                  ),
                                ),
                                Text(
                                  '${isPositive ? '+' : ''}${entry.value.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: isPositive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11, // Increased font size
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white38,
                                  size: 11,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _toggleButton(
    String label,
    bool active,
    Color activeColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? activeColor : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
