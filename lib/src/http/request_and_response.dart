import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../arowana.dart';
import 'body_parse.dart';


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

  bool get hasQuery =>requestedUri.hasQuery;

  Map<String, String> get query {
    return UnmodifiableMapView(url.queryParameters);
  }
}

extension BodyParams on Request{

  bool get hasFormData {
    var contentTypeStr = headers[HttpHeaders.contentTypeHeader];
    if (contentTypeStr != null) {
      var contentType = ContentType.parse(contentTypeStr);
      return contentType.primaryType == 'application' &&
          contentType.subType == 'x-www-form-urlencoded';
    }
    return false;
  }

  Future<RequestBody> get body async{
    var rb = context['arowana/RequestBody'] as RequestBody?;
    if(rb == null){
      rb = RequestBody();
      await rb.parseBody(this);
      change(context: {'arowana/RequestBody': rb});
    }
    return rb;
  }
}



extension ResponseX on Response{

  /// Constructs a 200 OK response.
  static Response ok(Map body,{Map<String,Object>? headers}){
    return Response.ok(json.encode(body),headers: headers);
  }

  /// Represents a 400 response.
  static Response badRequest(body,{Map<String,Object>? headers}){
    return Response(HttpStatus.badRequest,body: body,headers: headers);
  }

  /// Represents a 401 response.
  static Response unauthorized(body,{Map<String,Object>? headers}){
    return Response(HttpStatus.unauthorized,body: body);
  }

  /// Represents a 500 response.
  static Response serverError(body,{Map<String,Object>? headers}){
    return Response(HttpStatus.internalServerError,body: body);
  }

  static Response token(AuthToken token) {
    return Response(HttpStatus.ok,
        headers: {
          'Cache-Control': 'no-store',
          'Pragma': 'no-cache',
          HttpHeaders.contentTypeHeader: 'application/json'
        },
        body: json.encode(token.asMap()));
  }
}