
# arowana


![](https://gitee.com/arcticfox1919/ImageHosting/raw/master/img/2021-10-17-002.png)


A lightweight HTTP server framework for Dart.It is based on the [shelf](https://github.com/dart-lang/shelf) library for handling HTTP requests and implements a high-performance routing with reference to Golang's Gin framework.


## Usage

A simple usage example:

```dart
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
    get('/hello', (r){
      return Response.ok('hello,arowana!');
    });
  }
}


void main() {
  var app = Application(MyAChannel());
  app.start(numberOfInstances: 2,consoleLogging: true);
}
```
Another example, containing grouped routes:
```dart
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
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: http://example.com/issues/replaceme
