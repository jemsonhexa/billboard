import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class Player extends StatefulWidget {
  final List<String> videoUrls;
  final Function(VideoPlayerController) controllerCallback;

  const Player({
    super.key,
    required this.videoUrls,
    required this.controllerCallback,
  });

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  VideoPlayerController? _controller;
  int currentIndex = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer(currentIndex);
  }

  Future<void> _initializePlayer(int index) async {
    // Dispose old controller safely if exists
    if (_controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
    }

    if (_isDisposed) return;

    final controller = VideoPlayerController.network(widget.videoUrls[index]);
    _controller = controller;

    await controller.initialize();
    if (_isDisposed) return;

    controller.play();
    widget.controllerCallback(controller);
    controller.addListener(_onVideoEnd);

    if (mounted) setState(() {});
  }

  void _onVideoEnd() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (!controller.value.isPlaying &&
        controller.value.position >= controller.value.duration) {
      controller.removeListener(_onVideoEnd);
      _playNext();
    }
  }

  Future<void> _playNext() async {
    if (widget.videoUrls.isEmpty) return;
    currentIndex = (currentIndex + 1) % widget.videoUrls.length;
    await _initializePlayer(currentIndex);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.removeListener(_onVideoEnd);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: (controller != null && controller.value.isInitialized)
          ? SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: VideoPlayer(controller),
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
