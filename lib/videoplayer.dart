import 'package:flutter/material.dart';

import 'package:video_player/video_player.dart';

class Player extends StatefulWidget {
  final List videoUrls;
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
  late VideoPlayerController _controller;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer(currentIndex);
  }

  void _initializePlayer(int index) {
    _controller = VideoPlayerController.network(widget.videoUrls[index])
      ..initialize().then((_) {
        setState(() {});
        _controller.play();

        // Give controller to SocketService
        widget.controllerCallback(_controller);
      });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration) {
        _playNext();
      }
    });
  }

  void _playNext() {
    currentIndex = (currentIndex + 1) % widget.videoUrls.length;
    _controller.removeListener(() {});
    _controller.dispose();
    _initializePlayer(currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: VideoPlayer(_controller),
              ),
            )
          : Center(child: const CircularProgressIndicator()),
    );
  }
}
