
import 'dart:async';

import 'authorizer.dart';

class TokenExpiredException implements Exception{
  String message;

  TokenExpiredException(this.message);
}

abstract class AuthValidator {
  /// Returns an [Authorization] if [authorizationData] is valid.
  ///
  /// This method is invoked by [Authorizer] to validate the Authorization header of a request. [authorizationData]
  /// is the parsed contents of the Authorization header, while [parser] is the object that parsed the header.
  ///
  /// If this method returns null, an [Authorizer] will send a 401 Unauthorized response.
  /// If this method throws an [AuthorizationParserException], a 400 Bad Request response is sent.
  FutureOr<Authorization?> validate<T>(
      AuthorizationParser<T> parser, T authorizationData);

}
