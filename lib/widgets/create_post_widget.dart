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

  const CreatePostWidget({
    super.key,
    required this.user,
    this.onPostCreated,
    this.initialData,
    this.onCancel,
  });

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  late HashtagController _textController;
  final ImagePicker _picker = ImagePicker();

  List<String> _existingImages = [];
  List<XFile> _selectedImages = [];
  
  String? _error;
  bool _isSubmitting = false;

  static const int maxFiles = 5;
  static const int maxChars = 200;
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

  Future<void> _pickImages() async {
    if (totalImages >= maxFiles) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isEmpty) return;

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
    } catch (e) {
      setState(() => _error = "Failed to pick images");
    }
  }

  Future<void> _submitPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
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
          });
        }
        widget.onPostCreated?.call();
      } else {
        setState(() => _error = res.data['message'] ?? "Failed to save post");
      }
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
                        // Add Photo Text Button
                        GestureDetector(
                          onTap: totalImages >= maxFiles ? null : _pickImages,
                          child: Row(
                            children: [
                              Icon(Icons.photo_outlined, size: 20, color: totalImages >= maxFiles ? Colors.white38 : Colors.blueAccent),
                              const SizedBox(width: 6),
                              Text(
                                "Add Image ($totalImages/$maxFiles)",
                                style: TextStyle(
                                  color: totalImages >= maxFiles ? Colors.white38 : Colors.blueAccent, 
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                            ],
                          ),
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