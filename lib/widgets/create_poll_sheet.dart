import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Poll composer for mentors and admins: a question, 2-4 unique options
/// (max 150 characters each) and an optional expiry. Same limits the
/// backend enforces in createPost.
class CreatePollSheet extends StatefulWidget {
  final String targetFeed;
  final int maxQuestionChars;
  final VoidCallback onCreated;

  const CreatePollSheet({
    super.key,
    required this.targetFeed,
    required this.maxQuestionChars,
    required this.onCreated,
  });

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _question = TextEditingController();
  final List<TextEditingController> _options = [TextEditingController(), TextEditingController()];
  Duration? _expiry = const Duration(days: 1);
  bool _submitting = false;
  String? _error;

  static const _expiryChoices = <String, Duration?>{
    '1 hour': Duration(hours: 1),
    '1 day': Duration(days: 1),
    '3 days': Duration(days: 3),
    '7 days': Duration(days: 7),
    'No expiry': null,
  };

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _question.text.trim();
    final options = _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    if (question.isEmpty) return setState(() => _error = 'Enter a question for your poll.');
    if (options.length < 2) return setState(() => _error = 'Add at least two options.');
    if (options.map((o) => o.toLowerCase()).toSet().length != options.length) {
      return setState(() => _error = 'Poll options must be unique.');
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final form = FormData.fromMap({
        'content': question,
        'poll_options': jsonEncode(options),
        'target_feed': widget.targetFeed,
        if (_expiry != null)
          'poll_expiry_date': DateTime.now().add(_expiry!).toUtc().toIso8601String(),
      });
      final res = await ApiClient.dio.post('/community/posts', data: form);
      if (!mounted) return;
      if (res.data['success'] == true) {
        widget.onCreated();
      } else {
        setState(() => _error = res.data['message']?.toString() ?? 'Failed to create poll.');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() => _error = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New poll · ${widget.targetFeed.toUpperCase()} feed',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _question,
              maxLength: widget.maxQuestionChars,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _deco('Ask a question…'),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _options.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _options[i],
                      maxLength: 150,
                      style: const TextStyle(color: Colors.white),
                      decoration: _deco('Option ${i + 1}'),
                    ),
                  ),
                  if (_options.length > 2)
                    IconButton(
                      onPressed: () => setState(() => _options.removeAt(i).dispose()),
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (_options.length < 4)
              TextButton.icon(
                onPressed: () => setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add option'),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Ends after', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _expiryChoices.entries.firstWhere((e) => e.value == _expiry).key,
                  dropdownColor: const Color(0xFF111827),
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox.shrink(),
                  items: _expiryChoices.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                  onChanged: (k) => setState(() => _expiry = _expiryChoices[k]),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish poll'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
