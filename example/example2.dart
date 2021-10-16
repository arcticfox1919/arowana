

import 'dart:isolate';
import 'package:arowana/arowana.dart';

class MyAChannel extends DefaultChannel{

  @override
  Future prepare() {
    print('current isolate [${Isolate.current.debugName}]');

    return super.prepare();
  }

  @override
  void entryPoint() {
    var r = group('/v1');
    r.get('/hello', (r){
      return Response.ok('hello,arowana!');
    });
  }
}


void main() {
  var app = Application(MyAChannel());
  app.start(numberOfInstances: 2,consoleLogging: true);
}
