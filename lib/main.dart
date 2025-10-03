// import 'package:billboard_tv/home.dart';
// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'BillBoard Player',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const HomeScreen(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'socket_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // SocketService instance
  final SocketService socketService = SocketService();

  MyApp({super.key}) {
    // Connect to server
    socketService.connect();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  socketService.sendMessage('Hello from button!');
                },
                child: const Text('Send Message'),
              ),
              const SizedBox(height: 20),
              // ElevatedButton(
              //   onPressed: () {
              //     // Disconnect
              //     socketService.dispose();
              //   },
              //   child: const Text('Disconnect'),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
