import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'post_comments_widget.dart';
import 'post_video.dart';

/// Read-only post card (author + badge, text, tags, video, images, like and
/// comment) for lists that don't need the full feed card's edit/delete/report
/// menu, such as a mentor's profile.
class SimplePostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final int currentUserId;

  /// Optional tier chip (PRO / VIP / ELITE), shown when the list mixes tiers.
  final String? planName;

  const SimplePostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    this.planName,
  });

  @override
  State<SimplePostCard> createState() => _SimplePostCardState();
}

class _SimplePostCardState extends State<SimplePostCard> {
  late Map<String, dynamic> _post;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
  }

  String _timeAgo(String? iso) {
    final date = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (date == null) return 'just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 30}mo ago';
  }

  Future<void> _toggleLike() async {
    final liked = _post['isLikedByMe'] == true;
    final likes = (_post['likes'] as num?)?.toInt() ?? 0;
    setState(() {
      _post['isLikedByMe'] = !liked;
      _post['likes'] = liked ? likes - 1 : likes + 1;
    });
    try {
      await ApiClient.dio.post('/community/posts/${_post['id']}/like');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post['isLikedByMe'] = liked;
        _post['likes'] = likes;
      });
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: PostCommentsWidget(
            postId: (_post['id'] as num).toInt(),
            currentUserId: widget.currentUserId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(_post['user'] as Map? ?? {});
    final userType = user['user_type']?.toString();
    final name = (user['name']?.toString() ?? '').trim();
    final tags = (_post['tags'] as List?) ?? const [];
    final images = (_post['images'] as List?)?.cast<String>() ?? const <String>[];
    final videoUrl = _post['video_url'] as String?;
    final liked = _post['isLikedByMe'] == true;
    final plan = widget.planName ?? _post['plan_name']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                backgroundImage: user['avatar'] != null ? NetworkImage(user['avatar']) : null,
                child: user['avatar'] == null
                    ? Text(
                        name.isEmpty ? 'U' : name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name.isEmpty ? 'Trader' : name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (userType == 'admin' || userType == 'mentor') ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 15,
                            color: userType == 'admin' ? Colors.amberAccent : Colors.greenAccent,
                          ),
                        ],
                      ],
                    ),
                    Text(_timeAgo(_post['created_at']?.toString()),
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (plan != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    plan.toUpperCase(),
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _post['content']?.toString() ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: tags
                  .map((t) => Text(
                        t.toString().toUpperCase(),
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ))
                  .toList(),
            ),
          ],
          if (videoUrl != null && videoUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            PostVideo(url: videoUrl),
          ],
          for (final url in images) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? Colors.pinkAccent : Colors.white54,
                      size: 19,
                    ),
                    const SizedBox(width: 6),
                    Text('${_post['likes'] ?? 0}',
                        style: TextStyle(color: liked ? Colors.pinkAccent : Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              GestureDetector(
                onTap: _openComments,
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 19),
                    const SizedBox(width: 6),
                    Text('${_post['comments'] ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
