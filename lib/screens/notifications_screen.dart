import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/themed_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notifications_service.dart';
import '../services/post_id.dart';
import 'single_post_screen.dart';

/// All / Unread notifications, 15 per page, mark one or all as read. Tapping
/// one marks it read and follows its link (post links open in the app).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const int _pageSize = 15;

  final List<NotificationItem> _items = [];
  final ScrollController _scroll = ScrollController();
  bool _unreadOnly = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _unreadCount = 0;
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
      final res = await NotificationsService.fetch(
        page: page,
        limit: _pageSize,
        unreadOnly: _unreadOnly,
      );
      if (!mounted) return;
      setState(() {
        if (page == 1) _items.clear();
        _items.addAll(res.items);
        _hasMore = res.hasMore;
        _unreadCount = res.unreadCount;
        _page = page;
      });
    } catch (_) {
      if (mounted && page == 1) {
        setState(() => _error = "Couldn't load notifications.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _setFilter(bool unreadOnly) {
    if (_unreadOnly == unreadOnly) return;
    _unreadOnly = unreadOnly;
    _load(1);
  }

  Future<void> _open(NotificationItem n) async {
    if (!n.isRead) {
      setState(() {
        n.isRead = true;
        _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
      });
      try {
        await NotificationsService.markRead(n.id);
      } catch (_) {}
    }

    final postId = postIdFromLink(n.link);
    if (postId != null) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SinglePostScreen(postId: postId)),
      );
    } else if (n.link != null && n.link!.startsWith('http')) {
      await launchUrl(Uri.parse(n.link!), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markAll() async {
    try {
      await NotificationsService.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n.isRead = true;
        }
        _unreadCount = 0;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark all as read.')),
        );
      }
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 30}mo ago';
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: ThemedAppBar(
        title: 'Notifications',
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAll,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: AppBackground(
        underAppBar: true,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _chip('All', !_unreadOnly, () => _setFilter(false)),
                _chip(
                  _unreadCount > 0 ? 'Unread ($_unreadCount)' : 'Unread',
                  _unreadOnly,
                  () => _setFilter(true),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
      ),
    );
  }

  Widget _buildList() {
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
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, color: Colors.white24, size: 44),
            const SizedBox(height: 12),
            Text(
              _unreadOnly ? 'No unread notifications' : 'No notifications yet',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(1),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
            );
          }
          final n = _items[i];
          return InkWell(
            onTap: () => _open(n),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: n.isRead ? Colors.transparent : Colors.blueAccent.withOpacity(0.06),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            color: n.isRead ? Colors.white70 : Colors.blueAccent,
                            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(_timeAgo(n.createdAt), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
