import 'dart:developer';
import 'package:socket_io_client/socket_io_client.dart' as socketservice;

class SocketService {
  late socketservice.Socket socket;

  void connect() {
    // pc IP
    String url = 'http://10.114.20.151:3000';

    socket = socketservice.io(
      url,
      socketservice.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    socket.connect();
    //when connected
    socket.onConnect((_) {
      log('Connected to server');
      socket.emit('msg', 'Client says hello');
    });
    //recieve msg from servr
    socket.on('fromServer', (data) {
      log('Message from server: $data');
    });

    socket.on('video', (url) {
      print('Play this video: $url');
      // Pass `url` to VideoPlayerController

      // _controller = VideoPlayerController.network(url)
      //   ..initialize().then((_) {
      //     _controller.play();
      //   });
    });

    //when disconnect
    socket.onDisconnect((_) => log('Disconnected'));
    socket.onError((err) => log('Socket error: $err'));
  }

  void sendMessage(String msg) {
    socket.emit('msg', msg);
  }

  void dispose() {
    socket.dispose();
  }
}
