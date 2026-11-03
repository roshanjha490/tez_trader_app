import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../mentor_profile_screen.dart';

/// Grid-style list of mentors, oldest first, 12 per page with "load more".
class MentorsTab extends StatefulWidget {
  const MentorsTab({super.key});

  @override
  State<MentorsTab> createState() => _MentorsTabState();
}

class _MentorsTabState extends State<MentorsTab> {
  final List<Map<String, dynamic>> _mentors = [];
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(1);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
          _hasMore &&
          !_loadingMore &&
          !_loading) {
        _load(_page + 1);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    setState(() {
      if (page == 1) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final res = await ApiClient.dio.get('/community/mentors', queryParameters: {'page': page, 'limit': 12});
      if (!mounted) return;
      final data = (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        if (page == 1) _mentors.clear();
        _mentors.addAll(data);
        _hasMore = res.data['pagination']?['hasMore'] == true;
        _page = page;
      });
    } catch (_) {
      if (mounted && page == 1) setState(() => _error = "Couldn't load mentors.");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ElevatedButton(onPressed: () => _load(1), child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_mentors.isEmpty) {
      return const Center(child: Text('No mentors yet.', style: TextStyle(color: Colors.white54)));
    }

    return RefreshIndicator(
      onRefresh: () => _load(1),
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: _mentors.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _mentors.length) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          final m = _mentors[i];
          final name = (m['name']?.toString() ?? '').trim();
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MentorProfileScreen(mentorId: (m['id'] as num).toInt())),
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.greenAccent.withOpacity(0.2),
                    backgroundImage: m['avatar'] != null ? NetworkImage(m['avatar']) : null,
                    child: m['avatar'] == null
                        ? Text(
                            name.isEmpty ? 'M' : name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name.isEmpty ? 'Mentor' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 15, color: Colors.greenAccent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m['total_posts'] ?? 0} posts',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
