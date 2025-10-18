import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:video_player/video_player.dart';

class SocketService {
  late IO.Socket socket;
  bool isConnected = false;

  // Notifiers
  ValueNotifier<List<String>> videoUrls = ValueNotifier<List<String>>([]);
  ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  VideoPlayerController? videoController;
  Timer? statusTimer;

  final String deviceId = 'd-02';
  final String deviceToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDIiLCJpYXQiOjE3NjA2NzkyOTEsImV4cCI6MTc5MjIxNTI5MX0.pRFAnlXatCIWgf20k0dmpSWEhL_Vf_32mEvjb-bCot4';
  final String serverUrl = 'http://10.114.23.46:4000';

  List<File> downloadedVideos = [];
  late int currentVideoIndex;

  void connect() {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder().setTransports(['websocket']).enableForceNew().build(),
    );

    socket.onConnect((_) {
      isConnected = true;
      log('✅ Connected to server');
      socket.emit('device:auth', {'token': deviceToken});
    });

    // Authentication success
    socket.on('device:auth:ok', (data) {
      log('Auth success: $data');
      _sendStatus();

      // Start periodic status updates
      statusTimer?.cancel();
      statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (socket.connected) {
          _sendStatus();
        }
      });
    });

    // Authentication failure
    socket.on('device:auth:fail', (data) {
      log(' Auth failed: $data');
    });

    // Playlist updates
    socket.on('playlist:update', (data) {
      log('Playlist update: $data');
      if (data is Map && data['playlist'] is List) {
        final playlist = data['playlist'] as List;
        final urls = playlist.map((e) => e['url'].toString()).toList();
        videoUrls.value = urls;
        _startPlayback(urls);
      }
    });

    // Commands
    socket.on('command', (data) async {
      // print(data);
      final command = data['command'];
      final payload = data['payload'];
      log('Command received: $command');
      switch (command) {
        case 'play':
          if (payload is List) {
            videoUrls.value = List<String>.from(payload);
            _startPlayback(videoUrls.value);
          }
          break;
        case 'stop':
          _stopPlayback();
          break;
        case 'restart':
          _stopPlayback();
          if (payload is List) {
            videoUrls.value = List<String>.from(payload);
            _startPlayback(videoUrls.value);
          }
          break;
        case 'clearStorage':
          await clearDownloadedVideos();
          break;
      }
      _sendStatus();
    });

    // Handle disconnect
    socket.onDisconnect((reason) {
      log('Disconnected from server: $reason');
      isConnected = false;
      statusTimer?.cancel();
    });

    socket.onError((err) => log('Socket error: $err'));
    socket.connect();
  }

  //play
  Future<void> _startPlayback(List<String> urls, {int startIndex = 0}) async {
    if (urls.isEmpty) return;

    currentVideoIndex = startIndex;
    final url = urls[currentVideoIndex];
    log(' Starting playback: $url');

    isPlaying.value = true;
    await downloadVideos(urls);

    await videoController?.dispose();

    videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await videoController!.initialize();
    await videoController!.play();

    videoController!.addListener(() async {
      if (!videoController!.value.isPlaying &&
          videoController!.value.position >= videoController!.value.duration) {
        log('Video ended');
        currentVideoIndex++;
        if (currentVideoIndex < urls.length) {
          await _startPlayback(urls, startIndex: currentVideoIndex);
        } else {
          isPlaying.value = false;
          log('All videos finished');
        }
      }
    });
  }

  //download
  Future<void> downloadVideos(List<String> urls) async {
    final dir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${dir.path}/videos');
    if (!await videoDir.exists()) await videoDir.create(recursive: true);

    downloadedVideos.clear();

    final newFileNames = urls
        .map((url) => '${url.split('/').last}.mp4')
        .toList();

    final existingFiles = videoDir.listSync().whereType<File>().toList();
    for (final file in existingFiles) {
      final fileName = file.path.split('/').last;
      if (!newFileNames.contains(fileName)) {
        try {
          await file.delete();
          log('Deleted old video: $fileName');
        } catch (e) {
          log(' Failed to delete $fileName: $e');
        }
      }
    }

    // Download from the new list
    for (int i = 0; i < urls.length && i < 10; i++) {
      final url = urls[i];
      final fileName = '${url.split('/').last}.mp4';
      final file = File('${videoDir.path}/$fileName');

      if (!await file.exists()) {
        try {
          log(' Downloading: $url');
          await Dio().download(url, file.path);
          log(' Downloaded: $fileName');
        } catch (e) {
          log(' Failed to download $url: $e');
        }
      } else {
        log(' Already exists: $fileName');
      }

      downloadedVideos.add(file);
    }
    log(' Total active videos: ${downloadedVideos.length}');
  }

  // Future<void> downloadVideos(List<String> urls) async {
  //   final status = await Permission.storage.request();

  //   if (status.isDenied || status.isPermanentlyDenied) {
  //     log('❌ Storage permission denied');
  //     return;
  //   }

  //   final dir = await getApplicationDocumentsDirectory();
  //   final videoDir = Directory('${dir.path}/videos');
  //   if (!await videoDir.exists()) await videoDir.create(recursive: true);

  //   downloadedVideos.clear();
  //   print(downloadedVideos);

  //   for (int i = 0; i < urls.length && i < 10; i++) {
  //     final url = urls[i];
  //     final fileName = '${url.split('/').last}.mp4';
  //     final file = File('${videoDir.path}/$fileName');
  //     if (!await file.exists()) {
  //       try {
  //         log('⬇️ Downloading: $url');
  //         await Dio().download(url, file.path);
  //         log('✅ Downloaded: $fileName');
  //       } catch (e) {
  //         log('❌ Failed to download $url: $e');
  //       }
  //     } else {
  //       log('📁 Already exists: $fileName');
  //     }
  //     downloadedVideos.add(file);
  //   }

  //   log(' Total downloaded: ${downloadedVideos.length}');
  // }

  //stop
  Future<void> _stopPlayback() async {
    if (videoController != null) {
      await videoController!.pause();
      await videoController!.dispose();
      videoController = null;
      isPlaying.value = false;
      log(' Playback stopped');
    }
  }

  //clearStorage

  Future<void> clearDownloadedVideos() async {
    final dir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${dir.path}/videos');

    if (!await videoDir.exists()) return;

    final files = videoDir.listSync().whereType<File>();
    for (final file in files) {
      try {
        await file.delete();
        log(' Deleted: ${file.path.split('/').last}');
      } catch (e) {
        log(' Failed to delete ${file.path.split('/').last}: $e');
      }
    }

    downloadedVideos.clear();
    log('All downloaded videos cleared');
  }

  Future<void> _sendStatus() async {
    int? freeSpace;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await dir.stat();
      freeSpace = stat.size;
    } catch (_) {
      freeSpace = null;
    }

    final status = {
      'deviceId': deviceId,
      'status': {
        'playing': isPlaying.value,
        'playlistCount': videoUrls.value.length,
        'currently': currentVideoIndex,
        'freeSpaceBytes': freeSpace,
      },
    };

    socket.emit('device:status', status);
    log('Status sent: $status');
  }

  void disconnect() {
    socket.disconnect();
    statusTimer?.cancel();
    isConnected = false;
  }
}
