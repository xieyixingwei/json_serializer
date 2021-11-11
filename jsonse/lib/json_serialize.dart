library jsonse;

import 'dart:convert';
import 'dart:io';
import 'package:jsonse/model.dart';
import 'package:path/path.dart' as path;

class JsonSerialize {

  JsonSerialize({
    required String input,
    required this.output,
    required String configfile }) {

    final inf = File(input);
    if (inf.statSync().type == FileSystemEntityType.notFound) {
      print("*** ERROR: $input is not exist.");
      return;
    }

    if (inf.statSync().type == FileSystemEntityType.directory) {
      final d = Directory(input);
      d.listSync(recursive: true).forEach((e) {
        final jf = File(e.path);
        if ( jf.statSync().type == FileSystemEntityType.file
          && jf.path.endsWith(".json")
          && !path.basename(jf.path).startsWith("_")
          && path.basename(jf.path) != "_config.json") {
          jsons.add(e.path);
        }
      });

      if (output == "models") {
        final parentDir = d.parent.uri.toFilePath(windows:Platform.isWindows);
        output = path.join(parentDir, output);
      }
      final out = Directory(output);
      if(!out.existsSync())
        out.createSync(recursive:true);

      if (configfile == "_config.json") {
        final configDir = d.uri.toFilePath(windows:Platform.isWindows);
        configfile = path.join(configDir, configfile);
      }
    }
    else if (inf.statSync().type == FileSystemEntityType.file) {
      jsons.add(input);

      if (!path.basename(output).endsWith(".dart"))
        output = path.dirname(input);
    }

    final cf = File(configfile);
    if (cf.statSync().type == FileSystemEntityType.file)
      _parseConfigFile(cf);
  }

  String output;
  late final Map<String, dynamic> config;

  List<String> jsons = [];
  List<Model> models = [];
  String? importHttpPackage;

  List<String> _splitJsons(String src) {
    List<String> ret = [];
    String? left;
    String? right;
    int count = 0;
    String one = '';
    src.split('').forEach((e) {
      if(left == null && '{['.contains(e)) {
        left = e;
        right = left == '{' ? '}' : ']';
      }
      if(left != null && e == left) count++;
      if(right != null && e == right) count--;
      one += e;
      if(left != null && count == 0) {
        ret.add(one);
        one = '';
        left = null;
        right = null;
      }
    });
    return ret;
  }

  String _removeComments(List<String> lines) {
    String content = '';
    lines.forEach(
      (String line) {
        int pos = line.indexOf('//'); // comment char is '//'
        if(pos != -1) {
          line = line.substring(0, pos);
        }
        content += line + '\n';
      }
    );
    return content;
  }

  void _parseConfigFile(File cf) {
    try{
      config = json.decode(_removeComments(cf.readAsLinesSync()));
    } catch(e) {
      print('*** ERROR: from \'$config\' parse Json Error: $e');
    }
  }

  Future run() async {
    jsons.forEach((json) {
      List<String> lines = File(json).readAsLinesSync();
      String src = _removeComments(lines);
      _splitJsons(src).forEach((e) =>
        models.add(Model(jsonSerialize:this, jsonName: path.basenameWithoutExtension(json), jsonSrc:e))
      );
    });

    await Future.forEach<Model>(models,
      (e) async {
        try {
          await e.save(output);
        } catch(error) {
          print('*** Error: ${e.jsonName}.json');
          print(error);
        }
      } 
    );
  }
}
