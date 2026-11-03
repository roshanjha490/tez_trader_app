import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../services/api_client.dart'; // Adjust path to your ApiClient

// Helper class for Initial Edit Data
class EditPostData {
  final int id;
  final String content;
  final List<String> images;

  EditPostData({required this.id, required this.content, this.images = const []});
}

// 🎨 CUSTOM CONTROLLER: Live Hashtag Highlighting
class HashtagController extends TextEditingController {
  HashtagController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    List<TextSpan> children = [];
    text.splitMapJoin(
      RegExp(r'(#\w+)'),
      onMatch: (Match match) {
        children.add(TextSpan(
          text: match[0],
          style: style?.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        ));
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );
    return TextSpan(style: style, children: children);
  }
}

class CreatePostWidget extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onPostCreated;
  final EditPostData? initialData;
  final VoidCallback? onCancel;

  /// 500 characters for regular users, 1000 for mentors and admins (same
  /// limits the backend enforces).
  final int maxChars;

  /// Feed (pro / vip / elite) the post goes to. Only mentors and admins can
  /// target a feed other than their own plan; for everyone else the backend
  /// always posts to the user's own tier.
  final String? targetFeed;

  /// Mentors and admins can attach one video (record with the camera or pick
  /// from the gallery). The backend rejects videos from everyone else.
  final bool allowVideo;

  const CreatePostWidget({
    super.key,
    required this.user,
    this.onPostCreated,
    this.initialData,
    this.onCancel,
    this.maxChars = 500,
    this.targetFeed,
    this.allowVideo = false,
  });

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  late HashtagController _textController;
  final ImagePicker _picker = ImagePicker();

  List<String> _existingImages = [];
  List<XFile> _selectedImages = [];
  XFile? _video;
  static const int maxVideoBytes = 50 * 1024 * 1024; // 50MB, as on the backend
  
  String? _error;
  bool _isSubmitting = false;

  static const int maxFiles = 5;
  int get maxChars => widget.maxChars;
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  bool get isEditing => widget.initialData != null;
  int get totalImages => _existingImages.length + _selectedImages.length;

  @override
  void initState() {
    super.initState();
    _textController = HashtagController(text: widget.initialData?.content ?? '');
    if (isEditing) {
      _existingImages = List.from(widget.initialData?.images ?? []);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC
  // ==========================================

  void _showImageSourceOptions() {
    if (totalImages >= maxFiles) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text('Photo Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Handle Gallery (Multiple Images)
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isEmpty) return;
      await _processSelectedFiles(images);
    } catch (e) {
      setState(() => _error = "Failed to pick images");
    }
  }

  // 3. Handle Camera (Single Image)
  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      await _processSelectedFiles([image]);
    } catch (e) {
      setState(() => _error = "Failed to capture image");
    }
  }

  // 4. Shared Validation Logic
  void _showVideoSourceOptions() {
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
              leading: const Icon(Icons.videocam, color: Colors.blueAccent),
              title: const Text('Record with camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.blueAccent),
              title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickVideo(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (file == null) return;
      if (await file.length() > maxVideoBytes) {
        setState(() => _error = 'Video must not exceed 50 MB.');
        return;
      }
      setState(() {
        _video = file;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to pick video');
    }
  }

  Future<void> _processSelectedFiles(List<XFile> images) async {
    int remainingSlots = maxFiles - totalImages;
    List<XFile> validImages = [];

    for (var file in images.take(remainingSlots)) {
      final length = await file.length();
      if (length > maxFileSizeBytes) {
        setState(() => _error = "One or more images exceed 5MB.");
        continue;
      }
      validImages.add(file);
    }

    setState(() {
      _selectedImages.addAll(validImages);
      _error = null;
    });
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && totalImages == 0 && _video == null) {
      setState(() => _error = "Please write something.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final formData = FormData.fromMap({
        'content': text,
        if (!isEditing && widget.targetFeed != null)
          'target_feed': widget.targetFeed,
      });

      for (var url in _existingImages) {
        formData.fields.add(MapEntry('existingImages', url));
      }
      
      if (isEditing) {
        formData.fields.add(MapEntry('postId', widget.initialData!.id.toString()));
      }

      for (var file in _selectedImages) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }

      if (_video != null && !isEditing) {
        // The backend accepts MP4 only (mime type, .mp4 name, 'ftyp' header).
        // Phone cameras may name the file .mov/.MP4; the container is the
        // same ISO format, so send it under an .mp4 name.
        final base = _video!.name.contains('.')
            ? _video!.name.substring(0, _video!.name.lastIndexOf('.'))
            : _video!.name;
        formData.files.add(MapEntry(
          'video',
          await MultipartFile.fromFile(
            _video!.path,
            filename: '$base.mp4',
            contentType: DioMediaType('video', 'mp4'),
          ),
        ));
      }

      final endpoint = isEditing ? '/community/posts/${widget.initialData!.id}' : '/community/posts';
      final method = isEditing ? ApiClient.dio.put : ApiClient.dio.post; 

      final res = await method(endpoint, data: formData);

      if (mounted && res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? (isEditing ? "Updated successfully" : "Posted successfully!"))),
        );

        if (!isEditing) {
          _textController.clear();
          setState(() {
            _selectedImages.clear();
            _existingImages.clear();
            _video = null;
          });
        }
        widget.onPostCreated?.call();
      } else {
        setState(() => _error = res.data['message'] ?? "Failed to save post");
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() => _error = data is Map && data['message'] != null
          ? data['message'].toString()
          : "Connection error. Please try again.");
    } catch (e) {
      setState(() => _error = "Connection error. Please try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Ensures exactly 2 initials (e.g., "K" from Kumar, "U" from User -> "KU")
  String _getInitials(String? firstName, String? lastName) {
    String first = (firstName != null && firstName.trim().isNotEmpty) ? firstName.trim()[0].toUpperCase() : '';
    String last = (lastName != null && lastName.trim().isNotEmpty) ? lastName.trim()[0].toUpperCase() : '';
    
    String initials = '$first$last';
    return initials.isNotEmpty ? initials : 'U';
  }

  // ==========================================
  // UI BUILDER
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final charsCount = _textController.text.length;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset > 0 ? 16.0 : 16.0 + safeBottom;

    return Container(
      // Solid Dark Background, Curved Top (No Glassmorphism)
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19), // Match the deep dark theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wraps to content height
        children: [
          // 1. Drag Indicator Pill
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Main Row: Avatar + Input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with solid color and perfect initials
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.orange.shade700, // Deep Orange background
                backgroundImage: widget.user['profile_image'] != null ? NetworkImage(widget.user['profile_image']) : null,
                child: widget.user['profile_image'] == null
                    ? Text(
                        _getInitials(widget.user['first_name'], widget.user['last_name']),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Input Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Borderless Text Field
                    TextField(
                      controller: _textController,
                      maxLength: maxChars,
                      maxLines: null, 
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      onChanged: (_) => setState(() {}), 
                      decoration: const InputDecoration(
                        hintText: "Share something, ask a question, or drop a #tag...",
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                        border: InputBorder.none, // Removes the grey box
                        counterText: "", // Hide default counter
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Character Count (Right Aligned)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "$charsCount / $maxChars",
                        style: TextStyle(
                          color: charsCount >= maxChars ? Colors.redAccent : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),

                    // Image Grid Preview
                    if (totalImages > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._existingImages.asMap().entries.map((e) => _buildImageThumbnail(
                              imageProvider: NetworkImage(e.value),
                              onRemove: () => setState(() => _existingImages.removeAt(e.key)),
                            )),
                            ..._selectedImages.asMap().entries.map((e) => _buildImageThumbnail(
                              imageProvider: FileImage(File(e.value.path)),
                              onRemove: () => setState(() => _selectedImages.removeAt(e.key)),
                            )),
                          ],
                        ),
                      ),

                    // Selected video
                    if (_video != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam, color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _video!.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _video = null),
                              child: const Icon(Icons.close, size: 16, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),

                    // Error Message
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),

                    // Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Add Photo / Video
                        Row(
                          children: [
                        GestureDetector(
                          onTap: totalImages >= maxFiles ? null : _showImageSourceOptions,
                          child: Row(
                            children: [
                              Icon(Icons.photo_outlined, size: 20, color: totalImages >= maxFiles ? Colors.white38 : Colors.blueAccent),
                              const SizedBox(width: 6),
                              Text(
                                "Image ($totalImages/$maxFiles)",
                                style: TextStyle(
                                  color: totalImages >= maxFiles ? Colors.white38 : Colors.blueAccent, 
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (widget.allowVideo && !isEditing) ...[
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: _showVideoSourceOptions,
                            child: Row(
                              children: [
                                Icon(Icons.videocam_outlined, size: 20,
                                    color: _video != null ? Colors.greenAccent : Colors.blueAccent),
                                const SizedBox(width: 4),
                                Text(
                                  _video != null ? 'Video ✓' : 'Video',
                                  style: TextStyle(
                                    color: _video != null ? Colors.greenAccent : Colors.blueAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                          ],
                        ),

                        // Cancel & Submit Buttons
                        Row(
                          children: [
                            if (widget.onCancel != null)
                              TextButton(
                                onPressed: widget.onCancel,
                                child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitPost,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Pill shaped
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(isEditing ? "Update" : "Post", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
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

  // Image Preview Boxes
  Widget _buildImageThumbnail({required ImageProvider imageProvider, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}