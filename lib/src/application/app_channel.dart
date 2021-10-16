import 'dart:async';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'application.dart';

abstract class AppChannel{
  /// The configuration options used to start the application this channel belongs to.
  ///
  /// These options are set when starting the application. Changes to this object have no effect
  /// on other isolates.
  late ApplicationOptions appOptions;

  final ApplicationMessageHub messageHub = ApplicationMessageHub();

  Future initialize(ApplicationOptions options) async{}

  Future prepare()async{}

  void entryPoint();

  FutureOr<Response> call(Request request);
}

class ApplicationMessageHub extends Stream<dynamic> implements Sink<dynamic> {
  final Logger _logger = Logger('arowana');
  final StreamController<dynamic> _outboundController =
  StreamController<dynamic>();
  final StreamController<dynamic> _inboundController =
  StreamController<dynamic>.broadcast();

  /// Adds a listener for messages from other hubs.
  ///
  /// You use this method to add listeners for messages from other hubs.
  /// When another hub [add]s a message, this hub will receive it on [onData].
  ///
  /// [onError], if provided, will be invoked when this isolate tries to [add] invalid data. Only the isolate
  /// that failed to send the data will receive [onError] events.
  @override
  StreamSubscription<dynamic> listen(void Function(dynamic event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError=false}) =>
      _inboundController.stream.listen(onData,
          onError: onError ??
                  (err, StackTrace st) =>
                  _logger.severe('ApplicationMessageHub error', err, st),
          onDone: onDone,
          cancelOnError: cancelOnError);

  /// Sends a message to all other hubs.
  ///
  /// [event] will be delivered to all other isolates that have set up a callback for [listen].
  ///
  /// [event] must be isolate-safe data - in general, this means it may not be or contain a closure. Consult the API reference `dart:isolate` for more details. If [event]
  /// is not isolate-safe data, an error is delivered to [listen] on this isolate.
  @override
  void add(dynamic event) {
    _outboundController.sink.add(event);
  }

  @override
  Future close() async {
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