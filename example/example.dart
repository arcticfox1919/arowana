import 'dart:async';
import 'dart:isolate';

import 'package:arowana/arowana.dart';

class MyAChannel extends AppChannel {
  Router app = Router();

  Middleware verification() => (innerHandler) {
        return (request) async {
          if (request.query['name'] == 'abc' &&
              request.query['pass'] == '123') {
            return await innerHandler(request);
          } else {
            return ResponseX.unauthorized('Authentication failed !!!');
          }
        };
      };

  @override
  void entryPoint() {
    var r1 = app.group('/v1');

    // var middleware = Pipeline().addMiddleware(verification()).middleware;
    r1.use(verification());
    r1.get('/hello', (Request request) {
      return Response.ok('hello-world');
    });

    r1.get('/greet/:name', (Request request, String name) {
      return Response.ok('Hi,$name');
    });

    var r2 = app.group('/v2');
    r2.get('/hello', (Request request) {
      return Response.ok('hello,arowana');
    });
    r2.get('/user/:name', (Request request, String user) {
      return Response.ok('hello, $user');
    });
  }

  @override
  FutureOr<Response> call(Request request) {
    print('current isolate [${Isolate.current.debugName}]');
    return app.call(request);
  }
}

void main() {
  var app = Application(MyAChannel());
  app.options = ApplicationOptions()..address = '127.0.0.1';
  app.start(numberOfInstances: 2,consoleLogging: true);
}
