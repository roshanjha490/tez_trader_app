import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/paper_trading_service.dart';
import '../../services/sockets.dart';

/// Paper-trading simulator: place LONG/SHORT orders at the live server-side
/// LTP, watch today's positions with live P&L, edit stop loss / target, exit.
/// Mirrors the portal's OrderExecutionWidget + LivePositionsWidget.
class PaperTradingTab extends StatefulWidget {
  const PaperTradingTab({super.key});

  @override
  State<PaperTradingTab> createState() => _PaperTradingTabState();
}

class _PaperTradingTabState extends State<PaperTradingTab> {
  static const _card = Color(0xFF111827);

  // --- order form ---
  final _symbolCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<PaperInstrument> _suggestions = [];
  PaperInstrument? _selected;
  String _direction = 'LONG';
  bool _placing = false;

  // --- positions ---
  List<PaperPosition> _positions = [];
  bool _loadingPositions = true;
  Timer? _refreshTimer;
  final Set<int> _processing = {}; // ids being closed, prevents double exits

  // --- live prices ---
  final Map<String, double> _ltp = {};
  final Map<String, int> _flash = {}; // 1 up, -1 down
  StreamSubscription? _sub;
  StreamSubscription<bool>? _statusSub;
  bool _connected = false;
  String _subscribed = '';

  @override
  void initState() {
    super.initState();
    _loadPositions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadPositions());

    _sub = paperSocket.stream.listen(_onMessage);
    _statusSub = paperSocket.statusStream.listen((c) {
      if (mounted) setState(() => _connected = c);
    });
    paperSocket.acquire();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    _sub?.cancel();
    _statusSub?.cancel();
    paperSocket.release();
    _symbolCtrl.dispose();
    _qtyCtrl.dispose();
    _targetCtrl.dispose();
    _slCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _loadPositions() async {
    try {
      final list = await PaperTradingService.positions();
      if (!mounted) return;
      setState(() {
        _positions = list;
        _loadingPositions = false;
      });
      _syncSubscription();
    } catch (_) {
      if (mounted) setState(() => _loadingPositions = false);
    }
  }

  /// Subscribe only to symbols of OPEN positions (saves bandwidth).
  void _syncSubscription() {
    final open = _positions.where((p) => p.isOpen).map((p) => p.symbol).toSet().toList()..sort();
    final key = open.join(',');
    paperSymbols = open;
    if (key != _subscribed) {
      _subscribed = key;
      paperSocket.send({'type': 'update_symbols', 'symbols': open});
    }
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final updates = <String, dynamic>{};
    switch (msg['type']) {
      case 'initial_snapshot':
      case 'batch':
        updates.addAll(Map<String, dynamic>.from(msg['data'] as Map));
        break;
      case 'update':
        updates[msg['symbol'] as String] = msg['data'];
        break;
      default:
        return;
    }

    var changed = false;
    updates.forEach((symbol, data) {
      final price = (data is Map ? data['ltp'] as num? : null)?.toDouble();
      if (price == null) return;
      final prev = _ltp[symbol];
      if (prev != null && prev != price) {
        _flash[symbol] = price > prev ? 1 : -1;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _flash.remove(symbol));
        });
      }
      _ltp[symbol] = price;
      changed = true;
    });
    if (!changed || !mounted) return;
    setState(() {});
    _checkAutoExit();
  }

  /// Client-side SL/target exit. The server watcher does the same, so
  /// whichever runs first wins and the other finds the row already closed.
  void _checkAutoExit() {
    for (final p in _positions) {
      if (!p.isOpen || _processing.contains(p.id)) continue;
      final price = _ltp[p.symbol];
      if (price == null) continue;
      final reason = p.exitReason(price);
      if (reason != null) _closePosition(p, price, reason);
    }
  }

  Future<void> _closePosition(PaperPosition p, double price, String reason) async {
    _processing.add(p.id);
    final res = await PaperTradingService.close(p.id, price);
    _processing.remove(p.id);
    if (!mounted) return;
    _toast(res.success ? 'Position closed: $reason' : res.message);
    _loadPositions();
  }

  // ---------------------------------------------------------------- search

  void _onSymbolChanged(String value) {
    _selected = null;
    _searchDebounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await PaperTradingService.search(value.trim());
        if (mounted && _symbolCtrl.text.trim() == value.trim()) {
          setState(() => _suggestions = results);
        }
      } catch (_) {}
    });
    setState(() {});
  }

  void _pick(PaperInstrument i) {
    setState(() {
      _selected = i;
      _symbolCtrl.text = i.symbol;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  // ----------------------------------------------------------------- order

  Future<void> _placeOrder() async {
    final instrument = _selected;
    if (instrument == null) {
      _toast('Pick an instrument from the list.');
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _toast('Enter a valid quantity.');
      return;
    }
    final target = _qtyOrNull(_targetCtrl.text);
    final sl = _qtyOrNull(_slCtrl.text);
    if ((_targetCtrl.text.trim().isNotEmpty && (target == null || target <= 0)) ||
        (_slCtrl.text.trim().isNotEmpty && (sl == null || sl <= 0))) {
      _toast('Target and Stop Loss must be greater than zero.');
      return;
    }

    setState(() => _placing = true);
    final shares = instrument.lotSize > 1 ? qty * instrument.lotSize : qty;
    final res = await PaperTradingService.placeOrder(
      instrument: instrument,
      direction: _direction,
      quantity: shares,
      target: target,
      stopLoss: sl,
    );
    if (!mounted) return;
    setState(() => _placing = false);
    _toast(res.message);
    if (res.success) {
      setState(() {
        _selected = null;
        _symbolCtrl.clear();
        _qtyCtrl.clear();
        _targetCtrl.clear();
        _slCtrl.clear();
      });
      _loadPositions();
    }
  }

  double? _qtyOrNull(String s) => double.tryParse(s.trim());

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editTargets(PaperPosition p) async {
    final sl = TextEditingController(text: p.stopLoss?.toString() ?? '');
    final tgt = TextEditingController(text: p.target?.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: Text('Edit ${p.symbol}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(sl, 'Stop Loss', decimal: true),
            const SizedBox(height: 12),
            _field(tgt, 'Target', decimal: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final newSl = double.tryParse(sl.text.trim());
    final newTgt = double.tryParse(tgt.text.trim());
    sl.dispose();
    tgt.dispose();
    if (save != true) return;

    final res = await PaperTradingService.updateTargets(p.id, newSl, newTgt);
    if (!mounted) return;
    _toast(res.success ? 'Updated successfully' : res.message);
    if (res.success) _loadPositions();
  }

  // -------------------------------------------------------------------- UI

  Widget _field(TextEditingController c, String label, {bool decimal = false, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
      style: const TextStyle(color: Colors.white),
      decoration: _deco(label),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPositions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                "Today's Positions",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Icon(Icons.circle, size: 9, color: _connected ? Colors.greenAccent : Colors.redAccent),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingPositions)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
            )
          else if (_positions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No trades today.', style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ..._positions.map(_buildPosition),
        ],
      ),
    );
  }

  Widget _buildOrderCard() {
    final inst = _selected;
    final qtyLabel = inst?.isFno == true ? 'No. of Lots' : 'No. of Shares';
    final isLong = _direction == 'LONG';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Place Order',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _symbolCtrl,
            onChanged: _onSymbolChanged,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white),
            decoration: _deco('Search symbol (e.g. RELIANCE)').copyWith(
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: _suggestions
                    .map(
                      (i) => ListTile(
                        dense: true,
                        title: Text(i.symbol, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: Text(
                          '${i.type}${i.lotSize > 1 ? ' · lot ${i.lotSize}' : ''}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        onTap: () => _pick(i),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dirButton('LONG', Colors.greenAccent)),
              const SizedBox(width: 10),
              Expanded(child: _dirButton('SHORT', Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 12),
          _field(_qtyCtrl, qtyLabel),
          if (inst?.isFno == true && inst!.lotSize > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Lot size ${inst.lotSize} · total ${(int.tryParse(_qtyCtrl.text) ?? 0) * inst.lotSize} qty',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_targetCtrl, 'Target (optional)', decimal: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_slCtrl, 'Stop Loss (optional)', decimal: true)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _placing ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLong ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _placing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isLong ? 'BUY (LONG)' : 'SELL (SHORT)'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Orders fill at the live price during market hours (09:15–15:30 IST). '
            'Open positions are squared off at 15:15.',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _dirButton(String dir, Color color) {
    final active = _direction == dir;
    return GestureDetector(
      onTap: () => setState(() => _direction = dir),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.18) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : Colors.white12),
        ),
        child: Text(
          dir,
          style: TextStyle(color: active ? color : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildPosition(PaperPosition p) {
    final price = _ltp[p.symbol];
    final pnl = p.isOpen ? (price != null ? p.livePnl(price) : null) : p.pnl;
    final pnlColor = pnl == null ? Colors.white54 : (pnl >= 0 ? Colors.greenAccent : Colors.redAccent);
    final flash = _flash[p.symbol];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: flash == null
            ? Colors.white.withOpacity(0.04)
            : (flash > 0 ? Colors.greenAccent : Colors.redAccent).withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.symbol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              _chip(p.direction, p.isLong ? Colors.greenAccent : Colors.redAccent),
              const SizedBox(width: 6),
              _chip(p.status, p.isOpen ? Colors.blueAccent : Colors.white38),
              const Spacer(),
              Text(
                pnl == null ? '—' : '${pnl >= 0 ? '+' : ''}₹${pnl.toStringAsFixed(2)}',
                style: TextStyle(color: pnlColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _kv('Qty', '${p.quantity}'),
              _kv('Entry', '₹${p.entryPrice.toStringAsFixed(2)}'),
              if (p.isOpen) _kv('LTP', price == null ? '—' : '₹${price.toStringAsFixed(2)}'),
              if (!p.isOpen && p.exitPrice != null) _kv('Exit', '₹${p.exitPrice!.toStringAsFixed(2)}'),
              _kv('SL', p.stopLoss == null ? '—' : p.stopLoss!.toStringAsFixed(2)),
              _kv('Target', p.target == null ? '—' : p.target!.toStringAsFixed(2)),
            ],
          ),
          if (p.isOpen) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editTargets(p),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('SL / Target'),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _processing.contains(p.id) || price == null
                      ? null
                      : () => _closePosition(p, price, 'Manual Exit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _kv(String k, String v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$k ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}
