class JsonSerializeTool {
  static final String config = '_config.json';
  String srcDir = './jsons';
  String distDir = './serializers';
  String indexFile = 'index.dart';
  String importHttpPackage;
  List<JsonSerializer> serializers = [];

  Future<bool> _handleArgs(List<String> args) async {
    int index = args.indexOf('-src');
    if(index != -1) {
      srcDir = path.normalize(args[index + 1]);
    }

    index = args.indexOf('-dist');
    if(index != -1) {
      distDir = path.normalize(args[index + 1]);
    }

    Directory _distDir = Directory(distDir);
    if(!await _distDir.exists()) {
      _distDir.create(recursive:true);
    }

    indexFile = path.join(distDir, indexFile);
    if(await File(indexFile).exists()) {
      File(indexFile).delete();
    }

    return true;
  }

  List<String> _splitJsons(String src) {
    List<String> ret = [];
    String left;
    String right;
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

  Future _parseConfigFile(String src) async {
    var obj;
    try{
      obj = json.decode(src);
    } catch(e) {
      print('*** ERROR: from \'$config\' parse Json Error: $e');
      return;
    }

    importHttpPackage = obj['http_package'] != null ? 'import \'${obj['http_package']}\';' : null;
  }

  void run(List<String> args) async {
    await _handleArgs(args);
    List<FileSystemEntity> items = Directory(srcDir).listSync();

    for(FileSystemEntity item in items) {
      if(item is Directory) continue; // ignore directory
      if('.json' != path.extension(item.path)) continue; // ignore the not json filesif
      String baseName = path.basename(item.path);
      if(baseName.startsWith('_') && baseName != '_config.json') continue; // ignore the json files which begin with '_'
      List<String> lines = await File(item.path).readAsLines();
      String src = _removeComments(lines);
      if(baseName == config) {
        _parseConfigFile(src);
        continue;
      }
      _splitJsons(src).forEach((e) =>
        serializers.add(JsonSerializer(this, path.basenameWithoutExtension(item.path), e))
      );
    }

    await Future.forEach<JsonSerializer>(serializers,
      (e) async {
        try {
          await e.save(distDir);
        } catch(error) {
          print('*** Error: ${e.jsonName}.json');
          print(error);
        }
        
        File(indexFile).writeAsStringSync('export \'${e.jsonName}.dart\';\n', mode: FileMode.append, flush: true);
      } 
    );
  }
}
