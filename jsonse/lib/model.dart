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
      "name": "__abstract__",
      "set": (Model m, dynamic val) => m.isAbstract = true,
    },
    {
      "name": "__extends__",
      "set": (Model m, dynamic val) => m.extendFather = (val as String).replaceAll("\$", ""),
    },
  ];

  final JsonSerialize jsonSerialize;
  String jsonName;
  late final String modelTypeName;
  String? url;
  HttpMethods? httpMethods;
  List<Member> members = [];
  String? extendFather;
  bool isAbstract = false;

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

  String get pkSetter {
    if(url == null) return "";
    return
"""  @override
  set pk(primarykey) => ${primaryMember.name}.value = primarykey;
""";
  }

  String get pkGetter {
    if(url == null) return "";
    return
"""  @override
  get pk => ${primaryMember.name}.value;
""";
  }

  String get primaryMemberGetter {
    if(url == null) return "";
    return
"""  @override
  get primaryMember => ${primaryMember.name};
""";
  }

  String get toJsonMembers =>
    members.map((e) => e.toJson).where((e) => e != null).join("\n    ");
  String get toJson =>
"""  Map<String, dynamic> toJson({List<String>? ignores, List<String>? nulls}) {
    var ret = <String, dynamic>{};
    $toJsonMembers
    ret.removeWhere((k, v) => (ignores?.contains(k) ?? false) || ((!(nulls?.contains(k) ?? false)) && (v == null)));
    return ret;
  }
""";

  String get fromJsonMembers =>
    members.map((e) => e.fromJson).where((e) => e != null).join("\n    ");
  String get checkIsExist => url != null ? "\n    isExist = (pk != null);" : "";
  String get fromJson =>
"""  $modelTypeName fromJson(Map<String, dynamic>? json) {
    if(json == null) return this;
    $fromJsonMembers$checkIsExist
    return this;
  }
""";

  String get fromMembers => members.map((e) => e.from).where((e) => e.isNotEmpty).join("\n    ");
  String get fromType => "Model";
  String get asFromType => "\n    instance as $modelTypeName?;";
  String get isExist => url != null ? "\n    isExist = instance.isExist;" : "";
  String get from =>
"""  $fromType from($fromType? instance) {$asFromType
    if(instance == null) return this;
    $fromMembers$isExist
    return this;
  }
""";

  String get editWidgetsMembers =>
    members.map((e) => e.editWidget).where((e) => e != null).join("\n    ");
  String get editWidgets =>
"""  List<Widget> editWidgets({Function()? update}) => [
    $editWidgetsMembers
  ];
""";

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
    imports.add("import \'package:flutter/material.dart\';");
    imports.add("import \'common/model.dart\';");
    imports.add("import \'common/member.dart\';");
    if(extendFather != null) {
      imports.add("import \'$extendFather.dart\';");
    }
    return imports.where((e) => e.isNotEmpty) .join("\n") + "\n";
  }

  String get classMembers {
    var array = members.map((e) => e.member).toList();
    return "  ${array.join("\n  ")}\n";
  }

  String get extendsModel {
    var ret = url != null ? " extends UrlModel" : " extends Model";
    if(extendFather != null) {
      ret = "$ret, ${toModelType(extendFather!)}";
    }
    return ret;
  }

  String get overrideFlag => "  @override\n";

  String get abstract => isAbstract ? "abstract " : "";

  String get content {
    final List<String> body = [];
    body.add("// **************************************************************************\n");
    body.add("// GENERATED CODE BY jsonse - DO NOT MODIFY BY HAND\n");
    body.add("// **************************************************************************\n");
    body.add(imports);
    body.add("\n");
    body.add("$abstract class $modelTypeName$extendsModel {\n");
    body.add("\n");
    body.add(classMembers);
    body.add("\n");

    if(url != null) {
      body.add(urlGetter);
      body.add("\n");
      body.add(pkGetter);
      body.add("\n");
      body.add(pkSetter);
      body.add("\n");
      body.add(primaryMemberGetter);
      body.add("\n");
    }

    body.add("$overrideFlag$fromJson");
    body.add("\n");
    body.add("$overrideFlag$toJson");
    body.add("\n");
    body.add("$overrideFlag$from");
    body.add("\n");
    body.add("$overrideFlag$editWidgets");

    if(httpMethods != null) {
      body.add("\n");
      body.add(httpMethodsStr);
    }
    body.add("}");
    return body.where((e) => e.isNotEmpty).join("");
  }

  Future save(String dist) async {
    //if(members.where((e) => e.isFileType).isNotEmpty) await SingleFileType().save(distPath);
    if (!path.basename(dist).endsWith(".dart")) 
      dist = path.join(dist, "$jsonName.dart");
    File(dist).openWrite().write(content);
  }
}
