import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:arowana/src/utilities/str.dart';
import 'package:http_methods/http_methods.dart';
import 'package:shelf/shelf.dart';


part 'entry.dart';



/// Middleware to remove body from request.
final _removeBody = createMiddleware(responseHandler: (r) {
  if (r.headers.containsKey('content-length')) {
    r = r.change(headers: {'content-length': '0'});
  }
  return r.change(body: <int>[]);
});

mixin class Router{

  /// The [notFoundHandler] will be invoked for requests where no matching route
  /// was found. By default, a simple [Response.notFound] will be used instead.
  Handler _notFoundHandler = _defaultNotFound;

  final Map<String, _Node> _trees = {};

  set notFoundHandler(Handler notFound){
    _notFoundHandler = notFound;
  }

  void add(String method, String route, Function handler,{Middleware? middleware}) {
    if (!isHttpMethod(method)) {
      throw ArgumentError.value(
          method, 'method', 'expected a valid HTTP method');
    }

    if (route.isEmpty || !route.startsWith('/')) {
      throw ArgumentError.value(
          method, 'route', 'path must begin with "/" in path "$route"');
    }
    method = method.toUpperCase();

    if (method == 'GET') {
      // Handling in a 'GET' request without handling a 'HEAD' request is always
      // wrong, thus, we add a default implementation that discards the body.
      _addRoute('HEAD', route, handler, middleware: _removeBody);
    }
    _addRoute(method, route, handler,middleware:middleware);
  }

  void _addRoute(String method, String path, Function handler,{Middleware? middleware}){
    var root = _trees[method];
    if(root == null){
      root = _Node.Empty();
      _trees[method] = root;
    }

    _Node.addRoute(root, path, handler,middleware);
  }

  _NodeResult _getRoute(String method, String path) {
    var root = _trees[method];
    Map<String, String>? params;
    Function? handle;
    Middleware? middleware;

    if(root != null){
      var r = _Node.getValue(root, path);
      handle = r[0] as Function?;
      params = r[1] as Map<String, String>?;
      var tsr = r[2] as bool;
      middleware = r[3] as Middleware?;

      return _NodeResult(root, params,handle,middleware);
    }
    return _NodeResult(root, params,handle,middleware);
  }

  RouterGroup group(String prefix){
    if (!prefix.startsWith('/')) {
      throw ArgumentError.value(
          prefix, 'prefix', 'must start with a slash');
    }
    return RouterGroup(prefix,this);
  }


  /// Route incoming requests to registered handlers.
  ///
  /// This method allows a Router instance to be a [Handler].
  FutureOr<Response> call(Request request) async {
    var nodeResult = _getRoute(request.method,'/${request.url.path}');

    if(nodeResult._node != null){
      var params = nodeResult._params;
      var middleware = nodeResult._middleware;
      request = request.change(context: {'arowana/params': params});

      middleware ??= ((Handler fn) => fn);

      return await middleware((request) async {
        var _handler = nodeResult._handle;
        if (_handler is Handler) {
          return await _handler.call(request);
        }

        if(_handler != null && params != null){
          return await Function.apply(_handler, [
            request,
            ...params.values,
          ]);
        }
        return _notFoundHandler(request);
      })(request);
    }
    return _notFoundHandler(request);
  }

  // Handlers for all methods

  /// Handle `GET` request to [route] using [handler].
  ///
  /// If no matching handler for `HEAD` requests is registered, such requests
  /// will also be routed to the [handler] registered here.
  void get(String route, Function handler) => add('GET', route, handler);

  /// Handle `HEAD` request to [route] using [handler].
  void head(String route, Function handler) => add('HEAD', route, handler);

  /// Handle `POST` request to [route] using [handler].
  void post(String route, Function handler) => add('POST', route, handler);

  /// Handle `PUT` request to [route] using [handler].
  void put(String route, Function handler) => add('PUT', route, handler);

  /// Handle `DELETE` request to [route] using [handler].
  void delete(String route, Function handler) => add('DELETE', route, handler);

  /// Handle `CONNECT` request to [route] using [handler].
  void connect(String route, Function handler) =>
      add('CONNECT', route, handler);

  /// Handle `OPTIONS` request to [route] using [handler].
  void options(String route, Function handler) =>
      add('OPTIONS', route, handler);

  /// Handle `TRACE` request to [route] using [handler].
  void trace(String route, Function handler) => add('TRACE', route, handler);

  /// Handle `PATCH` request to [route] using [handler].
  void patch(String route, Function handler) => add('PATCH', route, handler);

  static Response _defaultNotFound(Request request) => routeNotFound;

  /// Sentinel [Response] object indicating that no matching route was found.
  ///
  /// This is the default response value from a [Router] created without a
  /// `notFoundHandler`, when no routes matches the incoming request.
  ///
  /// If the [routeNotFound] object is returned from a [Handler] the [Router]
  /// will consider the route _not matched_, and attempt to match other routes.
  /// This is useful when mounting nested routers, or when matching a route
  /// is conditioned on properties beyond the path of the URL.
  ///
  /// **Example**
  /// ```dart
  /// final app = Router();
  ///
  /// // The pattern for this route will match '/search' and '/search?q=...',
  /// // but if request does not have `?q=...', then the handler will return
  /// // [Router.routeNotFound] causing the router to attempt further routes.
  /// app.get('/search', (Request request) async {
  ///   if (!request.uri.queryParameters.containsKey('q')) {
  ///     return Router.routeNotFound;
  ///   }
  ///   return Response.ok('TODO: make search results');
  /// });
  ///
  /// // Same pattern as above
  /// app.get('/search', (Request request) async {
  ///   return Response.ok('TODO: return search form');
  /// });
  ///
  /// // Create a single nested router we can mount for handling API requests.
  /// final api = Router();
  ///
  /// api.get('/version', (Request request) => Response.ok('1'));
  ///
  /// // Mounting router under '/api'
  /// app.mount('/api', api);
  ///
  /// // If a request matches `/api/...` then the routes in the [api] router
  /// // will be attempted. However, for a request like `/api/hello` there is
  /// // no matching route in the [api] router. Thus, the router will return
  /// // [Router.routeNotFound], which will cause matching to continue.
  /// // Hence, the catch-all route below will be matched, causing a custom 404
  /// // response with message 'nothing found'.
  /// ```
  static final Response routeNotFound = _RouteNotFoundResponse();
}

class RouterGroup{
  String prefix;
  Router parent;
  Middleware? middleware;

  RouterGroup(this.prefix,this.parent);


  void add(String method, String route, Function handler) {
    parent.add(method, prefix+route, handler,middleware: middleware);
  }

  void use(Middleware middleware){
    this.middleware = middleware;
  }

  void get(String route, Function handler) => add('GET', route, handler);

  void head(String route, Function handler) => add('HEAD', route, handler);

  void post(String route, Function handler) => add('POST', route, handler);

  void put(String route, Function handler) => add('PUT', route, handler);

  void delete(String route, Function handler) => add('DELETE', route, handler);

  void connect(String route, Function handler) => add('CONNECT', route, handler);

  void options(String route, Function handler) => add('OPTIONS', route, handler);

  void trace(String route, Function handler) => add('TRACE', route, handler);

  void patch(String route, Function handler) => add('PATCH', route, handler);
}

/// Extends [Response] to allow it to be used multiple times in the
/// actual content being served.
class _RouteNotFoundResponse extends Response {
  static const _message = 'Route not found';
  static final _messageBytes = utf8.encode(_message);

  _RouteNotFoundResponse() : super.notFound(_message);

  @override
  Stream<List<int>> read() => Stream<List<int>>.value(_messageBytes);

  @override
  Response change({
    Map<String, /* String | List<String> */ Object?>? headers,
    Map<String, Object?>? context,
    body,
  }) {
    return super.change(
      headers: headers,
      context: context,
      body: body ?? _message,
    );
  }
}