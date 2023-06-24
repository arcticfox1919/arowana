import 'dart:async';
import 'package:arowana/src/application/isolate_message.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'application.dart';

abstract base class AppChannel {
  final ApplicationEventHub eventHub = ApplicationEventHub();

  /// The configuration options used to start the application this channel belongs to.
  Future<void> initialize(ApplicationOptions options) async {}

  Future<void> prepare() async {}

  void entryPoint();

  void emitEvent<T>(T event) {
    eventHub.add(BroadcastEvent<T>(event));
  }

  void onEvent<T>(void Function(T data) listener){
    eventHub.listen((event) {
      listener(event.payload as T);
    });
  }

  Future<void> dispose()async{
    await eventHub.close();
  }

  FutureOr<Response> call(Request request);
}

class ApplicationEventHub extends Stream<BroadcastEvent>
    implements Sink<BroadcastEvent> {
  final Logger _logger = Logger('arowana');
  final StreamController<BroadcastEvent> _outboundController =
      StreamController<BroadcastEvent>();
  final StreamController<BroadcastEvent> _inboundController =
      StreamController<BroadcastEvent>.broadcast();

  /// Adds a listener for messages from other hubs.
  ///
  /// You use this method to add listeners for messages from other hubs.
  /// When another hub [add]s a message, this hub will receive it on [onData].
  ///
  /// [onError], if provided, will be invoked when this isolate tries to [add] invalid data. Only the isolate
  /// that failed to send the data will receive [onError] events.
  @override
  StreamSubscription<BroadcastEvent> listen(
          void Function(BroadcastEvent event)? onData,
          {Function? onError,
          void Function()? onDone,
          bool? cancelOnError = false}) =>
      _inboundController.stream.listen(onData,
          onError: onError ??
              (err, StackTrace st) =>
                  _logger.severe('ApplicationEventHub error', err, st),
          onDone: onDone,
          cancelOnError: cancelOnError);

  /// Sends a message to all other hubs.
  ///
  /// [event] will be delivered to all other isolates that have set up a callback for [listen].
  ///
  /// [event] must be isolate-safe data - in general, this means it may not be or contain a closure. Consult the API reference `dart:isolate` for more details. If [event]
  /// is not isolate-safe data, an error is delivered to [listen] on this isolate.
  @override
  void add(BroadcastEvent event) {
    _outboundController.sink.add(event);
  }

  @override
  Future<void> close() async {
    if (!_outboundController.hasListener) {
      _outboundController.stream.listen(null);
    }

    if (!_inboundController.hasListener) {
      _inboundController.stream.listen(null);
    }

    await _outboundController.close();
    await _inboundController.close();
  }
}
