import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:video_player/video_player.dart';

class SocketService {
  late IO.Socket socket;
  bool isConnected = false;

  // Notifiers
  ValueNotifier<List<String>> videoUrls = ValueNotifier<List<String>>([]);
  ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  VideoPlayerController? videoController;

  final String deviceId = 'd-01';
  final String deviceToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDEiLCJpYXQiOjE3NTk3MjY5MjUsImV4cCI6MTc5MTI2MjkyNX0.iFknOQIUy7lmSV7lJa_o3QKHU4t3e7O87ZonH-pgyRw';
  final String serverUrl = 'http://192.168.29.222:4000';

  void connect() {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder().setTransports(['websocket']).enableForceNew().build(),
    );

    socket.onConnect((_) {
      isConnected = true;
      log('Connected to server');
      socket.emit('device:auth', {'token': deviceToken});
    });

    // Authentication events
    socket.on('device:auth:ok', (data) {
      log('Auth success: $data');
      _sendStatus();
    });

    socket.on('device:auth:fail', (data) {
      log(' Auth failed: $data');
    });

    // Playlist update
    socket.on('playlist:update', (data) {
      log('Playlist update: $data');
      if (data is Map && data['playlist'] is List) {
        final playlist = data['playlist'] as List;
        final urls = playlist.map((e) => e['url'].toString()).toList();
        videoUrls.value = urls;
        _startPlayback(urls);
      }
    });

    // Command handling
    socket.on('command', (data) {
      // print(data['payload']);
      // [http://192.168.29.222:4000/content/b63db930-6e9e-4a40-b929-0d16e4ad08c5.mp4, http://192.168.29.222:4000/content/f71262e5-b6da-40b8-ba00-69a11b235f30.mp4]
      final command = data['command'];
      final payload = data['payload'];
      log('Command received: $command');
      switch (command) {
        case 'play':
          if (payload is List) {
            videoUrls.value = List<String>.from(payload);
            log(' Starting playback: ${videoUrls.value}');
            _startPlayback(videoUrls.value);
          } else {
            log('Invalid payload for play: $payload');
          }
          break;
        case 'stop':
          _stopPlayback();
          break;
        case 'restart':
          _stopPlayback();
          if (payload is List) {
            videoUrls.value = List<String>.from(payload);
            log('Restarting playback: ${videoUrls.value}');
            _startPlayback(videoUrls.value);
          }
          break;
        case 'clearStorage':
          // Optional: clear cache or temp folder
          break;
      }
      _sendStatus();
    });

    socket.onDisconnect((_) {
      log(' Disconnected from server');
      isConnected = false;
    });

    socket.onError((err) => log('Socket error: $err'));

    socket.connect();
  }

  Future<void> _startPlayback(List<String> urls) async {
    if (urls.isEmpty) return;
    final url = urls.first; // play first video for now

    log('Starting playback: $url');
    isPlaying.value = true;

    // Clean up old controller
    await videoController?.dispose();

    videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await videoController!.initialize();
    await videoController!.play();

    videoController!.addListener(() {
      if (!videoController!.value.isPlaying &&
          videoController!.value.position >= videoController!.value.duration) {
        log('Video ended');
      }
    });
  }

  Future<void> _stopPlayback() async {
    if (videoController != null) {
      await videoController!.pause();
      await videoController!.dispose();
      videoController = null;
      isPlaying.value = false;
      log('Playback stopped');
    }
  }

  void _sendStatus() {
    final status = {
      'deviceId': deviceId,
      'status': {
        'playing': isPlaying.value,
        'playlistCount': videoUrls.value.length,
      },
    };
    socket.emit('device:status', status);
  }

  void disconnect() {
    socket.disconnect();
    isConnected = false;
  }
}
