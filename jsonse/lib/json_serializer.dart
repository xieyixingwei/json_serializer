

/*
// 首字母大写
String _capitalize(String str) => '${str[0].toUpperCase()}${str.substring(1)}';

enum JsonType {
  Map,
  List
}

enum ForeignType {
  Non,
  ManyToOne,
  ManyToMany,
  OneToOne
}

enum NestedType {
  Non,
  WriteRead,
  OnlyRead
}

String _jsonType(JsonType type) =>
  type == JsonType.Map ? 'Map<String, dynamic>' : 'List';

String _reName(String name) {
  name = name.trim();
  name = name.indexOf('_') > 0
        ? name.split('_').map<String>((String e) => _capitalize(e)).toList().join('')
        : _capitalize(name);
  return name;
}

String _serializerType(String name) => '${_reName(name)}Serializer';

bool _isSerializerType(String type) => type.contains('Serializer');


void main(List<String> args) {
  var js = JsonSerializeTool();
  js.run(args);
}
*/

import 'dart:io';
import 'package:jsonse/cli/commands/command.dart';
import 'package:jsonse/cli/commands/metadata.dart';

class CLIjsonserialize extends CLICommand {
  @Flag("retain-build-artifacts",
      help:
          "Whether or not the 'build' directory should be left intact after the application is compiled.",
      defaultsTo: false)
  bool get retainBuildArtifacts => decode("retain-build-artifacts");

  @Option("build-directory",
      help:
          "The directory to store build artifacts during compilation. By default, this directory is deleted when this command completes. See 'retain-build-artifacts' flag.",
      defaultsTo: "build")
  Directory get buildDirectory => Directory(decode("build-directory")).absolute;

  @override
  Future<int> handle() async {
    print("--- run json serialize");
    return 0;
  }

  @override
  Future cleanup() async {
    if (!retainBuildArtifacts) {
      if (buildDirectory.existsSync()) {
        buildDirectory.deleteSync(recursive: true);
      }
    }
  }

  @override
  String get name {
    return "build";
  }

  @override
  String get description {
    return "Creates an executable of an Aqueduct application.";
  }
}
