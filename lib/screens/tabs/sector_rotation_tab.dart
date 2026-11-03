import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/sockets.dart';

/// Sector Rotation board, mirroring the portal: NIFTY alignment, sectors
/// ranked by strength with rotation arrows, and the selection-logic scanner
/// (signals) for the chosen sector.
class SectorRotationTab extends StatefulWidget {
  const SectorRotationTab({super.key});

  @override
  State<SectorRotationTab> createState() => _SectorRotationTabState();
}

class _SectorRotationTabState extends State<SectorRotationTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _state;
  StreamSubscription? _sub;
  StreamSubscription<bool>? _statusSub;
  bool _connected = false;
  bool _onlyStrongWeak = true;
  String? _selected; // sector name, null = all

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = rotationSocket.stream.listen((raw) {
      try {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        if (msg['type'] == 'sector_rotation' && mounted) {
          setState(() => _state = Map<String, dynamic>.from(msg['data'] as Map));
        }
      } catch (_) {}
    });
    _statusSub = rotationSocket.statusStream.listen((c) {
      if (mounted) setState(() => _connected = c);
    });
    rotationSocket.acquire();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusSub?.cancel();
    rotationSocket.release();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  List<Map<String, dynamic>> _list(String key) =>
      ((_state?[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  String _fmtPct(num? v) => v == null ? '-' : '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

  Color _pctColor(num? v) =>
      v == null || v == 0 ? Colors.white38 : (v > 0 ? Colors.greenAccent : Colors.redAccent);

  Color _statusColor(String? s) =>
      s == 'STRONG' ? Colors.greenAccent : (s == 'WEAK' ? Colors.redAccent : Colors.white30);

  Widget _strengthBar(int strength, String? status) {
    final color = _statusColor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        10,
        (i) => Container(
          width: 5,
          height: 10,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < strength ? color : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = _state;
    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final allRows = _list('sectors');
    final rows = _onlyStrongWeak
        ? allRows.where((r) => r['status'] == 'STRONG' || r['status'] == 'WEAK').toList()
        : allRows;
    final signals = _list('signals')
        .where((s) => _selected == null || ((s['sectors'] as List?) ?? const []).contains(_selected))
        .toList();
    final counts = <String, int>{};
    for (final s in _list('signals')) {
      for (final sec in (s['sectors'] as List? ?? const [])) {
        counts[sec.toString()] = (counts[sec.toString()] ?? 0) + 1;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            const Icon(Icons.radar, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Sector Rotation',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.circle, size: 9, color: _connected ? Colors.greenAccent : Colors.redAccent),
            const Spacer(),
            Text(state['bar_time']?.toString() ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Early access: still being refined. Trade with caution.',
          style: TextStyle(color: Colors.amberAccent, fontSize: 11),
        ),
        const SizedBox(height: 12),
        _niftyCard(Map<String, dynamic>.from((state['nifty'] as Map?) ?? {})),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _onlyStrongWeak,
              onChanged: (v) => setState(() => _onlyStrongWeak = v ?? true),
              visualDensity: VisualDensity.compact,
            ),
            const Text('Strong / Weak only', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No strong or weak sectors right now.', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...rows.map((r) => _sectorRow(r, counts[r['name']] ?? 0)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'SCANNER — ${_selected ?? 'ALL SECTORS'}',
                style: const TextStyle(
                    color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            if (_selected != null)
              TextButton(onPressed: () => setState(() => _selected = null), child: const Text('Show all')),
          ],
        ),
        const SizedBox(height: 6),
        if (signals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No signals yet', style: TextStyle(color: Colors.white54))),
          )
        else
          ...signals.map(_signalRow),
      ],
    );
  }

  Widget _niftyCard(Map<String, dynamic> nifty) {
    final align = nifty['align']?.toString();
    final alignColor =
        align == 'UP' ? Colors.greenAccent : (align == 'DOWN' ? Colors.redAccent : Colors.amberAccent);
    final pct = (nifty['pct'] as num?);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Text('NF', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('NIFTY 50', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Text(
            '${nifty['status'] ?? '-'} · ${align ?? '-'}',
            style: TextStyle(color: alignColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Text(_fmtPct(pct),
              style: TextStyle(color: _pctColor(pct), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _sectorRow(Map<String, dynamic> r, int signalCount) {
    final name = r['name']?.toString() ?? '';
    final selected = _selected == name;
    final status = r['status']?.toString();
    final strength = (r['strength'] as num?)?.toInt() ?? 0;
    final score = (r['score'] as num?)?.toDouble();
    final source = r['source']?.toString() ?? '';
    final combined = r['combined']?.toString() ?? '-';
    final dir = r['rotation_dir']?.toString();

    return GestureDetector(
      onTap: () => setState(() => _selected = selected ? null : name),
      child: Opacity(
        opacity: status == 'NEUTRAL' ? 0.6 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? Colors.blueAccent.withOpacity(0.12) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.blueAccent : Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${r['rank'] ?? ''}',
                        style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 12)),
                  ),
                  Flexible(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  if (signalCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$signalCount',
                          style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  Text(_fmtPct(r['pct'] as num?),
                      style: TextStyle(
                          color: _pctColor(r['pct'] as num?), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 22, top: 2),
                child: Text(
                  source == 'BASKET' ? 'Stock basket' : source.replaceAll('_', ' '),
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 22),
                  _strengthBar(strength, status),
                  const SizedBox(width: 8),
                  Text(score?.toStringAsFixed(1) ?? '-',
                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
                  const Spacer(),
                  Text('1H ${_fmtPct(r['momentum_1h'] as num?)}',
                      style: TextStyle(color: _pctColor(r['momentum_1h'] as num?), fontSize: 11)),
                  const SizedBox(width: 10),
                  if (combined != '-')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (combined == 'PLUS' ? Colors.greenAccent : Colors.redAccent).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(combined,
                          style: TextStyle(
                              color: combined == 'PLUS' ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 8),
                  if (dir == 'UP')
                    const Icon(Icons.north_east, size: 16, color: Colors.greenAccent)
                  else if (dir == 'DOWN')
                    const Icon(Icons.south_east, size: 16, color: Colors.redAccent)
                  else
                    const Icon(Icons.remove, size: 14, color: Colors.white24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalRow(Map<String, dynamic> sig) {
    final isBuy = sig['signal'] == 'BUY';
    final color = isBuy ? Colors.greenAccent : Colors.redAccent;
    final phase = sig['phase']?.toString() ?? '';
    final sectors = ((sig['sectors'] as List?) ?? const []).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(sig['symbol']?.toString() ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        Text(isBuy ? '▲ BULLISH' : '▼ BEARISH',
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              children: [
                                TextSpan(text: '${sig['time'] ?? ''} · '),
                                TextSpan(
                                  text: phase,
                                  style: TextStyle(
                                      color: phase == 'MOMENTUM' ? Colors.orangeAccent : Colors.lightBlueAccent),
                                ),
                                if (_selected == null) TextSpan(text: '  $sectors'),
                              ],
                            ),
                          ),
                        ),
                        Text(_fmtPct(sig['pct_change'] as num?),
                            style: TextStyle(
                                color: _pctColor(sig['pct_change'] as num?),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
