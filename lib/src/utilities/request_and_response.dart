import 'dart:collection';
import 'dart:io';

import 'package:shelf/shelf.dart';


final _emptyParams = UnmodifiableMapView(<String, String>{});

extension RouterParams on Request {
  /// Get URL parameters captured by the [Router].
  ///
  /// **Example**
  /// ```dart
  /// final app = Router();
  ///
  /// app.get('/hello/:name', (Request request) {
  ///   final name = request.params['name'];
  ///   return Response.ok('Hello $name');
  /// });
  /// ```
  ///
  /// If no parameters are captured this returns an empty map.
  ///
  /// The returned map is unmodifiable.
  Map<String, String> get params {
    final p = context['arowana/params'];
    if (p is Map<String, String>) {
      return UnmodifiableMapView(p);
    }
    return _emptyParams;
  }

  Map<String, String> get query {
    return UnmodifiableMapView(url.queryParameters);
  }
}

extension ResponseX on Response{


  /// Represents a 400 response.
  static Response badRequest([body]){
    return Response(HttpStatus.badRequest,body: body);
  }

  /// Represents a 401 response.
  static Response unauthorized([body]){
    return Response(HttpStatus.unauthorized,body: body);
  }

  /// Represents a 500 response.
  static Response serverError([body]){
    return Response(HttpStatus.internalServerError,body: body);
  }
}