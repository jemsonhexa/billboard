import 'dart:developer';
import 'dart:io';
import 'package:billboard_tv/comand.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';

class LocalOfflinePlayer extends StatefulWidget {
  final List<File> videos;
  final ValueNotifier<bool> isPlayingNotifier;

  const LocalOfflinePlayer({
    super.key,
    required this.videos,
    required this.isPlayingNotifier,
  });

  @override
  State<LocalOfflinePlayer> createState() => _LocalOfflinePlayerState();
}

class _LocalOfflinePlayerState extends State<LocalOfflinePlayer> {
  VideoPlayerController? _controller;
  int currentIndex = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.videos.isNotEmpty) _playVideo(widget.videos[currentIndex]);

    // Play/pause control via isPlayingNotifier
    widget.isPlayingNotifier.addListener(() {
      if (_controller != null && _controller!.value.isInitialized) {
        if (widget.isPlayingNotifier.value) {
          _controller!.play();
        } else {
          _controller!.pause();
        }
      }
    });

    // SnackBar feedback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commandNotifier = context.read<CommandNotifier>();
      commandNotifier.addListener(() {
        if (!mounted) return;
        final command = commandNotifier.latestCommand;

        if (command == null) return;

        log('player cmd: $command');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Command: $command',
              style: TextStyle(),
              textAlign: TextAlign.center,
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );

        //Command logic
        switch (command.toLowerCase()) {
          case 'play':
            _controller?.play();
            widget.isPlayingNotifier.value = true;
            break;
          case 'pause':
            _controller?.pause();
            widget.isPlayingNotifier.value = false;
            break;
          case 'next':
            _nextVideo();
            break;
          default:
            debugPrint('Unknown command: $command');
        }
      });
    });
  }

  Future<void> _playVideo(File file) async {
    try {
      await _controller?.pause();
      await _controller?.dispose();

      if (_isDisposed) return;

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.setLooping(false);

      if (widget.isPlayingNotifier.value) await _controller!.play();

      _controller!.removeListener(_onVideoEnd);
      _controller!.addListener(_onVideoEnd);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error playing video: $e');
      _nextVideo(); // skip broken file
    }
  }

  void _onVideoEnd() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (!controller.value.isPlaying &&
        controller.value.position >= controller.value.duration) {
      controller.removeListener(_onVideoEnd);
      _nextVideo();
    }
  }

  Future<void> _nextVideo() async {
    if (_isDisposed || widget.videos.isEmpty) return;
    currentIndex = (currentIndex + 1) % widget.videos.length;
    await _playVideo(widget.videos[currentIndex]);
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
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
