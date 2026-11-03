import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// A poll attached to a post: question, options, vote, and results once the
/// viewer has voted or the poll has expired.
///
/// [poll] is the backend's poll object:
/// `{id, expiryDate, totalVotes, hasVoted, myVoteOptionId, options:[{id,text,imageUrl,votesCount}]}`
class PollCard extends StatefulWidget {
  final int postId;
  final String question;
  final Map<String, dynamic> poll;

  const PollCard({
    super.key,
    required this.postId,
    required this.question,
    required this.poll,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  late Map<String, dynamic> _poll;
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _poll = Map<String, dynamic>.from(widget.poll);
  }

  bool get _expired {
    final raw = _poll['expiryDate']?.toString();
    final expiry = raw == null ? null : DateTime.tryParse(raw);
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  bool get _hasVoted => _poll['hasVoted'] == true;
  bool get _showResults => _hasVoted || _expired;

  Future<void> _vote(int optionId) async {
    if (_voting || _showResults) return;
    setState(() => _voting = true);
    try {
      final res = await ApiClient.dio.post(
        '/community/posts/${widget.postId}/poll/vote',
        data: {'optionId': optionId},
      );
      final updated = res.data['data']?['poll'];
      if (mounted && updated is Map) {
        setState(() => _poll = Map<String, dynamic>.from(updated));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Failed to record your vote.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = (_poll['options'] as List? ?? const [])
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList();
    final total = (_poll['totalVotes'] as num?)?.toInt() ?? 0;
    final myVote = (_poll['myVoteOptionId'] as num?)?.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.question,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
        ),
        const SizedBox(height: 12),
        for (final o in options) ...[
          _option(o, total, myVote),
          const SizedBox(height: 8),
        ],
        Text(
          '$total vote${total == 1 ? '' : 's'}${_expired ? ' · Poll ended' : ''}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _option(Map<String, dynamic> o, int total, int? myVote) {
    final id = (o['id'] as num).toInt();
    final votes = (o['votesCount'] as num?)?.toInt() ?? 0;
    final pct = total == 0 ? 0.0 : votes / total;
    final mine = myVote == id;
    final imageUrl = o['imageUrl'] as String?;

    final label = Row(
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(imageUrl, width: 36, height: 36, fit: BoxFit.cover),
            ),
          ),
        Expanded(
          child: Text(
            o['text']?.toString() ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: mine ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (_showResults) ...[
          if (mine) const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.check_circle, size: 16, color: Colors.blueAccent),
          ),
          Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ],
    );

    return GestureDetector(
      onTap: _showResults ? null : () => _vote(id),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mine ? Colors.blueAccent : Colors.white.withOpacity(0.12)),
        ),
        child: Stack(
          children: [
            if (_showResults)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(color: Colors.blueAccent.withOpacity(mine ? 0.28 : 0.14)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: label,
            ),
          ],
        ),
      ),
    );
  }
}
