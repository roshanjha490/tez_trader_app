import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class ShoutboxTab extends StatefulWidget {
  const ShoutboxTab({super.key});

  @override
  State<ShoutboxTab> createState() => _ShoutboxTabState();
}

class _ShoutboxTabState extends State<ShoutboxTab> {
  // --- State ---
  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  bool _isSending = false;
  String? _error;
  bool _showEmojiPicker = false;
  bool _isDisposed = false;

  final TextEditingController _draftController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  // --- Constants ---
  static const int _maxLength = 280;
  static const List<String> _quickEmojis = [
    "🚀",
    "🔥",
    "🐂",
    "🐻",
    "📈",
    "📉",
    "💰",
    "👀",
    "💎",
    "🙌",
    "😂",
    "🤡",
  ];

  // Deterministic user colors mapped from your Tailwind classes
  static const List<Color> _userColors = [
    Colors.redAccent, Colors.greenAccent, Colors.orangeAccent,
    Colors.amberAccent, Color(0xFF34D399), // Emerald
    Colors.tealAccent, Colors.cyanAccent, Colors.blueAccent,
    Colors.indigoAccent, Colors.deepPurpleAccent, Colors.purpleAccent,
    Color(0xFFE879F9), // Fuchsia
    Colors.pinkAccent, Color(0xFFFB7185), // Rose
  ];

  @override
  void initState() {
    super.initState();
    _fetchMessages();

    // Setup 5-second polling exactly like Next.js
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchMessages(),
    );

    // Setup Infinite Scroll Listener
    _scrollController.addListener(() {
      // In a reversed list, reaching the 'maxScrollExtent' means you scrolled to the top
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        _fetchOlderMessages();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    _scrollController.dispose();
    _draftController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOGIC & API
  // ==========================================

  Future<void> _fetchMessages() async {
    if (_isDisposed) return;
    try {
      // Adjust this URL to match your actual Express route
      final response = await ApiClient.dio.get('/shoutbox/messages?offset=0');
      if (_isDisposed) return;

      if (response.data['success'] == true) {
        final List<dynamic> fetched = response.data['data'];

        setState(() {
          // Combine existing and new, then remove duplicates using a Set/Map logic
          final Map<int, Map<String, dynamic>> uniqueMap = {
            for (var m in _messages) m['id']: m,
            for (var m in fetched) m['id']: m,
          };

          _messages = uniqueMap.values.toList();
          // Sort DESCENDING so index 0 (newest) is at the bottom of the reversed list
          _messages.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
        });
      }
    } catch (e) {
      debugPrint("Shoutbox Poll Error: $e");
    }
  }

  Future<void> _fetchOlderMessages() async {
    if (_isLoadingOlder || !_hasMore || _isDisposed) return;
    setState(() => _isLoadingOlder = true);

    try {
      final response = await ApiClient.dio.get(
        '/shoutbox/messages?offset=${_messages.length}',
      );
      if (_isDisposed) return;

      if (response.data['success'] == true) {
        final List<dynamic> olderData = response.data['data'];

        setState(() {
          if (olderData.isEmpty) {
            _hasMore = false;
          } else {
            final Map<int, Map<String, dynamic>> uniqueMap = {
              for (var m in _messages) m['id']: m,
              for (var m in olderData) m['id']: m,
            };
            _messages = uniqueMap.values.toList();
            _messages.sort(
              (a, b) => (b['id'] as int).compareTo(a['id'] as int),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("Shoutbox Pagination Error: $e");
    } finally {
      if (!_isDisposed) setState(() => _isLoadingOlder = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _draftController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
      _showEmojiPicker = false;
    });

    try {
      final response = await ApiClient.dio.post(
        '/shoutbox/messages',
        data: {'message': text},
      );

      if (_isDisposed) return;

      if (response.data['success'] == true) {
        _draftController.clear();

        // 🚨 THE FIX: Only scroll if the ListView actually exists!
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

        _fetchMessages();
      } else {
        setState(
          () => _error = response.data['message'] ?? "Couldn't send message.",
        );
      }
    } catch (e) {
      if (!_isDisposed) setState(() => _error = "Failed to connect to server.");
    } finally {
      if (!_isDisposed) setState(() => _isSending = false);
    }
  }

  // ==========================================
  // HELPERS
  // ==========================================

  Color _getUserColor(int userId) {
    return _userColors[userId % _userColors.length];
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return "just now";
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return "";

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    return "${diff.inHours}h ago";
  }

  // ==========================================
  // UI BUILDER
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Chat Feed
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchMessages,
            color: Colors.blueAccent,
            backgroundColor: const Color(0xFF0B0F19),
            child: _messages.isEmpty && !_isLoadingOlder
                ? const Center(
                    child: Text(
                      "No messages yet. Say something.",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Magically handles bottom-anchoring!
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _messages.length + (_isLoadingOlder ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show loading indicator at the very top of the scroll
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        );
                      }

                      final m = _messages[index];
                      final userId = m['user_id'] as int? ?? 0;
                      final firstName = m['first_name']?.toString() ?? 'User';
                      final lastInitial =
                          (m['last_name']?.toString().isNotEmpty == true)
                          ? '${m['last_name'].toString()[0]}.'
                          : '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, height: 1.4),
                            children: [
                              TextSpan(
                                text: '$firstName $lastInitial ',
                                style: TextStyle(
                                  color: _getUserColor(userId),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: m['message']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              TextSpan(
                                text: '  ${_timeAgo(m['created_at'])}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),

        // 2. Optional Quick Emoji Picker (Above Input)
        if (_showEmojiPicker)
          Container(
            color: Colors.white.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _quickEmojis
                  .map(
                    (emoji) => GestureDetector(
                      onTap: () {
                        if (_draftController.text.length + emoji.length <=
                            _maxLength) {
                          _draftController.text += emoji;
                        }
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  )
                  .toList(),
            ),
          ),

        // 3. Input Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F19),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showEmojiPicker
                                  ? Icons.keyboard_arrow_down
                                  : Icons.emoji_emotions_outlined,
                              color: _showEmojiPicker
                                  ? Colors.amberAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _showEmojiPicker = !_showEmojiPicker,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _draftController,
                              maxLength: _maxLength,
                              maxLines: 4,
                              minLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: const InputDecoration(
                                hintText: "Say something...",
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                                counterText:
                                    "", // Hides the default counter to use our own
                              ),
                              onChanged: (_) => setState(
                                () {},
                              ), // Trigger rebuild for character count
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color:
                            _draftController.text.trim().isEmpty || _isSending
                            ? Colors.blueAccent.withOpacity(0.4)
                            : Colors.blueAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
              // Character Counter
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_maxLength - _draftController.text.length}/$_maxLength',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
