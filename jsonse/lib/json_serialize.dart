library jsonse;

import 'dart:convert';
import 'dart:io';
import 'package:jsonse/model.dart';
import 'package:path/path.dart' as path;

class JsonSerialize {

  JsonSerialize({
    required String input,
    required String output,
    required String configfile
  }) {
    init(input, output, configfile);
  }

  late final String outputDir;
  late final String outputDirName;
  late final Map<String, dynamic> config;

  final List<String> jsons = [];
  final List<Model> models = [];

  void init(String input, String output, String configfile) {
    final inf = File(input);

    if(inf.statSync().type == FileSystemEntityType.notFound) {
      throw(StateError("*** ERROR: $input is not exist."));
    }

    if(inf.statSync().type != FileSystemEntityType.directory) {
      throw(StateError("*** ERROR: $input must be a directory."));
    }

    final ind = Directory(input);
    ind.listSync(recursive: true).forEach((e) {
      final jf = File(e.path);
      if ( jf.statSync().type == FileSystemEntityType.file
        && jf.path.endsWith(".json")
        && !path.basename(jf.path).startsWith("_")
        && path.basename(jf.path) != "_config.json") {
        jsons.add(e.path);
      }
    });

    if(output == "models") {
      final parentDir = ind.parent.uri.toFilePath(windows:Platform.isWindows);
      output = path.join(parentDir, output);
    }

    outputDir = output;
    outputDirName = path.basename(output);

    final out = Directory(outputDir);
    if(!out.existsSync()) {
      out.createSync(recursive:true);
    }

    if(configfile == "_config.json") {
      final configDir = ind.uri.toFilePath(windows:Platform.isWindows);
      configfile = path.join(configDir, configfile);
    }

    final cf = File(configfile);
    if (cf.statSync().type == FileSystemEntityType.file)
      _parseConfigFile(cf);
  }

  List<String> _splitJsons(String src) {
    List<String> ret = [];
    String? left;
    String? right;
    int count = 0;
    String one = "";
    src.split("").forEach((e) {
      if(left == null && "{[".contains(e)) {
        left = e;
        right = left == "{" ? "}" : "]";
      }
      if(left != null && e == left) count++;
      if(right != null && e == right) count--;
      one += e;
      if(left != null && count == 0) {
        ret.add(one);
        one = "";
        left = null;
        right = null;
      }
    });
    return ret;
  }

  String _removeComments(List<String> lines) {
    String content = "";
    lines.forEach(
      (String line) {
        int pos = line.indexOf("//"); // comment char is "//"
        if(pos != -1) {
          line = line.substring(0, pos);
        }
        content += line + "\n";
      }
    );
    return content;
  }

  void _parseConfigFile(File cf) {
    try{
      config = json.decode(_removeComments(cf.readAsLinesSync()));
    } catch(e) {
      throw(StateError("*** ERROR: from \"$config\" parse Json Error: $e"));
    }
  }

  Future run() async {
    jsons.forEach((json) {
      List<String> lines = File(json).readAsLinesSync();
      String src = _removeComments(lines);
      _splitJsons(src).forEach((e) =>
        models.add(Model(serializer:this, jsonName: path.basenameWithoutExtension(json), jsonSrc:e))
      );
    });

    await Future.forEach<Model>(models,
      (e) async {
        try {
          await e.save(outputDir);
        } catch(error) {
          throw(StateError("*** Error: ${e.jsonName}.json $error"));
        }
      } 
    );
  }
}
