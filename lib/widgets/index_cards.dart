import 'package:flutter/material.dart';

class IndexCardsRow extends StatelessWidget {
  final Map<String, dynamic> trackingPrices;
  final bool isDataLoaded;

  const IndexCardsRow({
    super.key,
    required this.trackingPrices,
    required this.isDataLoaded,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDataLoaded || trackingPrices.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.4,
        ),
        itemCount: 4,
        itemBuilder: (context, i) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
        ),
      );
    }

    final entries = trackingPrices.entries.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final symbol = entries[index].key;
        final data = entries[index].value as Map<String, dynamic>? ?? {};
        final ltp = (data['ltp'] as num?)?.toDouble() ?? 0.0;
        final pct = (data['pct_change'] as num?)?.toDouble() ?? 0.0;
        final isPositive = pct >= 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Wrap the left column in Expanded so it yields space to the percentage pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis, // Truncates long symbols
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ltp.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis, // Truncates long prices
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 2. Simplified pill with the icon removed
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.greenAccent : Colors.redAccent)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isPositive ? '' : ''}${pct.abs().toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
