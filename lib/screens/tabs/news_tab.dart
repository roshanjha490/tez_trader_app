import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/sockets.dart';

/// Market news: a live feed over the news socket plus the corporate events
/// calendar (results, dividends, splits...).
class NewsTab extends StatelessWidget {
  const NewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: const [
          TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.white10,
            tabs: [Tab(text: 'Live News'), Tab(text: 'Events Calendar')],
          ),
          Expanded(
            child: TabBarView(children: [_LiveNews(), _EventsCalendar()]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- live news

class _LiveNews extends StatefulWidget {
  const _LiveNews();

  @override
  State<_LiveNews> createState() => _LiveNewsState();
}

class _LiveNewsState extends State<_LiveNews> with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _news = [];
  final Set<String> _seen = {};
  StreamSubscription? _sub;
  StreamSubscription<bool>? _statusSub;
  bool _connected = false;
  bool _hasSnapshot = false;
  String _query = '';
  String? _category;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub = newsSocket.stream.listen(_onMessage);
    _statusSub = newsSocket.statusStream.listen((c) {
      if (mounted) setState(() => _connected = c);
    });
    newsSocket.acquire();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusSub?.cancel();
    newsSocket.release();
    super.dispose();
  }

  List<Map<String, dynamic>> _unseen(dynamic data) {
    final out = <Map<String, dynamic>>[];
    for (final raw in (data as List? ?? const [])) {
      final item = Map<String, dynamic>.from(raw as Map);
      final guid = item['guid']?.toString() ?? item['title']?.toString() ?? '';
      if (guid.isNotEmpty && _seen.add(guid)) out.add(item);
    }
    return out;
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (!mounted) return;

    switch (msg['type']) {
      case 'initial_news_snapshot':
        // Newest batch: replaces whatever was shown (also after a reconnect).
        _seen.clear();
        final items = _unseen(msg['data']);
        setState(() {
          _news
            ..clear()
            ..addAll(items);
          _hasSnapshot = true;
        });
        break;
      case 'news_snapshot_batch':
        // Older batches arrive after the first; append at the bottom.
        final items = _unseen(msg['data']);
        if (items.isNotEmpty) setState(() => _news.addAll(items));
        break;
      default:
        // A live article: prepend.
        if (msg['guid'] != null || msg['title'] != null) {
          final items = _unseen([msg]);
          if (items.isNotEmpty) setState(() => _news.insertAll(0, items));
        }
    }
  }

  String _cat(Map<String, dynamic> n) {
    final c = n['category']?.toString().trim() ?? '';
    return c.isEmpty ? 'General' : c;
  }

  Color _color(String category) {
    const palette = [
      Colors.greenAccent, Colors.lightBlueAccent, Colors.amberAccent,
      Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent, Colors.limeAccent,
    ];
    if (category == 'Result') return Colors.greenAccent;
    if (category == 'General') return Colors.lightBlueAccent;
    return palette[category.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFF) % palette.length];
  }

  String _timeAgo(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categories = (_news.map(_cat).toSet().toList()..sort());
    final q = _query.toLowerCase();
    final visible = _news.where((n) {
      if (_category != null && _cat(n) != _category) return false;
      if (q.isEmpty) return true;
      return [n['title'], n['desc'], n['companyName'], n['tradeSymbol']]
          .any((v) => v?.toString().toLowerCase().contains(q) == true);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search news…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.circle, size: 10, color: _connected ? Colors.greenAccent : Colors.redAccent),
            ],
          ),
        ),
        if (categories.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', _category == null, () => setState(() => _category = null)),
                for (final c in categories)
                  _chip(c.replaceAll('_', ' '), _category == c, () => setState(() => _category = c)),
              ],
            ),
          ),
        Expanded(
          child: !_hasSnapshot
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : visible.isEmpty
                  ? const Center(child: Text('No news found.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, i) => _card(visible[i]),
                    ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: active,
          onSelected: (_) => onTap(),
          selectedColor: Colors.blueAccent.withOpacity(0.35),
          backgroundColor: Colors.white.withOpacity(0.05),
          labelStyle: TextStyle(color: active ? Colors.white : Colors.white60, fontSize: 12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      );

  Widget _card(Map<String, dynamic> n) {
    final cat = _cat(n);
    final color = _color(cat);
    final company = n['companyName']?.toString();
    final desc = n['desc']?.toString();
    final title = n['title']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      // A coloured left accent can't be a per-side Border together with
      // rounded corners (Flutter throws), so it's a clipped strip instead.
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(cat.replaceAll('_', ' '),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(_timeAgo(n['date']?.toString()), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
          if (desc != null && desc.isNotEmpty && desc != title) ...[
            const SizedBox(height: 6),
            Text(desc, maxLines: 4, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.35)),
          ],
          if (company != null && company.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.account_balance, size: 13, color: Colors.white38),
                const SizedBox(width: 5),
                Flexible(child: Text(company, style: const TextStyle(color: Colors.white38, fontSize: 11))),
              ],
            ),
          ],
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

// ------------------------------------------------------------ events calendar

class _EventsCalendar extends StatefulWidget {
  const _EventsCalendar();

  @override
  State<_EventsCalendar> createState() => _EventsCalendarState();
}

class _EventsCalendarState extends State<_EventsCalendar> with AutomaticKeepAliveClientMixin {
  static const _types = ['Results', 'Dividend', 'Split', 'Bonus', 'Rights', 'BuyBack'];

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  String? _type;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get('/events-calendar');
      if (!mounted) return;
      setState(() {
        _events = (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = "Couldn't load the events calendar.";
          _loading = false;
        });
      }
    }
  }

  String _dateKey(Map<String, dynamic> e) {
    final raw = e['eventDate']?.toString() ?? '';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String _prettyDate(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'Results':
        return Colors.greenAccent;
      case 'Dividend':
        return Colors.amberAccent;
      case 'Split':
      case 'Bonus':
        return Colors.purpleAccent;
      case 'Rights':
        return Colors.cyanAccent;
      default:
        return Colors.pinkAccent;
    }
  }

  String _detail(Map<String, dynamic> e) {
    final parts = <String>[];
    if (e['dividend'] != null) parts.add('Dividend ₹${e['dividend']}');
    if (e['ratio'] != null && e['ratio'].toString().isNotEmpty) parts.add('Ratio ${e['ratio']}');
    if (e['oldFv'] != null && e['newFv'] != null) parts.add('FV ₹${e['oldFv']} → ₹${e['newFv']}');
    if (e['price'] != null) parts.add('Price ₹${e['price']}');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final q = _query.toLowerCase();
    final filtered = _events.where((e) {
      if (_type != null && e['eventType'] != _type) return false;
      if (q.isEmpty) return true;
      return [e['symbol'], e['displayName'], e['companyName']]
          .any((v) => v?.toString().toLowerCase().contains(q) == true);
    }).toList()
      ..sort((a, b) => _dateKey(a).compareTo(_dateKey(b)));

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in filtered) {
      grouped.putIfAbsent(_dateKey(e), () => []).add(e);
    }
    final keys = grouped.keys.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search company or symbol…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final t in [null, ..._types])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t ?? 'All'),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: Colors.blueAccent.withOpacity(0.35),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: TextStyle(color: _type == t ? Colors.white : Colors.white60, fontSize: 12),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: keys.isEmpty
              ? const Center(child: Text('No events found.', style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: keys.length,
                    itemBuilder: (context, i) {
                      final key = keys[i];
                      final isToday = key == today;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 6),
                            child: Text(
                              isToday ? 'Today · ${_prettyDate(key)}' : _prettyDate(key),
                              style: TextStyle(
                                color: isToday ? Colors.blueAccent : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          for (final e in grouped[key]!) _eventRow(e),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _eventRow(Map<String, dynamic> e) {
    final type = e['eventType']?.toString() ?? '';
    final color = _typeColor(type);
    final detail = _detail(e);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e['symbol']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(e['companyName']?.toString() ?? e['displayName']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(detail, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(type, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
