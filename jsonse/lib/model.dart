import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:jsonse/http_method.dart';
import 'package:jsonse/model_mixins.dart';
import 'package:path/path.dart' as path;
import 'package:jsonse/member.dart';
import 'package:jsonse/json_serialize.dart';

abstract class AbstractModel {

  AbstractModel({
    required this.serializer,
    required this.jsonName,
    required this.jsonSrc
  }) {
    init();
  }

  static final keywords = [
    {
      "name": "__name__",
      "set": (AbstractModel m, dynamic val) => m.jsonName = (val as String).trim(),
    },
    {
      "name": "__url__",
      "set": (AbstractModel m, dynamic val) => m.url = val,
    },
    {
      "name": "__http__",
      "set": (AbstractModel m, dynamic val) => m.httpMethods = HttpMethods(m, val),
    },
    {
      "name": "__abstract__",
      "set": (AbstractModel m, dynamic val) {
        m.isAbstract = val;
      }
    },
    {
      "name": "__extends__",
      "set": (AbstractModel m, dynamic val) {
        if("$val".startsWith("\$")) {
          m.father = val.replaceAll("\$", "");
        }
        else {
          final tmp = "$val".split(".dart/");
          if(tmp.length != 2) {
            throw(StateError("*** ERROR: ${m.jsonName}'s format of __extends__ error."));
          }
          m.fatherPath = tmp.first;
          m.father = tmp.last;
        }
      }
    },
    {
      "name": "__uneditable__",
      "set": (AbstractModel m, dynamic val) {
        m.uneditable = val.map<String>((e) => e as String).toList();
      }
    },
    {
      "name": "__filter__",
      "set": (AbstractModel m, dynamic val) {
        m.filter = (val as Map).map<String, List<String>>((key, value) {
          return MapEntry(key, value.map<String>((e) => e as String).toList());
        });
      }
    },
  ];

  final JsonSerialize serializer;
  String jsonName;
  final jsonSrc;
  String? url;
  HttpMethods? httpMethods;
  List<Member> members = [];
  bool isAbstract = false;
  String father = "";
  String fatherPath = "";
  List<String> uneditable = [];
  Map<String, List<String>> filter = {};

  void init() {
    var obj;
    try{
      obj = json.decode(jsonSrc);
    } catch(e) {
      print("*** ERROR: from \"${this.jsonName}.json\" parse Json Error: $e");
      return;
    }

    keywords.forEach((e) {
      final name = e["name"] as String;
      final set = e["set"] as Function(AbstractModel, dynamic);
      if (obj[name] != null) {
        set(this, obj[name]);
        obj.remove(name);
      }
    });

    obj.forEach((String key, dynamic value) {
      members.add(Member(fatherModel:this, key:key, value:value));
    });
  }

  Member get primaryMember {
    final fund = members.firstWhereOrNull((e) => e.isPrimaryKey);
    if(fund == null)
      throw(StateError("*** ERROR: $jsonName does not have a primary key with @pk."));
    return fund;
  }

  String get modelTypeName => toModelType(jsonName);
  String get modelMixinName => "${trimName(jsonName)}Mixin";

  String get imports {
    var imports = members.map((e) => e.importModels).toSet();
    if(httpMethods != null) {
      imports.add("import \'package:dio/dio.dart\' as dio;");
      imports.add("import \'common/http_mixin.dart\';");
    }
    if(fatherPath.isNotEmpty) {
      imports.add("import \'$fatherPath.dart\';");
    }
    else if(father.isNotEmpty) {
      imports.add("import \'$father.dart\';");
    }
    else if(url != null) {
      imports.add("import \'common/url_model.dart\';");
    }
    else {
      imports.add("import \'common/model.dart\';");
    }

    if(!isAbstract) {
      imports.add("import \'../${serializer.outputDirName}_mixins/${jsonName}_mixin.dart\';");
    }

    if(filter.isNotEmpty) {
      imports.add("import \'common/member_list_mixin.dart\';");
    }

    imports.add("import \'common/member.dart\';");
    return imports.where((e) => e.isNotEmpty) .join("\n") + "\n";
  }

  String get classMembers => members.map((e) => "$e").join("\n  ");

  String get extendsModel {
    var ret = url != null ? " extends UrlModel" : " extends Model";
    if(father.isNotEmpty && fatherPath.isNotEmpty) {
      ret = " extends $father";
    }
    else if(father.isNotEmpty) {
      ret = " extends ${toModelType(father)}";
    }
    return ret;
  }

  String get initMethod {
    final List<String> body = [];

    // add uneditable members
    body.add("// set the editable of members");
    for(var name in uneditable) {
      body.add("$name.isEditable = false;");
    }

    body.add("// set the filter of members");
    for(var name in filter.keys) {
      var memerName = name;
      if(name.contains("->")) {
        final tmp = name.split("->");
        memerName = tmp.last.trim();
        body.add("$memerName.filterAlias = \"${tmp.first.trim()}\";");
      }
      body.add("$memerName.supportedFilterTypes = [${filter[name]!.map((e) => "FilterType.$e").join(", ")}];");
    }

    body.removeWhere((e) => e.isEmpty);

    if(body.isEmpty) {
      return "";
    }

    return
"""  @override
  void init() {
    super.init();
    ${body.join("\n    ")}
  }
""";
  }

  String get modelClass;

  String get abstractModelClass;

  String get modelMixinClass;

  Future save(String dist) async {
    final modelFile = path.join(dist, "${jsonName}.dart");
    File(modelFile).openWrite().write(isAbstract ? abstractModelClass : modelClass);

    if(!isAbstract) {
      final parentDir = Directory(dist).parent.uri.toFilePath(windows:Platform.isWindows);
      final modelDirName = path.basename(dist);
      final modelMixinDir = path.join(parentDir, "${modelDirName}_mixins");
      final d = Directory(modelMixinDir);
      if(!d.existsSync()) {
        d.createSync(recursive:true);
      }

      final modelMixinFile = path.join(modelMixinDir, "${jsonName}_mixin.dart");
      final mixinFile = File(modelMixinFile);
      if(!mixinFile.existsSync()) {
        mixinFile.openWrite().write(modelMixinClass);
      }
    }
  }
}

class Model extends AbstractModel with ModelClass, ModelMixinClass, AbstractModelClass {
  Model({
    required JsonSerialize serializer,
    required String jsonName,
    required String jsonSrc
  }) : super(serializer: serializer, jsonName: jsonName, jsonSrc: jsonSrc);
}
