import 'dart:async';
import 'dart:isolate';

import 'package:arowana/src/application/isolate_message.dart';
import 'package:logging/logging.dart';
import 'application.dart';
import 'declaration.dart';

base class IsolateServer extends ApplicationServer {
  IsolateServer(ApplicationOptions options, int identifier,
      this.supervisingApplicationPort, AppChannelBuilder channel,
      {bool logToConsole = false})
      : super(options, identifier, channel) {
    if (logToConsole) {
      hierarchicalLoggingEnabled = true;
      logger.level = Level.ALL;
      logger.onRecord.listen(print);
    }
    supervisingReceivePort = ReceivePort();
    supervisingReceivePort.listen(listener);

    logger
        .fine('ApplicationIsolateServer($identifier) listening, sending port');
    supervisingApplicationPort.send(InitialIsolateSendPortEvent(supervisingReceivePort.sendPort));
  }

  SendPort supervisingApplicationPort;
  late ReceivePort supervisingReceivePort;

  @override
  Future<bool> start({bool shareHttpServer = false}) async {
    final result = await super.start(shareHttpServer: shareHttpServer);
    logger.fine(
        'ApplicationIsolateServer($identifier) started, sending listen message');
    supervisingApplicationPort
        .send(ControlEvent(CtrlType.started));

    return result;
  }

  @override
  void sendApplicationEvent(IsolateEvent event) {
    /// TODO:
    supervisingApplicationPort.send(event);
  }

  void listener(dynamic message) {
    switch (message) {
      case ControlEvent m:
        if (m.payload == CtrlType.stop) {
          stop();
        }
        break;
      case BroadcastEvent m:
        channel?.eventHub.add(m);
        break;
    }
  }

  Future<void> stop() async {
    supervisingReceivePort.close();
    logger.fine('ApplicationIsolateServer($identifier) closing server');
    await close();
    logger.fine('ApplicationIsolateServer($identifier) did close server');
    await ServiceRegistry.defaultInstance.close();
    logger.clearListeners();
    logger.fine(
        'ApplicationIsolateServer($identifier) sending stop acknowledgement');
    supervisingApplicationPort
        .send(ControlEvent(CtrlType.stopped));
  }
}
