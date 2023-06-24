import 'dart:isolate';
import 'package:arowana/arowana.dart';
import 'package:arowana/src/file_handle/file_handle.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

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

    // visit http://127.0.0.1:8888/example/example.dart
    get('/example/*path', createStaticHandler('.'));
  }
}

void main() {
  var app = Application(() => MyAChannel());
  app.start(numberOfInstances: 2, consoleLogging: true);
}
