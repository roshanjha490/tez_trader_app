import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../widgets/post_comments_widget.dart';
import '../widgets/create_post_widget.dart';

class SelfPostFeed extends StatefulWidget {
  final dynamic currentUserId;

  const SelfPostFeed({
    super.key,
    required this.currentUserId,
  });

  @override
  State<SelfPostFeed> createState() => _SelfPostFeedState();
}

class _SelfPostFeedState extends State<SelfPostFeed> {
  static const _accentColor = Color(0xFF6C63FF);
  static const _cardColor = Color(0xFF1E1E2A);

  List<Map<String, dynamic>> _posts = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // Filters
  String _filter = 'latest'; // "latest" | "top"
  String? _activeTag;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPosts(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================
  // API LOGIC
  // ==========================================

  Future<void> _fetchPosts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final queryParams = {
        'page': _page,
        'filter': _filter,
        if (widget.currentUserId != null) 'userId': widget.currentUserId.toString(),
        if (_activeTag != null) 'tag': _activeTag,
      };

      final response = await ApiClient.dio.get(
        '/community/posts/userId/',
        queryParameters: queryParams,
      );

      if (mounted && response.data['success'] != false) {
        final List<dynamic> rawData = response.data['data'] ?? [];
        final newPosts = rawData.cast<Map<String, dynamic>>();

        setState(() {
          if (reset) {
            _posts = newPosts;
          } else {
            _posts.addAll(newPosts);
          }
          _hasMore = response.data['pagination']?['hasMore'] ?? false;
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['message'] ?? "Failed to load posts");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Couldn't load posts. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    await _fetchPosts(reset: false);
    setState(() => _isLoadingMore = false);
  }

  // Optimistic UI Like Toggle
  Future<void> _toggleLike(int index, dynamic postId) async {
    final bool isCurrentlyLiked = _posts[index]['isLikedByMe'] == true;
    final int currentLikes = _posts[index]['likes'] ?? 0;

    setState(() {
      _posts[index]['isLikedByMe'] = !isCurrentlyLiked;
      _posts[index]['likes'] = isCurrentlyLiked ? currentLikes - 1 : currentLikes + 1;
    });

    try {
      final res = await ApiClient.dio.post('/community/posts/$postId/like');
      if (res.data['success'] == false) throw Exception();
    } catch (e) {
      if (mounted) {
        setState(() {
          _posts[index]['isLikedByMe'] = isCurrentlyLiked;
          _posts[index]['likes'] = currentLikes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to toggle like.')),
        );
      }
    }
  }

  // Delete Post Logic with Confirmation & Optimistic UI
  Future<void> _confirmAndDeletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        title: const Text("Delete Post", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this post? This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final previousPosts = List<Map<String, dynamic>>.from(_posts);
    setState(() {
      _posts.removeWhere((p) => p['id'] == postId);
    });

    try {
      final res = await ApiClient.dio.delete('/community/posts/$postId');
      if (res.data['success'] == false) throw Exception(res.data['message']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _posts = previousPosts);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete post. Restored to feed.')),
        );
      }
    }
  }

  void _openEditPostModal(Map<String, dynamic> post) {
    final user = post['user'] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Wrap(
            children: [
              CreatePostWidget(
                user: {
                  'first_name': user['name'] ?? 'Trader',
                  'last_name': '',
                  'profile_image': user['avatar'],
                },
                initialData: EditPostData(
                  id: post['id'],
                  content: post['content'] ?? '',
                  images: List<String>.from(post['images'] ?? []),
                ),
                onPostCreated: () {
                  Navigator.pop(context);
                  _fetchPosts(reset: true);
                },
                onCancel: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPostOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Edit Post', style: TextStyle(color: Colors.white, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _openEditPostModal(post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Post', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAndDeletePost(post['id'] as int);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _setFilter(String newFilter) {
    if (_filter == newFilter) return;
    _filter = newFilter;
    _fetchPosts(reset: true);
  }

  void _setTag(String? tag) {
    if (_activeTag == tag) return;
    _activeTag = tag;
    _fetchPosts(reset: true);
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return "just now";
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return "just now";
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}hr ago";
    if (diff.inDays < 30) return "${diff.inDays}d ago";
    return "${diff.inDays ~/ 30}mo ago";
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildFeed()),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterButton(
                      title: 'Latest',
                      isActive: _filter == 'latest',
                      onTap: () => _setFilter('latest'),
                    ),
                    _FilterButton(
                      title: 'Top Rated',
                      isActive: _filter == 'top',
                      onTap: () => _setFilter('top'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_activeTag != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accentColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: _accentColor, fontSize: 13),
                      children: [
                        const TextSpan(text: 'Filtering by '),
                        TextSpan(
                          text: _activeTag!.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _setTag(null),
                    child: const Icon(Icons.close, size: 16, color: _accentColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _accentColor));
    }

    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchPosts(reset: true),
              style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
              child: const Text("Try again"),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return const Center(
        child: Text("No posts created yet.", style: TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPosts(reset: true),
      color: _accentColor,
      backgroundColor: _cardColor,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator(color: _accentColor)),
            );
          }
          return _buildPostCard(_posts[index], index);
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final user = post['user'] ?? {};
    final tags = post['tags'] as List<dynamic>? ?? [];
    final images = post['images'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: Colors.white10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _accentColor.withOpacity(0.2),
                backgroundImage: user['avatar'] != null ? NetworkImage(user['avatar']) : null,
                child: user['avatar'] == null
                    ? Text(
                        (user['name']?.isNotEmpty == true ? user['name'][0] : 'U').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'Trader',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(post['created_at']),
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                onPressed: () => _showPostOptions(post),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          _ExpandablePostContent(content: post['content'] ?? ''),

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) => GestureDetector(
                onTap: () => _setTag(t.toString()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    border: Border.all(color: _accentColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t.toString().toUpperCase(),
                    style: const TextStyle(color: _accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              )).toList(),
            ),
          ],

          // Images
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImageGrid(images.cast<String>()),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleLike(index, post['id']),
                child: Row(
                  children: [
                    Icon(
                      post['isLikedByMe'] == true ? Icons.favorite : Icons.favorite_border,
                      color: post['isLikedByMe'] == true ? Colors.pinkAccent : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post['likes'] ?? 0}',
                      style: TextStyle(
                        color: post['isLikedByMe'] == true ? Colors.pinkAccent : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: FractionallySizedBox(
                          heightFactor: 0.85,
                          child: PostCommentsWidget(
                            postId: post['id'],
                            currentUserId: widget.currentUserId ?? 0,
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${post['comments'] ?? 0}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.length == 1) {
      return _ImageTile(url: images[0]);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length > 4 ? 4 : images.length,
      itemBuilder: (context, index) {
        return _ImageTile(url: images[index]);
      },
    );
  }
}

// Helper Widgets
class _FilterButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ExpandablePostContent extends StatefulWidget {
  final String content;

  const _ExpandablePostContent({required this.content});

  @override
  State<_ExpandablePostContent> createState() => _ExpandablePostContentState();
}

class _ExpandablePostContentState extends State<_ExpandablePostContent> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final int newlines = '\n'.allMatches(widget.content).length;
    final bool isLong = newlines > 4 || widget.content.length > 250;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content,
          maxLines: _isExpanded || !isLong ? null : 4,
          overflow: _isExpanded || !isLong ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
        if (isLong)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? "Read less" : "Read more",
                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String url;

  const _ImageTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, fit: BoxFit.cover, width: double.infinity),
      ),
    );
  }
}