import 'dart:io';
import 'dart:isolate';
import 'package:arowana/arowana.dart';
import 'package:arowana/src/web_socket/websocket_controller.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/src/channel.dart';

base class MyAChannel extends DefaultChannel {
  @override
  Future prepare() {
    print('current isolate [${Isolate.current.debugName}]');

    return super.prepare();
  }

  @override
  void entryPoint() {
    get('/hello', (r) async {
      return Response.ok('hello,arowana! form:${Isolate.current.debugName}');
    });

    get('/ws', MyWebSocket());
  }
}

final class MyWebSocket extends WebSocketController{
  MyWebSocket() : super(null,null,null);

  @override
  void onConnection(WebSocketChannel webSocket, String? protocol) {
    webSocket.stream.listen((message) {
      webSocket.sink.add('echo $message');
    });
  }
}

void main() {
  var app = Application(() => MyAChannel());
  app.options = ApplicationOptions()
    ..address = InternetAddress('0.0.0.0', type: InternetAddressType.IPv4)
    ..port = 8110;
  app.start(numberOfInstances: 2, consoleLogging: true);
}
