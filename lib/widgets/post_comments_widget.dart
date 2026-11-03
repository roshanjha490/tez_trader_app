import 'package:flutter/material.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_client.dart';
import '../../services/token_storage.dart';

class PostCommentsWidget extends StatefulWidget {
  final int postId;
  final int currentUserId;

  const PostCommentsWidget({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<PostCommentsWidget> createState() => _PostCommentsWidgetState();
}

class _PostCommentsWidgetState extends State<PostCommentsWidget> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _submitting = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int? _replyingTo;

  // Regular users can write 30-character comments; mentors and admins 1000
  // (same limits the backend enforces).
  int _maxChars = 30;

  // Images attached to the comment being written (max 5, JPG/PNG, 5MB each).
  final List<XFile> _attachments = [];
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TokenStorage.getCurrentUser().then((user) {
      if (!mounted || user == null) return;
      if (user.isMentor || user.isAdmin) setState(() => _maxChars = 1000);
    });
    _fetchComments(1);

    // Infinite Scroll Listener for the Bottom Sheet
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        if (_hasMore && !_loadingMore) {
          _fetchComments(_page + 1);
        }
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================
  // API LOGIC
  // ==========================================

  Future<void> _fetchComments(int pageNum) async {
    if (pageNum == 1) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await ApiClient.dio.get('/community/posts/${widget.postId}/comments?page=$pageNum');
      
      if (mounted && res.data['success'] == true) {
        final newComments = List<Map<String, dynamic>>.from(res.data['data']);
        setState(() {
          if (pageNum == 1) {
            _comments = newComments;
          } else {
            _comments.addAll(newComments);
          }
          _hasMore = res.data['pagination']?['hasMore'] ?? false;
          _page = pageNum;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comments: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _attachments.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(limit: remaining >= 2 ? remaining : null);
      final ok = <XFile>[];
      for (final f in picked.take(remaining)) {
        if (await f.length() > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Images must be 5MB or smaller.')),
            );
          }
          continue;
        }
        ok.add(f);
      }
      if (ok.isNotEmpty && mounted) setState(() => _attachments.addAll(ok));
    } catch (_) {}
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    setState(() => _submitting = true);

    try {
      final res = await ApiClient.dio.post(
        '/community/posts/${widget.postId}/comments',
        data: FormData.fromMap({
          'content': text,
          if (_replyingTo != null) 'parent_id': _replyingTo,
          'images': [
            for (final f in _attachments)
              await MultipartFile.fromFile(f.path, filename: f.name),
          ],
        }),
      );

      if (mounted && res.data['success'] == true) {
        _commentController.clear();
        setState(() {
          _replyingTo = null;
          _attachments.clear();
        });
        
        // Refresh to show new comment
        await _fetchComments(1);
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data is Map && data['message'] != null
                ? data['message'].toString()
                : "Failed to connect to server"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to connect to server")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Delete Comment", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this comment?", style: TextStyle(color: Colors.white70)),
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

    final previousComments = List<Map<String, dynamic>>.from(_comments);
    setState(() {
      _comments.removeWhere((c) => c['id'] == commentId);
    });

    try {
      final res = await ApiClient.dio.delete('/community/posts/comments/$commentId');
      if (res.data['success'] != true) {
        throw Exception(res.data['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _comments = previousComments);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete comment.")),
        );
      }
    }
  }

  // ==========================================
  // HELPERS
  // ==========================================

  String _capitalizeName(String? firstName, String? lastName) {
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (full.isEmpty) return 'Trader';
    return full.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getInitials(String? firstName, String? lastName) {
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (full.isEmpty) return '?';
    final parts = full.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // ==========================================
  // UI BUILDERS
  // ==========================================

  @override
  Widget build(BuildContext context) {

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset > 0 ? 16.0 : 16.0 + safeBottom;

    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19), // Dark background for the sheet
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 1. Drag Indicator Pill & Header
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 8), 
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Comments",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),

          // 2. Scrollable Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _buildCommentsList(),
          ),

          // 3. Pinned Input Form at the bottom
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F19),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: _buildCommentInput(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    final parentComments = _comments.where((c) => c['parent_id'] == null).toList();

    if (parentComments.isEmpty) {
      return const Center(
        child: Text(
          "No comments yet. Be the first to start the conversation!",
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: parentComments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == parentComments.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }

        final parent = parentComments[index];
        final replies = _comments.where((c) => c['parent_id'] == parent['id']).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentRow(parent, isReply: false),
            ...replies.map((r) => _buildCommentRow(r, isReply: true)),
          ],
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingTo != null)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
            child: Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.blueAccent),
                const SizedBox(width: 4),
                Text(
                  "Replying to comment",
                  style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _replyingTo = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.white54),
                )
              ],
            ),
          ),
        if (_attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _attachments.length; i++)
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(_attachments[i].path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => setState(() => _attachments.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _attachments.length >= 5 ? null : _pickImages,
              child: Container(
                height: 44,
                width: 44,
                margin: const EdgeInsets.only(right: 8, bottom: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: _attachments.length >= 5 ? Colors.white24 : Colors.white70,
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _commentController,
                  maxLength: _maxChars,
                  minLines: 1,
                  maxLines: 4, 
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _replyingTo != null ? "Write a reply..." : "Add a comment...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _submitting ? null : _submitComment,
              child: Container(
                height: 44,
                width: 44,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: _submitting ? Colors.blueAccent.withOpacity(0.5) : Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentRow(Map<String, dynamic> comment, {required bool isReply}) {
    final name = _capitalizeName(comment['first_name'], comment['last_name']);
    final isOwner = widget.currentUserId.toString() == comment['user_id']?.toString();

    return Padding(
      padding: EdgeInsets.only(
        top: 16.0,
        left: isReply ? 40.0 : 0.0, 
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            backgroundImage: comment['avatar'] != null ? NetworkImage(comment['avatar']) : null,
            child: comment['avatar'] == null
                ? Text(
                    _getInitials(comment['first_name'], comment['last_name']),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04), 
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                // Gold tick for admins, green for mentors.
                                if (comment['user_type'] == 'admin' || comment['user_type'] == 'mentor') ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    size: 14,
                                    color: comment['user_type'] == 'admin' ? Colors.amberAccent : Colors.greenAccent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isOwner)
                            GestureDetector(
                              onTap: () => _deleteComment(comment['id']),
                              child: const Icon(Icons.delete_outline, size: 14, color: Colors.white38),
                            )
                        ],
                      ),
                      const SizedBox(height: 4),
                      if ((comment['content'] ?? '').toString().isNotEmpty)
                        Text(
                          comment['content'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      for (final url in (comment['images'] as List? ?? const []))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url.toString(), fit: BoxFit.cover, width: double.infinity),
                          ),
                        ),
                    ],
                  ),
                ),
                
                if (!isReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, left: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingTo = _replyingTo == comment['id'] ? null : comment['id'];
                        });
                      },
                      child: Text(
                        _replyingTo == comment['id'] ? 'Cancel Reply' : 'Reply',
                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}