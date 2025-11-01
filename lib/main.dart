import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:billboard_tv/comand.dart';
import 'package:billboard_tv/localplayer.dart';
import 'package:billboard_tv/socket_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CommandNotifier())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  CommandNotifier? commandNotifier;
  SocketService? socketService;
  bool hasInternet = true;
  bool hasStoragePermission = false;
  bool _isRequestingPermission = false;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initConnectivity();
      // Delay permission slightly to prevent race during cold start
      await Future.delayed(const Duration(milliseconds: 300));
      await _safeRequestPermission();
    });
  }

  /// Prevents overlapping permission requests
  Future<void> _safeRequestPermission() async {
    if (_isRequestingPermission) {
      log('Permission request already in progress, skipping...');
      return;
    }

    _isRequestingPermission = true;

    try {
      if (Platform.isAndroid) {
        final currentStatus = await Permission.storage.status;

        if (currentStatus.isDenied || currentStatus.isRestricted) {
          final result = await Permission.storage.request();
          hasStoragePermission = result.isGranted;
        } else {
          hasStoragePermission = currentStatus.isGranted;
        }
      } else {
        hasStoragePermission = true;
      }

      if (mounted) setState(() {});
    } catch (e, st) {
      log('Permission request error: $e\n$st');
    } finally {
      _isRequestingPermission = false;
    }

    if (hasStoragePermission) {
      await _initSocket();
    }
  }

  Future<void> _initSocket() async {
    commandNotifier = CommandNotifier();
    socketService = SocketService(commandNotifier: commandNotifier!);
    socketService!.connect();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } on PlatformException catch (e) {
      log("Could not check connectivity: $e");
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final connected = !result.contains(ConnectivityResult.none);
    if (mounted) {
      setState(() => hasInternet = connected);
    }

    log('Internet: $hasInternet');
    if (hasInternet && socketService != null && !socketService!.isConnected) {
      socketService!.connect();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    socketService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasStoragePermission) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              "📂 Storage permission required",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (socketService == null || commandNotifier == null) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: commandNotifier!),
        Provider.value(value: socketService!),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ValueListenableBuilder<List<File>>(
          valueListenable: socketService!.downloadedVideos,
          builder: (context, videos, _) {
            if (videos.isEmpty) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: socketService!.isDownloading,
                    builder: (_, downloading, __) {
                      final text = socketService!.isConnected
                          ? (downloading
                                ? "Downloading videos..."
                                : "Connected, waiting for playlist...")
                          : "Waiting for Server...";

                      return Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      );
                    },
                  ),
                ),
              );
            }

            return Stack(
              children: [
                LocalOfflinePlayer(
                  videos: videos,
                  isPlayingNotifier: socketService!.isPlaying,
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Row(
                    children: [
                      Icon(
                        hasInternet ? Icons.wifi : Icons.wifi_off,
                        color: hasInternet ? Colors.green : Colors.red,
                      ),
                      Text(
                        socketService!.downloadedVideos.value.length.toString(),
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
