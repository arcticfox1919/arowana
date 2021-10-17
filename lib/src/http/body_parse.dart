import 'dart:convert' as cvert;
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';

class RequestBody {
  Map<String, String>? formParams;
  Map<String, dynamic>? json;
  Map<String, List<dynamic>>? formFileParams;

  Future<void> parseBody(Request request) async {
    var headers = request.headers;
    var contentTypeStr = headers[HttpHeaders.contentTypeHeader];
    if (contentTypeStr != null) {
      var contentType = MediaType.parse(contentTypeStr);
      if (contentType.type == 'multipart' &&
          contentType.parameters.containsKey('boundary')) {
        if (contentType.parameters['boundary'] != null) {
          var parts = MimeMultipartTransformer(
              contentType.parameters['boundary']!).bind(request.read());
          await for (MimeMultipart part in parts) {
            if (part.headers['content-disposition'] != null) {
              formFileParams ??= {};
              var header = HeaderValue.parse(part.headers['content-disposition']!);
              var name = header.parameters['name'];
              var filename = header.parameters['filename'];

              if (name == null) return;

              if (filename == null) {
                var list = formFileParams![name];
                list ??= <String>[];

                var builder = await part.fold(
                    BytesBuilder(copy: false),
                    (BytesBuilder b, List<int> d) =>
                        b..add(d is! String ? d : (d as String).codeUnits));
                list.add(cvert.utf8.decode(builder.takeBytes()));
                formFileParams![name] = list;
                continue;
              }

              var list = formFileParams![name];
              list ??= <FileParams>[];

              list.add(FileParams(
                  name,
                  filename,
                  MediaType.parse(part.headers['content-type']!).mimeType,
                  part));
              formFileParams![name] = list;
            }
          }
        }
      } else if (contentType.mimeType == 'application/json') {
        var data = cvert.json.decode(await request.readAsString()) as Map;
        json = data.map<String, dynamic>(
            (key, value) => MapEntry(key.toString(), value));
      } else if (contentType.mimeType == 'application/x-www-form-urlencoded') {
        formParams = Uri.splitQueryString(await request.readAsString());
      }
    }
  }
}

/// Represents a file uploaded to the server.
class FileParams {
  /// The MIME type of the uploaded file.
  String mimeType;

  /// The name of the file field from the request.
  String name;

  /// The filename of the file.
  String filename;

  /// The bytes that make up this file.
  MimeMultipart part;

  FileParams(this.name, this.filename, this.mimeType, this.part);

  @override
  String toString() => 'filename:$filename name:$name mimeType:$mimeType';
}
