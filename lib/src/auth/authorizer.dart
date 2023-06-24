
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'validator.dart';


class Auth{

  Auth(this.validator, {this.parser = const AuthorizationBearerParser()});

  /// Creates an instance of [Auth] with Basic Authentication parsing.
  ///
  /// Parses a username and password from the request's Basic Authentication data in the Authorization header, e.g.:
  ///
  ///         Authorization: Basic base64(username:password)
  Auth.basic(AuthValidator validator)
      : this(validator, parser: const AuthorizationBasicParser());

  /// Creates an instance of [Auth] with Bearer token parsing.
  ///
  /// Parses a bearer token from the request's Authorization header, e.g.
  ///
  ///         Authorization: Bearer ap9ijlarlkz8jIOa9laweo
  ///
  /// If [scopes] is provided, the bearer token must have access to *all* scopes according to [validator].
  Auth.bearer(AuthValidator validator)
      : this(validator,
      parser: const AuthorizationBearerParser());

  /// The validating authorization object.
  ///
  /// This object will check credentials parsed from the Authorization header and produce an
  /// [Authorization] object representing the authorization the credentials have. It may also
  /// reject a request. This is typically an instance of [AuthServer].
  final AuthValidator validator;


  /// Parses the Authorization header.
  ///
  /// The parser determines how to interpret the data in the Authorization header. Concrete subclasses
  /// are [AuthorizationBasicParser] and [AuthorizationBearerParser].
  ///
  /// Once parsed, the parsed value is validated by [validator].
  final AuthorizationParser parser;


  Handler call(Handler innerHandler){

    return (r)async{
      var authData = r.headers[HttpHeaders.authorizationHeader];

      if (authData == null) {
        return Response.unauthorized('Unauthorized');
      }

      try {
        final value = parser.parse(authData);
        var authorization = await validator.validate(parser, value);
        if (authorization == null) {
          return Response.unauthorized('Unauthorized');
        }
        return innerHandler(r);
      } on TokenExpiredException catch(e){
        return Response.unauthorized(e.message);
      } on AuthorizationParserException catch (e) {
        return _responseFromParseException(e);
      }
    };
  }

  Response _responseFromParseException(AuthorizationParserException e) {
    switch (e.reason) {
      case AuthorizationParserExceptionReason.malformed:
        return Response.badRequest(body: 'Error: invalid_authorization_header');
      case AuthorizationParserExceptionReason.missing:
        return Response.unauthorized('Unauthorized');
      default:
        return Response.internalServerError(body: 'Internal Server Error');
    }
  }
}

abstract class AuthorizationParser<T> {
  const AuthorizationParser();

  T parse(String? authorizationHeader);
}

/// Parses a Bearer token from an Authorization header.
class AuthorizationBearerParser extends AuthorizationParser<String> {
  const AuthorizationBearerParser();

  /// Parses a Bearer token from [authorizationHeader]. If the header is malformed or doesn't exist,
  /// throws an [AuthorizationParserException]. Otherwise, returns the [String] representation of the bearer token.
  ///
  /// For example, if the input to this method is "Bearer token" it would return 'token'.
  ///
  /// If [authorizationHeader] is malformed or null, throws an [AuthorizationParserException].
  @override
  String parse(String? authorizationHeader) {
    if (authorizationHeader == null) {
      throw AuthorizationParserException(
          AuthorizationParserExceptionReason.missing);
    }

    final matcher = RegExp('Bearer (.+)');
    final match = matcher.firstMatch(authorizationHeader);
    if (match == null) {
      throw AuthorizationParserException(
          AuthorizationParserExceptionReason.malformed);
    }
    return match[1]!;
  }
}

/// A structure to hold Basic authorization credentials.
///
/// See [AuthorizationBasicParser] for getting instances of this type.
class AuthBasicCredentials {
  /// The username of a Basic Authorization header.
  String? username;

  /// The password of a Basic Authorization header.
  String? password;

  @override
  String toString() => '$username:$password';
}

/// Parses a Basic Authorization header.
class AuthorizationBasicParser
    extends AuthorizationParser<AuthBasicCredentials> {
  const AuthorizationBasicParser();

  /// Returns a [AuthBasicCredentials] containing the username and password
  /// base64 encoded in [authorizationHeader]. For example, if the input to this method
  /// was 'Basic base64String' it would decode the base64String
  /// and return the username and password by splitting that decoded string around the character ':'.
  ///
  /// If [authorizationHeader] is malformed or null, throws an [AuthorizationParserException].
  @override
  AuthBasicCredentials parse(String? authorizationHeader) {
    if (authorizationHeader == null) {
      throw AuthorizationParserException(
          AuthorizationParserExceptionReason.missing);
    }

    final matcher = RegExp('Basic (.+)');
    final match = matcher.firstMatch(authorizationHeader);
    if (match == null) {
      throw AuthorizationParserException(
          AuthorizationParserExceptionReason.malformed);
    }

    final base64String = match[1]!;
    String decodedCredentials;
    try {
      decodedCredentials =
          String.fromCharCodes(const Base64Decoder().convert(base64String));
    } catch (e) {
      throw AuthorizationParserException(
          AuthorizationParserExceptionReason.malformed);
    }

    final splitCredentials = decodedCredentials.split(':');
    if (splitCredentials.length != 2) {
      throw AuthorizationParserException(
          AuthorizationParserExceptionReason.malformed);
    }

    return AuthBasicCredentials()
      ..username = splitCredentials.first
      ..password = splitCredentials.last;
  }
}

class Authorization {
  /// Creates an instance of a [Authorization].
  Authorization(this.id,this.validator,
      {this.credentials});

  final String id;

  /// The [AuthValidator] that granted this permission.
  final AuthValidator validator;

  /// Basic authorization credentials, if provided.
  ///
  /// If this instance represents the authorization header of a request with basic authorization credentials,
  /// the parsed credentials will be available in this property. Otherwise, this value is null.
  final AuthBasicCredentials? credentials;
}

class AuthToken {
  /// The value to be passed as a Bearer Authorization header.
  String accessToken;

  /// The value to be passed for refreshing a token.
  String? refreshToken;

  /// The time this token was issued on.
  DateTime issueDate;

  /// The time when this token expires.
  DateTime expirationDate;

  AuthToken(this.accessToken, this.issueDate, this.expirationDate,
      [this.refreshToken]);

  /// Whether or not this token is expired by evaluated [expirationDate].
  bool get isExpired {
    return expirationDate.difference(DateTime.now().toUtc()).inSeconds <= 0;
  }

  /// Emits this instance as a [Map] according to the OAuth 2.0 specification.
  Map<String, dynamic> asMap() {
    final map = {
      'access_token': accessToken,
      'expires_in': expirationDate.difference(DateTime.now().toUtc()).inSeconds,
    };

    if (refreshToken != null) {
      map['refresh_token'] = refreshToken!;
    }

    return map;
  }
}

/// The reason either [AuthorizationBearerParser] or [AuthorizationBasicParser] failed.
enum AuthorizationParserExceptionReason { missing, malformed}

/// An exception indicating why Authorization parsing failed.
class AuthorizationParserException implements Exception {
  AuthorizationParserException(this.reason);

  AuthorizationParserExceptionReason reason;
}