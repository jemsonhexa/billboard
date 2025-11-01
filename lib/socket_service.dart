import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:billboard_tv/comand.dart';
import 'package:dio/dio.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
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
  final CommandNotifier commandNotifier;
  Timer? statusTimer;

  //device details
  final String deviceId = 'd-01';
  final String deviceToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDEiLCJpYXQiOjE3NTk3MjY5MjUsImV4cCI6MTc5MTI2MjkyNX0.iFknOQIUy7lmSV7lJa_o3QKHU4t3e7O87ZonH-pgyRw';
  final String serverUrl = 'http://192.168.29.38:4000';
  //   final String deviceId = 'd-01';
  //   final String deviceToken =
  //       'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDEiLCJpYXQiOjE3NTk3MjY5MjUsImV4cCI6MTc5MTI2MjkyNX0.iFknOQIUy7lmSV7lJa_o3QKHU4t3e7O87ZonH-pgyRw';
  //   final String serverUrl = 'https://cms-backend-mlnr.onrender.com';

  // d2
  //   final String deviceId = 'd-02';
  //   final String deviceToken =
  //       'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkZXZpY2VJZCI6ImQtMDIiLCJpYXQiOjE3NjA2NzkyOTEsImV4cCI6MTc5MjIxNTI5MX0.pRFAnlXatCIWgf20k0dmpSWEhL_Vf_32mEvjb-bCot4';
  //   final String serverUrl = 'https://cms-backend-mlnr.onrender.com/';

  SocketService({required this.commandNotifier});
  // Connect to socket
  void connect() {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    socket.onConnect((_) {
      isConnected = true;
      log('Connected to server');
      socket.emit('device:auth', {'token': deviceToken});

      statusTimer?.cancel();
      statusTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _sendStatus(),
      );
    });

    socket.on('command', (data) async {
      final command = data['command'];
      final payload = data['payload'];
      log('Command received: $command');
      commandNotifier.latestCommand = command;

      switch (command) {
        case 'play':
          isPlaying.value = false;
          await Future.delayed(const Duration(milliseconds: 200));
          if (payload is List) {
            final urls = List<String>.from(payload);
            await _downloadVideos(urls);
            isPlaying.value = true;
          }
          break;
        case 'restart':
          isPlaying.value = false;
          // Close existing socket connection
          try {
            socket.disconnect();
            log('Socket disconnected successfully');
          } catch (e) {
            log('Socket disconnect failed: $e');
          }
          // Wait a bit before reconnecting
          await Future.delayed(const Duration(seconds: 2));
          // Reconnect to the server
          try {
            socket.connect();
            log('Socket reconnected successfully');
          } catch (e) {
            log('Failed to reconnect socket: $e');
          }
          break;

        case 'stop':
          isPlaying.value = false; // pause
          break;

        case 'clearStorage':
          isPlaying.value = false; // stop playback
          await clearDownloadedVideos();
          break;

        default:
          log('Unknown command: $command');
      }
      _sendStatus();
    });

    socket.onDisconnect((reason) {
      log('Disconnected: $reason');
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

    final List<File> newFiles = [];
    final newFileNames = urls
        .map((url) => Uri.decodeComponent(url.split('/').last))
        .toList();
    //Delete old videos not in new playlist
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
    // start playback as soon as first file is ready
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      final rawName = Uri.decodeComponent(url.split('/').last);
      final cleanName = '${rawName.split('.mp4').first}.mp4';
      final file = File('${videoDir.path}/$cleanName');

      try {
        if (!await file.exists()) {
          log('Downloading: $url');
          await Dio().download(url, file.path);
          log('Downloaded: $cleanName');
        } else {
          log('Already exists: $cleanName');
        }

        if (await file.exists()) {
          newFiles.add(file);

          // Update the notifier
          downloadedVideos.value = List.from(newFiles);

          //Start playback once first video is ready
          if (newFiles.length == 1 && !isPlaying.value) {
            isPlaying.value = true;
            log('Starting playback — first video ready');
          }
        } else {
          log('Missing file after download attempt: $cleanName');
        }
      } catch (e) {
        log('Failed to download $cleanName: $e');
      }
    }

    isDownloading.value = false;
    log('All videos processed. Total: ${newFiles.length}');
  }

  Future<void> clearDownloadedVideos() async {
    isPlaying.value = false;

    final dir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${dir.path}/videos');

    if (!await videoDir.exists()) {
      log('No video directory found at: ${videoDir.path}');
      return;
    }

    final entries = videoDir.listSync(recursive: true);
    final files = entries.whereType<File>().toList();
    final folders = entries.whereType<Directory>().toList();

    log('Clearing storage in: ${videoDir.path}');
    log('Found ${files.length} file(s) and ${folders.length} folder(s)');

    for (final file in files) {
      try {
        final name = file.path.split('/').last;
        await file.delete();
        log('Deleted: $name');
      } catch (e) {
        log('Skip deleting missing file: ${file.path.split('/').last}');
      }
    }
    // Clean up empty directories
    for (final folder in folders.reversed) {
      try {
        if (await folder.exists()) {
          await folder.delete(recursive: true);
          log('Removed folder: ${folder.path}');
        }
      } catch (e) {
        log('Failed to remove folder ${folder.path}: $e');
      }
    }
    downloadedVideos.value = [];
    log("Storage Cleared");
  }

  Future<void> _sendStatus() async {
    if (!socket.connected) return;

    double freeSpace = 0;
    double totalSpace = 0;

    try {
      final diskSpace = DiskSpacePlus();
      freeSpace = await diskSpace.getFreeDiskSpace ?? 0;
      totalSpace = await diskSpace.getTotalDiskSpace ?? 0;
    } catch (e) {
      log('Disk space fetch failed: $e');
    }

    final status = {
      'deviceId': deviceId,
      'status': {
        'playlistCount': downloadedVideos.value.length,
        'freeSpaceMB': freeSpace.toStringAsFixed(2),
        'totalSpaceMB': totalSpace.toStringAsFixed(2),
      },
    };

    socket.emit('device:status', status);
    log('Status sent: $status');
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
