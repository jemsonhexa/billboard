import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:billboard_tv/localplayer.dart';
import 'package:billboard_tv/socket_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SocketService socketService = SocketService();
  bool hasInternet = true;
  bool hasStoragePermission = false;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _initConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      setState(() {
        hasStoragePermission = status.isGranted;
      });
    } else {
      hasStoragePermission = true;
    }
  }

  Future<void> _initConnectivity() async {
    try {
      final List<ConnectivityResult> result = await _connectivity
          .checkConnectivity();
      _updateConnectionStatus(result);
    } on PlatformException catch (e) {
      log(" Could not check connectivity: $e");
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final connected = !result.contains(ConnectivityResult.none);
    setState(() => hasInternet = connected);

    log('Internet: $hasInternet');

    // Always connect to server if internet available
    if (hasInternet && !socketService.isConnected) {
      socketService.connect();
    }
    // do NOT stop playback instead videos keep playing locally
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasStoragePermission) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              "Storage permission required",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ValueListenableBuilder<List<File>>(
        valueListenable: socketService.downloadedVideos,
        builder: (context, videos, _) {
          if (videos.isEmpty) {
            //if download list is empty
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  "Waiting for Server...",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          return Stack(
            children: [
              LocalOfflinePlayer(
                key: UniqueKey(),
                videos: videos,
                isPlayingNotifier: socketService.isPlaying,
              ),
              Positioned(
                bottom: MediaQuery.of(context).size.height * 0.0,
                left: MediaQuery.of(context).size.height * 0.01,
                child: hasInternet
                    ? Icon(Icons.wifi, color: Colors.green)
                    : Icon(Icons.wifi_off, color: Colors.red),
              ),
            ],
          );
        },
      ),
    );
  }
}
