import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Inline player for a post's MP4 (mentors and admins can attach one).
/// Loads only when first tapped so scrolling a feed doesn't start downloads.
class PostVideo extends StatefulWidget {
  final String url;

  const PostVideo({super.key, required this.url});

  @override
  State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  String? _errorDetail;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PostVideo: failed to play ${widget.url}: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
          _errorDetail = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return GestureDetector(
        onTap: _loading ? null : _start,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white54)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _failed
                              ? Icons.error_outline
                              : Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 52,
                        ),
                        if (_failed) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              "Couldn't play video. Tap to retry.",
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                          if (kDebugMode && _errorDetail != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                              child: Text(
                                _errorDetail!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white30, fontSize: 10),
                              ),
                            ),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(widget.url),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Text('Open in browser'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => controller.value.isPlaying
                  ? controller.pause()
                  : controller.play(),
              child: VideoPlayer(controller),
            ),
            if (!controller.value.isPlaying)
              IgnorePointer(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 52,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.blueAccent,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.black38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
