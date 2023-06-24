import 'dart:async';
import 'dart:io';

void main() async {
  final url = 'ws://127.0.0.1:8110/ws';

  try {
    final webSocket = await WebSocket.connect(url);

    webSocket.listen(
          (data) {
        print('received data: $data');
      },
      onError: (error) {
        print('WebSocket ERROR: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
      cancelOnError: true,
    );

    webSocket.add('hello，WebSocket！');

    await Future.delayed(Duration(seconds: 5));
    await webSocket.close();
  } catch (e) {
    print('Can\'t connect to WebSocket server: $e');
  }
}