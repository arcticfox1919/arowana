import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:logging/logging.dart';
import 'app_channel.dart';
import 'application_server.dart';
import 'isolate_application_server.dart';
import 'isolate_supervisor.dart';
import 'options.dart';
import 'service_registry.dart';

export 'application_server.dart';
export 'options.dart';
export 'service_registry.dart';

/// This object starts and stops instances of your [ApplicationChannel].
///
/// An application object opens HTTP listeners that forward requests to instances of your [ApplicationChannel].
/// It is unlikely that you need to use this class directly - the `arowana serve` command creates an application object
/// on your behalf.
class Application {

  Application(this.channel);

  /// A list of isolates that this application supervises.
  List<ApplicationIsolateSupervisor> supervisors = [];

  /// The [ApplicationServer] listening for HTTP requests while under test.
  ///
  /// This property is only valid when an application is started via [startOnCurrentIsolate].
  ApplicationServer? server;

  AppChannel channel;

  /// The logger that this application will write messages to.
  ///
  /// This logger's name will appear as 'arowana'.
  Logger logger = Logger('arowana');

  /// The options used to configure this application.
  ///
  /// Changing these values once the application has started will have no effect.
  ApplicationOptions options = ApplicationOptions();

  /// The duration to wait for each isolate during startup before failing.
  ///
  /// A [TimeoutException] is thrown if an isolate fails to startup in this time period.
  ///
  /// Defaults to 30 seconds.
  Duration isolateStartupTimeout = const Duration(seconds: 30);

  /// Whether or not this application is running.
  ///
  /// This will return true if [start]/[startOnCurrentIsolate] have been invoked and completed; i.e. this is the synchronous version of the [Future] returned by [start]/[startOnCurrentIsolate].
  ///
  /// This value will return to false after [stop] has completed.
  bool get isRunning => _hasFinishedLaunching;
  bool _hasFinishedLaunching = false;

  /// Starts this application, allowing it to handle HTTP requests.
  ///
  /// This method spawns [numberOfInstances] isolates, instantiates your application channel
  /// for each of these isolates, and opens an HTTP listener that sends requests to these instances.
  ///
  /// The [Future] returned from this method will complete once all isolates have successfully started
  /// and are available to handle requests.
  ///
  /// If your application channel implements [ApplicationChannel.initializeApplication],
  /// it will be invoked prior to any isolate being spawned.
  ///
  /// See also [startOnCurrentIsolate] for starting an application when running automated tests.
  Future start({int numberOfInstances = 1, bool consoleLogging = false}) async {
    if (server != null || supervisors.isNotEmpty) {
      throw StateError(
          "Application error. Cannot invoke 'start' on already running Aqueduct application.");
    }

    if (options.address == null) {
      if (options.isIpv6Only) {
        options.address = InternetAddress.anyIPv6;
      } else {
        options.address = InternetAddress.anyIPv4;
      }
    }

    try {
      channel.appOptions = options;
      await channel.initialize(options);

      for (var i = 0; i < numberOfInstances; i++) {
        final supervisor = await _spawn(
            this,channel, options, i + 1, logger, isolateStartupTimeout,
            logToConsole: consoleLogging);
        supervisors.add(supervisor);
        await supervisor.resume();
      }
    } catch (e, st) {
      logger.severe('$e', this, st);
      await stop().timeout(const Duration(seconds: 5));
      rethrow;
    }
    supervisors.forEach((sup) => sup.sendPendingMessages());
    _hasFinishedLaunching = true;
  }

  /// Starts the application on the current isolate, and does not spawn additional isolates.
  ///
  /// An application started in this way will run on the same isolate this method is invoked on.
  /// Performance is limited when running the application with this method; prefer to use [start].
  Future startOnCurrentIsolate() async {
    if (server != null || supervisors.isNotEmpty) {
      throw StateError(
          "Application error. Cannot invoke 'test' on already running Aqueduct application.");
    }

    options.address ??= InternetAddress.loopbackIPv4;

    try {
      channel.appOptions = options;
      await channel.initialize(options);
      server = ApplicationServer(options, 1,channel);

      await server!.start();
      _hasFinishedLaunching = true;
    } catch (e, st) {
      logger.severe('$e', this, st);
      await stop().timeout(const Duration(seconds: 5));
      rethrow;
    }
  }

  /// Stops the application from running.
  ///
  /// Closes every isolate and their channel and stops listening for HTTP requests.
  /// The [ServiceRegistry] will close any of its resources.
  Future stop() async {
    _hasFinishedLaunching = false;
    await Future.wait(supervisors.map((s) => s.stop()));
    await server?.server.close(force: true);

    await ServiceRegistry.defaultInstance.close();
    _hasFinishedLaunching = false;
    server = null;
    supervisors = [];

    logger.clearListeners();
  }

  Future<ApplicationIsolateSupervisor> _spawn(
      Application application,
      AppChannel channel,
      ApplicationOptions config,
      int identifier,
      Logger logger,
      Duration startupTimeout,
      {bool logToConsole = false}) async {
    final receivePort = ReceivePort();

    final initialMessage = ApplicationInitialServerMessage(
        config, identifier, receivePort.sendPort,channel,
        logToConsole: logToConsole);

    final isolate = await Isolate.spawn(isolateServerEntryPoint, initialMessage,
        paused: true,debugName: 'Worker id:$identifier');

    return ApplicationIsolateSupervisor(
        application, isolate, receivePort, identifier, logger,
        startupTimeout: startupTimeout);
  }
}

void isolateServerEntryPoint(ApplicationInitialServerMessage params) {
  final server = ApplicationIsolateServer(params.configuration,
      params.identifier, params.parentMessagePort, params.channel,
      logToConsole: params.logToConsole);
  server.start(shareHttpServer: true);
}

/// Thrown when an application encounters an exception during startup.
///
/// Contains the original exception that halted startup.
class ApplicationStartupException implements Exception {
  ApplicationStartupException(this.originalException);

  dynamic originalException;

  @override
  String toString() => originalException.toString();
}
