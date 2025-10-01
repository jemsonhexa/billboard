import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player/video_player.dart';

class Player extends StatefulWidget {
  final List<String> videoUrls;
  const Player({super.key, required this.videoUrls});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late VideoPlayerController _controller;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Hide system UI for fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializePlayer(currentIndex);
  }

  void _initializePlayer(int index) {
    _controller = VideoPlayerController.network(widget.videoUrls[index])
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
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
    currentIndex = (currentIndex + 1) % widget.videoUrls.length; // loop
    _controller.removeListener(() {});
    _controller.dispose();
    _initializePlayer(currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    // Restore system UI on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller.value.isInitialized
            ? SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16, // Keep Reel format
                    child: VideoPlayer(_controller),
                  ),
                ),

                // FittedBox(
                //   fit: BoxFit.cover,
                //   child: SizedBox(
                //     width: _controller.value.size.width,
                //     height: _controller.value.size.height,
                //     child:
                //         //  AspectRatio(
                //         //   aspectRatio: 16 / 9,
                //         //   child:
                //         VideoPlayer(_controller),
                //     // ),
                //   ),
                // ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

//landscape mode

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// // ignore: depend_on_referenced_packages
// import 'package:video_player/video_player.dart';

// class Player extends StatefulWidget {
//   final List<String> videoUrls;
//   const Player({super.key, required this.videoUrls});

//   @override
//   State<Player> createState() => _PlayerState();
// }

// class _PlayerState extends State<Player> {
//   late VideoPlayerController _controller;
//   int currentIndex = 0;
//   bool _isFullScreen = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializePlayer(currentIndex);
//   }

//   void _initializePlayer(int index) {
//     _controller = VideoPlayerController.network(widget.videoUrls[index])
//       ..initialize().then((_) {
//         setState(() {});
//         _controller.play();
//       });

//     _controller.addListener(() {
//       if (_controller.value.isInitialized &&
//           !_controller.value.isPlaying &&
//           _controller.value.position >= _controller.value.duration) {
//         _playNext();
//       }
//     });
//   }

//   void _playNext() {
//     currentIndex = (currentIndex + 1) % widget.videoUrls.length;
//     _controller.dispose();
//     _initializePlayer(currentIndex);
//   }

//   void _toggleFullScreen() {
//     setState(() {
//       _isFullScreen = !_isFullScreen;
//     });

//     if (_isFullScreen) {
//       // Go fullscreen (landscape + hide system UI)
//       SystemChrome.setPreferredOrientations([
//         DeviceOrientation.landscapeLeft,
//         DeviceOrientation.landscapeRight,
//       ]);
//       SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//     } else {
//       // Exit fullscreen (portrait + restore UI)
//       SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
//       SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     }
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     // Always restore portrait mode when leaving
//     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: _controller.value.isInitialized
//             ? Stack(
//                 alignment: Alignment.bottomRight,
//                 children: [
//                   AspectRatio(
//                     aspectRatio: 16 / 9, // fixed 16:9
//                     child: VideoPlayer(_controller),
//                   ),
//                   Positioned(
//                     bottom: 20,
//                     right: 20,
//                     child: IconButton(
//                       iconSize: 40,
//                       color: Colors.white,
//                       icon: Icon(
//                         _isFullScreen
//                             ? Icons.fullscreen_exit
//                             : Icons.fullscreen,
//                       ),
//                       onPressed: _toggleFullScreen,
//                     ),
//                   ),
//                 ],
//               )
//             : const CircularProgressIndicator(),
//       ),
//     );
//   }
// }
