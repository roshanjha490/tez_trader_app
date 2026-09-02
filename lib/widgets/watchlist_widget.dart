import 'package:flutter/material.dart';
import '../services/watchlist_service.dart';
import '../screens/tabs/sectors_tab.dart' show SECTORS;

class WatchlistWidget extends StatefulWidget {
  final Map<String, dynamic> livePrices;

  const WatchlistWidget({super.key, required this.livePrices});

  @override
  State<WatchlistWidget> createState() => _WatchlistWidgetState();
}

class _WatchlistWidgetState extends State<WatchlistWidget> {
  static const _accentColor = Color(0xFF6C63FF);

  List<String> _savedSymbols = [];
  bool _isLoading = true;
  bool _isAdding = false;
  late final List<String> _allSymbols;

  @override
  void initState() {
    super.initState();
    _allSymbols = SECTORS.values.expand((s) => s).toSet().toList()..sort();
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    final res = await WatchlistService.getWatchlist();
    if (!mounted) return;
    setState(() {
      if (res['success'] == true && res['data'] != null) {
        _savedSymbols = List<String>.from(res['data']);
      }
      _isLoading = false;
    });
  }

  Future<void> _handleAdd(String symbol) async {
    if (_savedSymbols.contains(symbol) || _isAdding) return;
    Navigator.pop(context); // close the add-symbol sheet

    setState(() {
      _isAdding = true;
      _savedSymbols = [symbol, ..._savedSymbols];
    });

    final res = await WatchlistService.addStock(symbol);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _savedSymbols.remove(symbol));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Failed to add stock'),
        ),
      );
    }
    setState(() => _isAdding = false);
  }

  Future<void> _handleRemove(String symbol) async {
    final previous = List<String>.from(_savedSymbols);
    setState(() => _savedSymbols.remove(symbol));

    final res = await WatchlistService.removeStock(symbol);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _savedSymbols = previous);
    }
  }

  void _openAddModal() {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _allSymbols
                .where((s) => s.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: FractionallySizedBox(
                heightFactor: 0.85,
                child: Material(
                  color: const Color(0xFF0B0F19),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add Symbol',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (v) => setModalState(() => query = v),
                            decoration: const InputDecoration(
                              hintText: 'Search stocks...',
                              hintStyle: TextStyle(color: Colors.white38),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.white38,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No stocks found',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final sym = filtered[i];
                                  final isAdded = _savedSymbols.contains(sym);
                                  return ListTile(
                                    enabled: !isAdded,
                                    title: Text(
                                      sym,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: isAdded
                                        ? const Text(
                                            'Added',
                                            style: TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 12,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.add,
                                            color: Colors.white38,
                                            size: 18,
                                          ),
                                    onTap: isAdded
                                        ? null
                                        : () => _handleAdd(sym),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                'My Watchlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openAddModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Add Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: _accentColor),
              ),
            )
          else if (_savedSymbols.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your watchlist is empty.',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap "Add Stock" to start tracking.',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _savedSymbols.map((symbol) {
                final data =
                    widget.livePrices[symbol] as Map<String, dynamic>? ?? {};
                final ltp = (data['ltp'] as num?)?.toDouble() ?? 0.0;
                final pct = (data['pct_change'] as num?)?.toDouble() ?? 0.0;
                final isPositive = pct >= 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 12,
                                  color: isPositive
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${pct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: isPositive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${ltp.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _handleRemove(symbol),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
