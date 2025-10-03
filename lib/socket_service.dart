import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as socketservice;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class SocketService {
  late socketservice.Socket socket;

  // Add ValueNotifier to store video URLs
  ValueNotifier<List<String>> videoUrls = ValueNotifier<List<String>>([]);
  bool isConnected = false;

  VideoPlayerController? videoController; // current video

  void connect() {
    String url = 'http://10.114.20.151:3000';

    socket = socketservice.io(
      url,
      socketservice.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    // Listeners
    socket.onConnect((_) {
      isConnected = true;
      log('Connected to server');
      socket.emit('msg', 'Client says hello');
    });

    socket.on('videos', (data) {
      if (data is List) {
        // print(data);
        videoUrls.value = List<String>.from(data); // update the notifier
      }
    });

    socket.onDisconnect((_) {
      log('Socket disconnect');
      isConnected = false;
    });
    socket.onError((err) => log('Socket error: $err'));

    socket.connect();
  }
}
