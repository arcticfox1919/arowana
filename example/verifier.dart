


import 'dart:async';

import 'package:arowana/arowana.dart';


class AuthVerifier extends AuthValidator{


  @override
  FutureOr<Authorization?> validate<T>(AuthorizationParser<T> parser, T authorizationData) {
    if (parser is AuthorizationBearerParser) {
      return _verify(authorizationData as String);
    }
    throw ArgumentError(
        "Invalid 'parser' for 'AuthValidator.validate'. Use 'AuthorizationBearerHeader'.");
  }

  Future<Authorization?> _verify(String accessToken) async {

  }
}