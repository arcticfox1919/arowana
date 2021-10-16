import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'app_channel.dart';
import 'application.dart';

import 'options.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Listens for HTTP requests and delivers them to its [ApplicationChannel] instance.
///
/// An Aqueduct application creates instances of this type to pair an HTTP server and an
/// instance of an [ApplicationChannel] subclass. Instances are created by [Application]
/// and shouldn't be created otherwise.
class ApplicationServer {
  /// Creates a new server.
  ///
  /// You should not need to invoke this method directly.
  ApplicationServer(this.options, this.identifier,this.channel);

  /// The configuration this instance used to start its [channel].
  ApplicationOptions options;

  /// The underlying [HttpServer].
  late HttpServer server;

  AppChannel channel;

  /// Target for sending messages to other [ApplicationChannel.messageHub]s.
  ///
  /// Events are added to this property by instances of [ApplicationMessageHub] and should not otherwise be used.
  late EventSink<dynamic> hubSink;

  /// Whether or not this server requires an HTTPS listener.
  bool get requiresHTTPS => _requiresHTTPS;
  bool _requiresHTTPS = false;

  /// The unique identifier of this instance.
  ///
  /// Each instance has its own identifier, a numeric value starting at 1, to identify it
  /// among other instances.
  int identifier;

  /// The logger of this instance
  Logger get logger => Logger('arowana');

  /// Starts this instance, allowing it to receive HTTP requests.
  ///
  /// Do not invoke this method directly.
  Future start({bool shareHttpServer = false}) async {
    logger.fine('ApplicationServer($identifier).start entry');

    await channel.prepare();

    channel.entryPoint();

    logger.fine('ApplicationServer($identifier).start binding HTTP');

    _requiresHTTPS = securityContext != null;

    await shelf_io.serve(channel, options.address, options.port,
        securityContext: securityContext,shared: shareHttpServer);

    logger.fine('ApplicationServer($identifier).start bound HTTP');
    return Future.value(true);
  }

  SecurityContext? get securityContext {
    if (options.certificateFilePath == null ||
        options.privateKeyFilePath == null) {
      return null;
    }

    return SecurityContext()
      ..useCertificateChain(options.certificateFilePath!)
      ..usePrivateKey(options.privateKeyFilePath!);
  }

  /// Closes this HTTP server and channel.
  Future close() async {
    logger.fine('ApplicationServer($identifier).close Closing HTTP listener');
    await server.close(force: true);
    logger.fine('ApplicationServer($identifier).close Closing channel');

    // This is actually closed by channel.messageHub.close, but this shuts up the analyzer.
    hubSink.close();
    logger.fine('ApplicationServer($identifier).close Closing complete');
  }

  void sendApplicationEvent(dynamic event) {
    // By default, do nothing
  }
}
