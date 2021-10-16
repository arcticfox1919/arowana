
class Route {
  /// HTTP verb for requests routed to the annotated method.
  final String verb;

  /// HTTP route for request routed to the annotated method.
  final String route;

  /// Create an annotation that routes requests matching [verb] and [route] to
  /// the annotated method.
  const Route(this.verb, this.route);

  /// Route `GET` requests matching [route] to annotated method.
  const Route.get(this.route) : verb = 'GET';

  /// Route `HEAD` requests matching [route] to annotated method.
  const Route.head(this.route) : verb = 'HEAD';

  /// Route `POST` requests matching [route] to annotated method.
  const Route.post(this.route) : verb = 'POST';

  /// Route `PUT` requests matching [route] to annotated method.
  const Route.put(this.route) : verb = 'PUT';

  /// Route `DELETE` requests matching [route] to annotated method.
  const Route.delete(this.route) : verb = 'DELETE';

  /// Route `CONNECT` requests matching [route] to annotated method.
  const Route.connect(this.route) : verb = 'CONNECT';

  /// Route `OPTIONS` requests matching [route] to annotated method.
  const Route.options(this.route) : verb = 'OPTIONS';

  /// Route `TRACE` requests matching [route] to annotated method.
  const Route.trace(this.route) : verb = 'TRACE';
}