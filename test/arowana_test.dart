

import 'dart:convert';

import 'package:arowana/arowana.dart';
import 'package:test/test.dart';

const routes = <String>[
  '/hi',
  '/contact',
  '/co',
  '/c',
  '/a',
  '/ab',
  '/doc/',
  '/doc/go_faq.html',
  '/doc/go1.html',
];

Handler fakeHandler(String val){
  return (request){
    return Response.ok(val);
  };
}

void main() {
  group('A group of router tree tests', () {
    Router? router;

    setUp(() {
      router = Router();
      for(var path in routes){
        router?.get(path, fakeHandler(path));
      }
    });

    test('First Test', () async{
      for(var path in routes){
        var r = Request('GET',Uri.parse('https://localhost$path'));
        var req = await router?.call(r);
        if(req!=null){
          var content = await req.readAsString();
          expect(content, path);
        }
      }
    });
  });
}

