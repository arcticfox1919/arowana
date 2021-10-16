
# arowana

![](https://gitee.com/arcticfox1919/ImageHosting/raw/master/img/2021-10-17-002.png)

A lightweight HTTP server framework for Dart.


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
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: http://example.com/issues/replaceme
