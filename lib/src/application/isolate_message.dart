import 'dart:isolate';

import 'declaration.dart';
import 'options.dart';

sealed class IsolateEvent<T> {
  T payload;

  IsolateEvent(this.payload);
}

typedef InitialPayload = (
  ApplicationOptions,
  int,
  SendPort,
  AppChannelBuilder, {
  bool logToConsole
});

class InitialServerEvent extends IsolateEvent<InitialPayload> {
  InitialServerEvent(ApplicationOptions configuration, int identifier,
      SendPort parentMessagePort, AppChannelBuilder channelBuilder,
      {bool logToConsole = false})
      : super((
          configuration,
          identifier,
          parentMessagePort,
          channelBuilder,
          logToConsole: logToConsole
        ));
}

class InitialIsolateSendPortEvent extends IsolateEvent<SendPort>{
  InitialIsolateSendPortEvent(super.payload);
}

enum CtrlType{
  started,stop,stopped
}

class ControlEvent extends IsolateEvent<CtrlType>{
  ControlEvent(super.payload);
}

class BroadcastEvent<T> extends IsolateEvent<T>{
  BroadcastEvent(super.payload);
}

class ExceptionEvent extends IsolateEvent<String>{
  ExceptionEvent(super.payload);
}