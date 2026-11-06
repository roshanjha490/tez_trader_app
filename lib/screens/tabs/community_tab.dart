import 'package:flutter/material.dart';
import '../../services/initials.dart';
import '../../services/api_client.dart'; // Adjust to your actual API Client
import '../../widgets/create_post_widget.dart';
import '../../widgets/post_comments_widget.dart'; // Custom widget for post actions
import '../../services/token_storage.dart';
import '../../services/jwt_user.dart';
import '../../widgets/post_video.dart';
import '../../widgets/poll_card.dart';
import '../../widgets/create_poll_sheet.dart';
import 'package:dio/dio.dart';
import '../main_shell.dart'; // 1. IMPORT ACTIVETAB HERE!

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab> {
  String _capitalizeName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Trader';

    return name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  // 2. ADD TAB TRACKING STATE
  bool _isActive = false;

  // State
  List<Map<String, dynamic>> _posts = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // Filters
  String _filter = 'latest'; // "latest" | "top" | "highlighted"
  String? _activeTag;

  // Tiered feeds: pro (1) < vip (2) < elite (3). Users can read feeds up to
  // their plan level; the backend enforces the same rule.
  static const List<String> _feeds = ['pro', 'vip', 'elite'];
  String _feed = 'pro';
  bool _locked = false; // current feed is above the user's plan
  UserSession? _me;

  int get _myId => _me?.id ?? 0;
  int get _myLevel => _me?.planLevel ?? 1;

  /// Regular users post only in their own tier; mentors in any tier up to
  /// their plan; admins anywhere (same rules as the portal).
  bool get _canPost {
    final me = _me;
    if (me == null || _locked) return false;
    final feedLevel = UserSession.planLevelOf(_feed);
    if (_filter == 'polls' && !(me.isAdmin || me.isMentor)) return false;
    if (me.isAdmin) return true;
    if (me.isMentor) return feedLevel <= _myLevel;
    return feedLevel == _myLevel;
  }

  bool get _isStaff => _me?.isMentor == true || _me?.isAdmin == true;

  int get _maxChars => (_me?.isMentor == true || _me?.isAdmin == true) ? 1000 : 500;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUser();

    // 3. REMOVED _fetchPosts(reset: true) FROM HERE
    // We let didChangeDependencies handle the initial load instead to prevent duplicate API calls.

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchMorePosts();
      }
    });
  }

  // 4. ADD VISIBILITY LISTENER
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // The Discover Screen is on Tab Index 2
    final isNowActive = ActiveTab.of(context) == 2;

    if (isNowActive && !_isActive) {
      _isActive = true;
      _fetchPosts(reset: true); // Auto-refresh whenever they open the tab!
    } else if (!isNowActive && _isActive) {
      _isActive = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await TokenStorage.getCurrentUser();
    if (!mounted || user == null) return;
    setState(() {
      _me = user;
      _feed = _feeds.contains(user.planName.toLowerCase())
          ? user.planName.toLowerCase()
          : 'pro';
    });
    if (_isActive) _fetchPosts(reset: true);
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
      // Tiered endpoint: only returns approved, non-poll posts of this feed.
      String url = _filter == 'polls'
          ? '/community/polls?page=$_page&feed=$_feed'
          : '/community/plan_posts?page=$_page&filter=$_filter&feed=$_feed';
      if (_activeTag != null && _filter != 'polls') {
        url += '&tag=${Uri.encodeComponent(_activeTag!)}';
      }

      final response = await ApiClient.dio.get(url);

      if (mounted && response.data['success'] == true) {
        final newPosts = List<Map<String, dynamic>>.from(response.data['data']);
        setState(() {
          _locked = false;
          if (reset) {
            _posts = newPosts;
          } else {
            _posts.addAll(newPosts);
          }
          _hasMore = response.data['pagination']?['hasMore'] ?? false;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 403) {
        // Feed above the user's plan: show the upgrade card instead.
        setState(() {
          _locked = true;
          _posts = [];
          _hasMore = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Couldn't load posts. Please try again.";
          _isLoading = false;
        });
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

  // Optimistic UI Like Toggle (Exactly like React)
  Future<void> _toggleLike(int index, dynamic postId) async {
    final bool isCurrentlyLiked = _posts[index]['isLikedByMe'] == true;
    final int currentLikes = _posts[index]['likes'] ?? 0;

    // 1. Optimistic UI Update
    setState(() {
      _posts[index]['isLikedByMe'] = !isCurrentlyLiked;
      _posts[index]['likes'] = isCurrentlyLiked
          ? currentLikes - 1
          : currentLikes + 1;
    });

    try {
      // 2. Network Request
      final res = await ApiClient.dio.post('/community/posts/$postId/like');
      if (res.data['success'] != true) throw Exception("Failed to like");
    } catch (e) {
      // 3. Revert on failure
      if (mounted) {
        setState(() {
          _posts[index]['isLikedByMe'] = isCurrentlyLiked;
          _posts[index]['likes'] = currentLikes;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to toggle like.')));
      }
    }
  }

  // Helpers
  void _setFilter(String newFilter) {
    if (_filter == newFilter) return;
    _filter = newFilter;
    _fetchPosts(reset: true);
  }

  void _setFeed(String feed) {
    if (_feed == feed) return;
    setState(() {
      _feed = feed;
      _activeTag = null;
    });
    _fetchPosts(reset: true);
  }

  void _setTag(String? tag) {
    if (_activeTag == tag) return;
    _activeTag = tag;
    _fetchPosts(reset: true);
  }

  void _openCreatePostModal({EditPostData? existingPost}) async {
    // 1. Fetch the actual logged-in user securely
    final currentUser = _me ?? await TokenStorage.getCurrentUser();

    // Safety check to ensure the widget is still on screen after the await
    if (!mounted) return;

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
                // 2. Inject the real user data dynamically!
                user: {
                  'first_name': currentUser?.firstName ?? 'Trader',
                  'last_name': currentUser?.lastName ?? '',
                  // Note: Change 'profileImage' below to whatever your User model calls the image property
                  'profile_image': currentUser?.profileImage,
                },
                initialData: existingPost,
                maxChars: _maxChars,
                allowVideo: _isStaff,
                // Mentors/admins choose the feed by browsing it; regular
                // users always post to their own tier.
                targetFeed: (_me?.isMentor == true || _me?.isAdmin == true)
                    ? _feed
                    : null,
                onPostCreated: () {
                  Navigator.pop(context);
                  _fetchPosts(reset: true);
                },
                onCancel: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mentors and admins choose between a post (text, images, video) and a
  /// poll; everyone else goes straight to the post composer.
  void _onComposePressed() {
    if (!_isStaff) {
      _openCreatePostModal();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blueAccent),
              title: const Text('New post', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Text, images or a video', style: TextStyle(color: Colors.white38)),
              onTap: () {
                Navigator.pop(context);
                _openCreatePostModal();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined, color: Colors.blueAccent),
              title: const Text('New poll', style: TextStyle(color: Colors.white)),
              subtitle: const Text('2–4 options', style: TextStyle(color: Colors.white38)),
              onTap: () {
                Navigator.pop(context);
                _openCreatePollModal();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCreatePollModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CreatePollSheet(
          targetFeed: _feed,
          maxQuestionChars: _maxChars,
          onCreated: () {
            Navigator.pop(context);
            _fetchPosts(reset: true);
          },
        ),
      ),
    );
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

  // 1. Report Post Modal (Matches your React ReportModal perfectly)
  void _showReportDialog(int postId) {
    String reason = "Spam";
    String comments = "";
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.flag,
                              color: Colors.orangeAccent,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Report Post",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Reason Dropdown
                    const Text(
                      "Reason",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: reason,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white54,
                          ),
                          items:
                              [
                                "Spam",
                                "Scam / Fraud",
                                "Inappropriate Content",
                                "Harassment",
                              ].map((String val) {
                                return DropdownMenuItem<String>(
                                  value: val,
                                  child: Text(val),
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => reason = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Comments Textarea
                    const Text(
                      "Additional Comments",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Tell us more...",
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                        onChanged: (val) => comments = val,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setDialogState(() => isSubmitting = true);

                                try {
                                  final res = await ApiClient.dio.post(
                                    '/community/posts/$postId/report',
                                    data: {
                                      'reason': reason,
                                      'comments': comments,
                                    },
                                  );

                                  if (mounted) {
                                    Navigator.pop(context); // Close dialog
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res.data['message'] ??
                                              'Report submitted.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to submit report.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Submit Report",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Instagram-Style Bottom Sheet
  void _showPostOptions(Map<String, dynamic> post, bool isCreator) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B0F19), // Match the dark theme
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag indicator pill
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              if (isCreator) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text(
                    'Edit Post',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the sheet
                    _openCreatePostModal(
                      existingPost: EditPostData(
                        id: post['id'],
                        content: post['content'] ?? '',
                        images: List<String>.from(post['images'] ?? []),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.redAccent, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the sheet
                    _confirmAndDeletePost(post['id'] as int);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    'Block / Report',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the sheet
                    _showReportDialog(post['id'] as int);
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 2. Delete Post Logic (Optimistic UI)
  Future<void> _confirmAndDeletePost(int postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text("Delete Post", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this post? This action cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Optimistic Delete
    final previousPosts = List<Map<String, dynamic>>.from(_posts);
    setState(() {
      _posts.removeWhere((p) => p['id'] == postId);
    });

    try {
      final res = await ApiClient.dio.delete('/community/posts/$postId');
      if (res.data['success'] != true) throw Exception(res.data['message']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      // Revert if API fails
      if (mounted) {
        setState(() => _posts = previousPosts);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete post. Restored to feed.'),
          ),
        );
      }
    }
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canPost
          ? FloatingActionButton(
              onPressed: _onComposePressed,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Feed (tier) selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _feeds.map((f) {
              final level = UserSession.planLevelOf(f);
              final locked = level > _myLevel;
              final active = _feed == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (locked)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.lock, size: 12, color: Colors.white54),
                        ),
                      Text(f.toUpperCase()),
                    ],
                  ),
                  selected: active,
                  onSelected: (_) => _setFeed(f),
                  selectedColor: Colors.blueAccent.withOpacity(0.35),
                  backgroundColor: Colors.white.withOpacity(0.05),
                  labelStyle: TextStyle(
                    color: active ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Filter Toggle (Pinned / Latest / Top Rated / Polls), centred
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
                  title: 'Pinned',
                  isActive: _filter == 'highlighted',
                  onTap: () => _setFilter('highlighted'),
                ),
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
                _FilterButton(
                  title: 'Polls',
                  isActive: _filter == 'polls',
                  onTap: () => _setFilter('polls'),
                ),
              ],
            ),
          ),

          // Active Tag Indicator
          if (_activeTag != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                      ),
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
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
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
    if (_locked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 44),
              const SizedBox(height: 16),
              Text(
                '${_feed.toUpperCase()} community is locked',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are on the ${(_me?.planName ?? 'pro').toUpperCase()} plan. '
                'Upgrade your plan to access this feed.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
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
              child: const Text("Try again"),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Text(_filter == 'polls' ? "No polls yet." : "No posts yet.", style: const TextStyle(color: Colors.white54)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPosts(reset: true),
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF0B0F19),
      child: ListView.builder(
        controller: _scrollController,
        // AlwaysScrollableScrollPhysics ensures pull-to-refresh works even if the list is short
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
            );
          }
          return _buildPostCard(_posts[index], index);
        },
      ),
    );
  }

  Widget _buildPollItem(Map<String, dynamic> post) {
    final user = post['user'] ?? {};
    final poll = post['poll'];
    final userType = user['user_type']?.toString();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                radius: 16,
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                backgroundImage: user['avatar'] != null ? NetworkImage(user['avatar']) : null,
                child: user['avatar'] == null
                    ? Text(
                        initialsFor(user['name']?.toString()),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _capitalizeName(user['name']),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (userType == 'admin' || userType == 'mentor') ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, size: 15,
                    color: userType == 'admin' ? Colors.amberAccent : Colors.greenAccent),
              ],
              const Spacer(),
              Text(_timeAgo(post['created_at']),
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          if (poll is Map)
            PollCard(
              key: ValueKey('poll_${post['id']}'),
              postId: (post['id'] as num).toInt(),
              question: post['content']?.toString() ?? '',
              poll: Map<String, dynamic>.from(poll),
            ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    if (_filter == 'polls') return _buildPollItem(post);
    final user = post['user'] ?? {};
    final tags = post['tags'] as List<dynamic>? ?? [];
    final images = post['images'] as List<dynamic>? ?? [];
    final isCreator = _myId != 0 && _myId.toString() == user['id']?.toString();
    final videoUrl = post['video_url'] as String?;
    final userType = user['user_type']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                backgroundImage: user['avatar'] != null
                    ? NetworkImage(user['avatar'])
                    : null,
                child: user['avatar'] == null
                    ? Text(
                        initialsFor(user['name']?.toString()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _capitalizeName(user['name']),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        // Gold tick for admins, green for mentors.
                        if (userType == 'admin' || userType == 'mentor') ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: userType == 'admin'
                                ? Colors.amberAccent
                                : Colors.greenAccent,
                          ),
                        ],
                        if (post['isHighlighted'] == true) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 14, color: Colors.amberAccent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(post['created_at']),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                onPressed: () => _showPostOptions(post, isCreator),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content (Expandable)
          _ExpandablePostContent(content: post['content'] ?? ''),

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (t) => GestureDetector(
                      onTap: () => _setTag(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${t.toString().toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          // Video (mentors/admins only)
          if (videoUrl != null && videoUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            PostVideo(url: videoUrl),
          ],

          // Images
          if (images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImageGrid(images.cast<String>()),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Footer Actions
          Row(
            children: [
              // Like Button
              GestureDetector(
                onTap: () => _toggleLike(index, post['id']),
                child: Row(
                  children: [
                    Icon(
                      post['isLikedByMe'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: post['isLikedByMe'] == true
                          ? Colors.pinkAccent
                          : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post['likes'] ?? 0}',
                      style: TextStyle(
                        color: post['isLikedByMe'] == true
                            ? Colors.pinkAccent
                            : Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Comment Button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled:
                        true, // Allows sheet to take up more than 50% of screen
                    backgroundColor: Colors
                        .transparent, // Transparent so we can see our custom rounded corners
                    builder: (context) {
                      // Padding viewInsets handles the keyboard sliding up!
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: FractionallySizedBox(
                          heightFactor:
                              0.85, // Takes up 85% of the screen height
                          child: PostCommentsWidget(
                            postId: post['id'],
                            currentUserId: _myId,
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post['comments'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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

  // Smart Image Grid Logic
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
        childAspectRatio: 1, // Square blocks
      ),
      itemCount: images.length > 4 ? 4 : images.length, // Max 4 previews
      itemBuilder: (context, index) {
        return _ImageTile(url: images[index]);
      },
    );
  }
}

// ==========================================
// UTILITY WIDGETS (Expandable Text, Buttons)
// ==========================================

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          overflow: _isExpanded || !isLong
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (isLong)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? "Read less" : "Read more",
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Clickable Image Tile for Grid
class _ImageTile extends StatelessWidget {
  final String url;

  const _ImageTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Open Full Screen Image Viewer
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
                  top: 0,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
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