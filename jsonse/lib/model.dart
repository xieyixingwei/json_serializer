import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:jsonse/http_method.dart';
import 'package:path/path.dart' as path;
import 'package:jsonse/member.dart';
import 'package:jsonse/json_serialize.dart';

class Model {

  Model({
    required this.jsonSerialize,
    required this.jsonName,
    required String jsonSrc }) {

    var obj;
    try{
      obj = json.decode(jsonSrc);
    } catch(e) {
      print("*** ERROR: from \"${this.jsonName}.json\" parse Json Error: $e");
      return;
    }

    keywords.forEach((e) {
      final name = e["name"] as String;
      final set = e["set"] as Function(Model, dynamic);
      if (obj[name] != null) {
        set(this, obj[name]);
        obj.remove(name);
      }
    });

    modelTypeName = toModelType(jsonName);

    obj.forEach((String key, dynamic value) {
      members.add(Member(fatherModel:this, key:key, value:value));
    });
  }

  static final keywords = [
    {
      "name": "__name__",
      "set": (Model m, dynamic val) => m.jsonName = (val as String).trim(),
    },
    {
      "name": "__url__",
      "set": (Model m, dynamic val) => m.url = val,
    },
    {
      "name": "__http__",
      "set": (Model m, dynamic val) => m.httpMethods = HttpMethods(m, val),
    },
    {
      "name": "__mixin__",
      "set": (Model m, dynamic val) {
        if(val is bool) {
          m.isMixin = val;
        }
        else if(val is String) {
          m.mixins.add(val.replaceAll("\$", ""));
        }
      }
    },
  ];

  final JsonSerialize jsonSerialize;
  String jsonName;
  late final String modelTypeName;
  String? url;
  HttpMethods? httpMethods;
  List<Member> members = [];
  bool isMixin = false;
  List<String> mixins = [];

  String get httpMethodsStr => httpMethods != null ? httpMethods!.methods.join("\n") : "";

  Member get primaryMember {
    final fund = members.firstWhereOrNull((e) => e.isPrimaryKey);
    if(fund == null)
      throw(StateError("*** ERROR: $jsonName does not have a primary key with @pk."));
    return fund;
  }

  String get urlGetter {
    if(url == null) return "";
    return
"""  @override
  String get url => "$url";
""";
  }

  String get newInstance {
    return
"""  @override
  $modelTypeName get newInstance => $modelTypeName();
""";
  }

  String get addToFormDataOfMembers => members.map((e) => e.addToFormData).where((e) => e != null).toList().join("\n    ");
  String get removeMtpFiles => members.map((e) => e.removeMtpFile).where((e) => e != null).toList().join("\n      ");
  bool get hasFileType => members.where((e) => e.isFileType).isNotEmpty;
  String get uploadFile => hasFileType ?
"""
  Future<bool> uploadFile() async {
    var jsonObj = {"${primaryMember.name}": ${primaryMember.name}};
    var formData = FormData.fromMap(jsonObj, ListFormat.multi);
    $addToFormDataOfMembers
    bool ret = true;
    if(formData.files.isNotEmpty) {
      ret = await update(data:formData);
      $removeMtpFiles
    }
    return ret;
  }
""" : "";

  String get imports {
    var imports = members.map((e) => e.importModels).toSet();
    if(httpMethods != null) {
      imports.add("import \'package:dio/dio.dart\' as dio;");
      imports.add("import \'${jsonSerialize.config["http_file"]}\';");
    }
    if(!isMixin) {
      imports.add("import \'common/model.dart\';");
    }
    imports.add("import \'common/member.dart\';");
    for(var e in mixins) {
      imports.add("import \'$e.dart\';");
    }
    return imports.where((e) => e.isNotEmpty) .join("\n") + "\n";
  }

  String get classMembers {
    var array = members.map((e) => e.member).toList();
    return "  ${array.join("\n  ")}\n";
  }

  String get classMembersGetter {
    var array = members.where((e) => !e.isStatic).map((e) => e.name).toList();
    var getterName = isMixin ? "${jsonName}Members" : "members";
    var addMembers = "";
    if(!isMixin && mixins.isNotEmpty) {
      addMembers += " + ${mixins.map((e) => "${e}Members").join(" + ")}";
    }
    return
"""  @override
  List<Member> get $getterName => <Member>[${array.join(", ")}]$addMembers;
""";
  }

  String get extendsModel {
    var ret = url != null ? " extends UrlModel" : " extends Model";
    if(mixins.isNotEmpty) {
      ret += " with ${mixins.map((e) => toModelType(e)).join(", ")}";
    }
    return ret;
  }

  String get overrideFlag => "  @override\n";

  String get modelClass {
    final List<String> body = [];
    body.add("// **************************************************************************\n");
    body.add("// GENERATED CODE BY jsonse - DO NOT MODIFY BY HAND\n");
    body.add("// **************************************************************************\n");
    body.add(imports);
    body.add("\n");
    body.add("class $modelTypeName$extendsModel {\n");
    body.add("\n");
    body.add(classMembers);
    body.add("\n");
    body.add(classMembersGetter);
    body.add("\n");
    body.add(newInstance);

    if(url != null) {
      body.add("\n");
      body.add(urlGetter);
    }

    if(httpMethods != null) {
      body.add("\n");
      body.add(httpMethodsStr);
    }
    body.add("}");
    return body.where((e) => e.isNotEmpty).join("");
  }

  String get modelMixin {
    final List<String> body = [];
    body.add("// **************************************************************************\n");
    body.add("// GENERATED CODE BY jsonse - DO NOT MODIFY BY HAND\n");
    body.add("// **************************************************************************\n");
    body.add(imports);
    body.add("\n");
    body.add("mixin $modelTypeName {\n");
    body.add("\n");
    body.add(classMembers);
    body.add("\n");
    body.add(classMembersGetter);
    body.add("}");
    return body.where((e) => e.isNotEmpty).join("");
  }

  Future save(String dist) async {
    //if(members.where((e) => e.isFileType).isNotEmpty) await SingleFileType().save(distPath);
    if (!path.basename(dist).endsWith(".dart")) 
      dist = path.join(dist, "$jsonName.dart");
    File(dist).openWrite().write(isMixin ? modelMixin : modelClass);
  }
}
