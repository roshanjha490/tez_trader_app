import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/themed_app_bar.dart';

import '../services/api_client.dart';
import '../services/initials.dart';
import '../services/token_storage.dart';
import '../widgets/simple_post_card.dart';
import 'single_post_screen.dart';

/// Mentor profile: cover, avatar, plan, joined date, then Posts and Replies
/// tabs. Only tiers the viewer can read are returned by the backend.
class MentorProfileScreen extends StatefulWidget {
  final int mentorId;

  const MentorProfileScreen({super.key, required this.mentorId});

  @override
  State<MentorProfileScreen> createState() => _MentorProfileScreenState();
}

class _MentorProfileScreenState extends State<MentorProfileScreen> {
  Map<String, dynamic>? _mentor;
  bool _loading = true;
  String? _error;
  int _myId = 0;

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
      _myId = (await TokenStorage.getCurrentUser())?.id ?? 0;
      final res = await ApiClient.dio.get('/community/mentors/${widget.mentorId}');
      if (!mounted) return;
      setState(() {
        _mentor = Map<String, dynamic>.from(res.data['data'] as Map);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = "Couldn't load this mentor.";
          _loading = false;
        });
      }
    }
  }

  String _joined(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Joined ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const ThemedAppBar(title: 'Mentor'),
      body: AppBackground(underAppBar: true, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    final m = _mentor;
    if (_error != null || m == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Mentor not found.', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final name = (m['name']?.toString() ?? '').trim();
    final cover = m['cover_image'] as String?;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    // No cover photo: paint the portal's emerald-to-blue banner.
                    gradient: cover == null || cover.isEmpty
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.emeraldGlow.withOpacity(0.55),
                              AppColors.blueGlow.withOpacity(0.45),
                            ],
                          )
                        : null,
                    image: cover != null && cover.isNotEmpty
                        ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                        : null,
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 62,
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.background,
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.greenAccent.withOpacity(0.25),
                      backgroundImage: m['avatar'] != null ? NetworkImage(m['avatar']) : null,
                      child: m['avatar'] == null
                          ? Text(
                              initialsFor(name, fallback: 'M'),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: Colors.greenAccent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (m['plan_name'] != null) m['plan_name'].toString().toUpperCase(),
                      _joined(m['joined_at']?.toString()),
                      '${m['total_posts'] ?? 0} posts',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.white10,
            tabs: [Tab(text: 'Posts'), Tab(text: 'Replies')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                PagedApiList(
                  path: '/community/mentors/${widget.mentorId}/posts',
                  emptyText: 'No posts you can see yet.',
                  itemBuilder: (item) => SimplePostCard(post: item, currentUserId: _myId),
                ),
                PagedApiList(
                  path: '/community/mentors/${widget.mentorId}/replies',
                  emptyText: 'No replies you can see yet.',
                  itemBuilder: (item) => ReplyCard(reply: item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paged list shared by the Posts and Replies tabs.
class PagedApiList extends StatefulWidget {
  final String path;
  final String emptyText;
  final Widget Function(Map<String, dynamic> item) itemBuilder;

  const PagedApiList({required this.path, required this.emptyText, required this.itemBuilder});

  @override
  State<PagedApiList> createState() => _PagedApiListState();
}

class _PagedApiListState extends State<PagedApiList> with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _items = [];
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final res = await ApiClient.dio.get(widget.path, queryParameters: {'page': page, 'limit': 10});
      if (!mounted) return;
      final data = (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        if (page == 1) _items.clear();
        _items.addAll(data);
        _hasMore = res.data['pagination']?['hasMore'] == true;
        _page = page;
      });
    } catch (_) {
      if (mounted && page == 1) setState(() => _error = "Couldn't load.");
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
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    if (_error != null) {
      return Center(
        child: ElevatedButton(onPressed: () => _load(1), child: Text('$_error Tap to retry')),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(widget.emptyText, style: const TextStyle(color: Colors.white54)));
    }
    return RefreshIndicator(
      onRefresh: () => _load(1),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
            );
          }
          return widget.itemBuilder(_items[i]);
        },
      ),
    );
  }
}

class ReplyCard extends StatelessWidget {
  final Map<String, dynamic> reply;

  const ReplyCard({required this.reply});

  @override
  Widget build(BuildContext context) {
    final postId = (reply['post_id'] as num?)?.toInt();
    return GestureDetector(
      onTap: postId == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SinglePostScreen(postId: postId)),
              ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${reply['replying_to'] ?? ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                if (reply['plan_name'] != null)
                  Text(
                    reply['plan_name'].toString().toUpperCase(),
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reply['content']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
            if ((reply['post_content']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  reply['post_content'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
