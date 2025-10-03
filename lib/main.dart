import 'dart:async';
import 'dart:developer';
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
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
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

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initConnectivity() async {
    late List<ConnectivityResult> result;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException catch (e) {
      log("couldnt check $e");
      return;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      _connectionStatus = result;

      hasInternet =
          !(result.length == 1 && result.contains(ConnectivityResult.none));
    });

    log('Connectivity changed: $_connectionStatus');
    log(hasInternet.toString());
    socketService.connect();

    if (!hasInternet && socketService.videoController != null) {
      // Pause video if internet lost
      socketService.videoController!.pause();
    } else if (hasInternet && socketService.videoController != null) {
      // Resume video if internet restored
      socketService.videoController!.play();
      // Reconnect socket if needed
      if (!socketService.isConnected) socketService.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasInternet) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: const Center(
            child: Text(
              "No Internet Connection !",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'BillBoard Player',
      theme: ThemeData.dark(),
      home: ValueListenableBuilder<List<String>>(
        valueListenable: socketService.videoUrls,
        builder: (context, urls, _) {
          // log(urls.toString());
          if (urls.isNotEmpty) {
            return Player(
              videoUrls: urls,
              controllerCallback: (controller) {
                socketService.videoController = controller;
              },
            );
          } else {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }
}
