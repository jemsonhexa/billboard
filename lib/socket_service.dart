import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  bool isConnected = false;

  // Reactive notifiers
  final ValueNotifier<List<File>> downloadedVideos = ValueNotifier<List<File>>(
    [],
  );
  final ValueNotifier<bool> isDownloading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  Timer? statusTimer;

  //device details

  final String deviceId = 'd-01';
  final String deviceToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDEiLCJpYXQiOjE3NTk3MjY5MjUsImV4cCI6MTc5MTI2MjkyNX0.iFknOQIUy7lmSV7lJa_o3QKHU4t3e7O87ZonH-pgyRw';
  final String serverUrl = 'https://cms-backend-mlnr.onrender.com';

  //   final String deviceId = 'd-01';
  //   final String deviceToken =
  //       'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDEiLCJpYXQiOjE3NTk3MjY5MjUsImV4cCI6MTc5MTI2MjkyNX0.iFknOQIUy7lmSV7lJa_o3QKHU4t3e7O87ZonH-pgyRw';
  //   final String serverUrl = 'https://cms-backend-mlnr.onrender.com';

  // d2
  //   final String deviceId = 'd-02';
  //   final String deviceToken =
  //       'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDIiLCJpYXQiOjE3NjA2NzkyOTEsImV4cCI6MTc5MjIxNTI5MX0.pRFAnlXatCIWgf20k0dmpSWEhL_Vf_32mEvjb-bCot4';
  //   final String serverUrl = 'https://cms-backend-mlnr.onrender.com/';

  // Connect to socket
  void connect() {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    socket.onConnect((_) {
      isConnected = true;
      log('Connected to server');
      socket.emit('device:auth', {'token': deviceToken});
    });

    socket.on('command', (data) async {
      final command = data['command'];
      final payload = data['payload'];
      log('Command received: $command');

      switch (command) {
        case 'play':
        case 'restart':
          if (payload is List) {
            final urls = List<String>.from(payload);
            await _downloadVideos(urls);
            isPlaying.value = true; // start/resume
          }
          break;

        case 'stop':
          isPlaying.value = false; // pause
          break;

        case 'clearStorage':
          await clearDownloadedVideos();
          isPlaying.value = false; // stop playback if cleared
          break;

        default:
          log('⚠️ Unknown command: $command');
      }

      _sendStatus();
    });

    socket.onDisconnect((reason) {
      log('🔌 Disconnected: $reason');
      isConnected = false;
      statusTimer?.cancel();
    });

    socket.onError((err) => log('Socket error: $err'));

    socket.connect();
  }

  Future<void> _downloadVideos(List<String> urls) async {
    if (urls.isEmpty) return;

    isDownloading.value = true;
    final dir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${dir.path}/videos');
    if (!await videoDir.exists()) await videoDir.create(recursive: true);

    final newFiles = <File>[];
    final newFileNames = urls
        .map((url) => Uri.decodeComponent(url.split('/').last))
        .toList();

    // Delete old videos not in playlist
    for (final file in videoDir.listSync().whereType<File>()) {
      final fileName = file.path.split('/').last;
      if (!newFileNames.contains(fileName)) {
        try {
          await file.delete();
          log('Deleted old: $fileName');
        } catch (e) {
          log('Failed to delete $fileName: $e');
        }
      }
    }

    // Download required videos
    for (final url in urls) {
      final fileName = Uri.decodeComponent(url.split('/').last);
      final file = File('${videoDir.path}/$fileName');

      if (!await file.exists()) {
        try {
          log('Downloading: $url');
          await Dio().download(url, file.path);
          log('Downloaded: $fileName');
        } catch (e) {
          log('Failed to download $fileName: $e');
          continue;
        }
      } else {
        log('Already exists: $fileName');
      }

      newFiles.add(file);
    }

    downloadedVideos.value = newFiles;
    isDownloading.value = false;
    log('Total downloaded: ${downloadedVideos.value.length}');
  }

  Future<void> clearDownloadedVideos() async {
    final dir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${dir.path}/videos');

    if (!await videoDir.exists()) return;

    for (final file in videoDir.listSync().whereType<File>()) {
      try {
        await file.delete();
        log('Deleted: ${file.path.split('/').last}');
      } catch (e) {
        log('Failed to delete ${file.path.split('/').last}: $e');
      }
    }

    downloadedVideos.value = [];
  }

  Future<void> _sendStatus() async {
    if (!socket.connected) return;

    final dir = await getApplicationDocumentsDirectory();
    int freeSpace = 0;
    try {
      final stat = await dir.stat();
      freeSpace = stat.size;
    } catch (_) {}

    final status = {
      'deviceId': deviceId,
      'status': {
        'playlistCount': downloadedVideos.value.length,
        'freeSpaceBytes': freeSpace,
      },
    };

    socket.emit('device:status', status);
    log(' Status sent: $status');
  }

  void disconnect() {
    try {
      socket.dispose();
    } catch (_) {
      socket.disconnect();
    }
    statusTimer?.cancel();
    isConnected = false;
  }
}
