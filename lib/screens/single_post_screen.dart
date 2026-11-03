import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_background.dart';

import '../services/api_client.dart';
import '../services/token_storage.dart';
import '../widgets/post_comments_widget.dart';
import '../widgets/post_video.dart';

/// One post opened from a notification link. Mirrors the portal's
/// `/community/post/[code]` page, including the "Restricted Access" card
/// when the post belongs to a tier above the viewer's plan.
class SinglePostScreen extends StatefulWidget {
  final int postId;

  const SinglePostScreen({super.key, required this.postId});

  @override
  State<SinglePostScreen> createState() => _SinglePostScreenState();
}

class _SinglePostScreenState extends State<SinglePostScreen> {
  Map<String, dynamic>? _post;
  bool _loading = true;
  String? _error;
  String? _restrictedTier; // set when the server answers 403 with plan_name
  int _myId = 0;
  String _myPlan = 'pro';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _restrictedTier = null;
    });
    try {
      final user = await TokenStorage.getCurrentUser();
      _myId = user?.id ?? 0;
      _myPlan = user?.planName ?? 'pro';

      final res = await ApiClient.dio.get('/community/posts/${widget.postId}');
      if (!mounted) return;
      setState(() {
        _post = Map<String, dynamic>.from(res.data['data'] as Map);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _loading = false;
        if (e.response?.statusCode == 403 && data is Map && data['plan_name'] != null) {
          _restrictedTier = data['plan_name'].toString();
        } else if (e.response?.statusCode == 404) {
          _error = 'This post is no longer available.';
        } else {
          _error = "Couldn't load this post. Please try again.";
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "Couldn't load this post. Please try again.";
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    final liked = post['isLikedByMe'] == true;
    final likes = (post['likes'] as num?)?.toInt() ?? 0;
    setState(() {
      post['isLikedByMe'] = !liked;
      post['likes'] = liked ? likes - 1 : likes + 1;
    });
    try {
      await ApiClient.dio.post('/community/posts/${widget.postId}/like');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        post['isLikedByMe'] = liked;
        post['likes'] = likes;
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
          child: PostCommentsWidget(postId: widget.postId, currentUserId: _myId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Post', style: TextStyle(color: Colors.white)),
      ),
      body: AppBackground(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    if (_restrictedTier != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 44),
              const SizedBox(height: 16),
              const Text(
                'Restricted Access',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You are on the ${_myPlan.toUpperCase()} plan, but this post is in '
                'the ${_restrictedTier!.toUpperCase()} community. Upgrade your plan to view it.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
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

    final post = _post!;
    final user = Map<String, dynamic>.from(post['user'] as Map? ?? {});
    final userType = user['user_type']?.toString();
    final images = (post['images'] as List?)?.cast<String>() ?? const <String>[];
    final tags = (post['tags'] as List?) ?? const [];
    final videoUrl = post['video_url'] as String?;
    final liked = post['isLikedByMe'] == true;
    final name = (user['name']?.toString() ?? '').trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              backgroundImage: user['avatar'] != null ? NetworkImage(user['avatar']) : null,
              child: user['avatar'] == null
                  ? Text(
                      name.isEmpty ? 'U' : name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name.isEmpty ? 'Trader' : name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (userType == 'admin' || userType == 'mentor') ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: userType == 'admin' ? Colors.amberAccent : Colors.greenAccent,
                    ),
                  ],
                ],
              ),
            ),
            if (post['plan_name'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  post['plan_name'].toString().toUpperCase(),
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SelectableText(
          post['content']?.toString() ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map((t) => Text(
                      t.toString().toUpperCase(),
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),
        ],
        if (videoUrl != null && videoUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          PostVideo(url: videoUrl),
        ],
        for (final url in images) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Row(
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.pinkAccent : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${post['likes'] ?? 0}',
                    style: TextStyle(color: liked ? Colors.pinkAccent : Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: _openComments,
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 20),
                  const SizedBox(width: 6),
                  Text('${post['comments'] ?? 0}', style: const TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
