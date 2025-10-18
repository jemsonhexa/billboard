import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:billboard_tv/download.dart';
import 'package:billboard_tv/localplayer.dart';
import 'package:billboard_tv/videoplayer.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'socket_service.dart';

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
  List<ConnectivityResult> connectionStatus = [ConnectivityResult.none];
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      log("couldnt check $e");
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      connectionStatus = result;
      hasInternet =
          !(result.length == 1 && result.contains(ConnectivityResult.none));
    });

    log('Internet - ${hasInternet.toString()}');
    socketService.connect();
    if (!hasInternet && socketService.videoController != null) {
      // Pause video if internet lost
      socketService.videoController!.pause();
    } else if (hasInternet && socketService.videoController != null) {
      // Resume video if internet restored
      socketService.videoController!.play();
      // Reconnect socket if needed
      if (!socketService.isConnected) {
        log("server disconnect");
        socketService.connect();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasInternet) {
      return FutureBuilder<List<File>>(
        future: getDownloadedVideos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Text(
                    "Connection in Progress...",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.black,
                body: const Center(
                  child: Text(
                    "Error loading offline videos",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            );
          }
          final videos = snapshot.data ?? [];
          // 🔹 If downloaded videos exist → play offline
          if (videos.isNotEmpty) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Stack(
                children: [
                  LocalOfflinePlayer(videos: videos),
                  // Red dot bottom-right
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.01,
                    left: MediaQuery.of(context).size.height * 0.01,
                    child: Icon(Icons.wifi_off_rounded, color: Colors.red),
                  ),
                ],
              ),
            );
          }
          return MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: const Center(
                child: Text(
                  "No Internet Connection!\nNo downloaded videos found.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
          );
        },
      );
    }

    return MaterialApp(
      title: 'BillBoard Player',
      theme: ThemeData.dark(),
      home: ValueListenableBuilder<List<String>>(
        valueListenable: socketService.videoUrls,
        builder: (context, urls, _) {
          if (urls.isNotEmpty) {
            return Stack(
              children: [
                Player(
                  key: UniqueKey(),
                  videoUrls: urls,
                  controllerCallback: (betterPlayerController) {
                    socketService.videoController = betterPlayerController;
                  },
                ),
                if (hasInternet)
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.01,
                    left: MediaQuery.of(context).size.height * 0.01,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          } else {
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
        },
      ),
    );
  }
}
