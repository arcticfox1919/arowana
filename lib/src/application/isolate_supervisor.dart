import 'dart:async';
import 'dart:isolate';

import 'package:arowana/src/application/isolate_message.dart';
import 'package:logging/logging.dart';

import 'application.dart';
import 'isolate_server.dart';

/// Represents the supervision of a [IsolateServer].
///
/// You should not use this class directly.
class ApplicationIsolateSupervisor {
  /// Create an instance of [ApplicationIsolateSupervisor].
  ApplicationIsolateSupervisor(
      this.supervisingApplication, this.isolate,
      this.receivePort, this.identifier, this.logger,
      {this.startupTimeout = const Duration(seconds: 30)});

  /// The [Isolate] being supervised.
  final Isolate isolate;

  /// The [ReceivePort] for which messages coming from [isolate] will be received.
  final ReceivePort receivePort;

  /// A numeric identifier for the isolate relative to the [Application].
  final int identifier;

  final Duration startupTimeout;

  /// A reference to the owning [Application]
  Application supervisingApplication;

  /// A reference to the [Logger] used by the [supervisingApplication].
  Logger logger;

  final List<BroadcastEvent> _pendingMessageQueue = [];

  bool get _isLaunching => _launchCompleter != null;

  SendPort? _serverSendPort;
  Completer ?_launchCompleter;
  Completer? _stopCompleter;

  /// Resumes the [Isolate] being supervised.
  Future resume() {
    _launchCompleter = Completer();
    receivePort.listen(listener);

    isolate.setErrorsFatal(false);
    isolate.addErrorListener(receivePort.sendPort);
    logger.fine(
        'ApplicationIsolateSupervisor($identifier).resume will resume isolate');

    isolate.resume(isolate.pauseCapability!);

    _launchCompleter!.future.catchError((e,s){
      throw Exception(e);
    });

    return _launchCompleter!.future.timeout(startupTimeout, onTimeout: () {
      logger.fine(
          'ApplicationIsolateSupervisor($identifier).resume timed out waiting for isolate start');
      throw TimeoutException(
          'Isolate ($identifier) failed to launch in $startupTimeout seconds. '
              'There may be an error with your application or Application.isolateStartupTimeout needs to be increased.');
    });
  }

  /// Stops the [Isolate] being supervised.
  Future stop() async {
    _stopCompleter = Completer();
    logger.fine(
        'ApplicationIsolateSupervisor($identifier).stop sending stop to supervised isolate');
    _serverSendPort?.send(ControlEvent(CtrlType.stop));

    try {
      await _stopCompleter!.future.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      logger.severe(
          'Isolate ($identifier) not responding to stop message, terminating.');
      isolate.kill();
    }

    receivePort.close();
  }

  void listener(dynamic message) {
    switch (message) {
      case InitialIsolateSendPortEvent m:
        _serverSendPort = m.payload;
        break;
      case BroadcastEvent m:
        if (!supervisingApplication.isRunning) {
          _pendingMessageQueue.add(m);
        } else {
          _sendToOtherSupervisors(m);
        }
        break;
      case ControlEvent m:
        if (m.payload == CtrlType.started) {
          _launchCompleter?.complete();
          _launchCompleter = null;
          logger.fine(
              'ApplicationIsolateSupervisor($identifier) isolate listening acknowledged');
        } else if (m.payload == CtrlType.stopped) {
          logger.fine(
              'ApplicationIsolateSupervisor($identifier) stop message acknowledged');
          receivePort.close();
          _stopCompleter?.complete();
        }
        break;
      case ExceptionEvent m:
        logger.fine(
            'ApplicationIsolateSupervisor($identifier) received isolate error ${m.payload}');
        final stacktrace = StackTrace.fromString(m.payload);
        _handleIsolateException(m.payload, stacktrace);
        break;
    }
  }

  void sendPendingMessages() {
    final list = List<BroadcastEvent>.from(_pendingMessageQueue);
    _pendingMessageQueue.clear();
    list.forEach(_sendToOtherSupervisors);
  }

  void _sendToOtherSupervisors(BroadcastEvent message) {
    supervisingApplication.supervisors
        .where((sup) => sup != this)
        .forEach((supervisor) {
      supervisor._serverSendPort?.send(message);
    });
  }

  void _handleIsolateException(dynamic error, StackTrace stacktrace) {
    if (_isLaunching) {
      final appException = ApplicationStartupException(error);
      _launchCompleter?.completeError(appException, stacktrace);
    } else {
      logger.severe('Uncaught exception in isolate.', error, stacktrace);
    }
  }
}
