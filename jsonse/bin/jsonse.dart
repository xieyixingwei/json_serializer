import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'package:jsonse/json_serialize.dart';
import 'package:jsonse/cli/runner.dart';

Future main(List<String> args) async {
  
  final runner = Runner();
  final values = runner.args.parse(args);
  exitCode = await runner.process(values);
  

  //test();
}

void test() {
  final curms = currentMirrorSystem();

  for(var url in curms.libraries.keys) {
    print("--- $url = ${curms.libraries[url]?.uri.scheme}");
  }

  final declars = curms.libraries.values
    .where((lib) => lib.uri.scheme == "package" || lib.uri.scheme == "file")
    .expand((lib) => lib.declarations.values);
  for(var d in declars) {
    print("--- ${d.simpleName}");
  }

  final classes = curms.libraries.values
    .where((lib) => lib.uri.scheme == "package" || lib.uri.scheme == "file")
    .expand((lib) => lib.declarations.values).whereType<ClassMirror>().toList();;
  for(var c in classes) {
    print("--- ${c.simpleName}");
  }
}
