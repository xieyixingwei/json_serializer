import 'package:jsonse/model.dart';
import 'package:collection/collection.dart';

enum ForeignType {
  Non,
  ManyToOne,
  ManyToMany,
  OneToOne
}

// 首字母大写
String _capitalize(String str) => "${str[0].toUpperCase()}${str.substring(1)}";

String _reName(String name) {
  name = name.trim();
  name = name.indexOf("_") > 0
        ? name.split("_").map<String>((String e) => _capitalize(e)).toList().join("")
        : _capitalize(name);
  return name;
}

String toModelType(String name) => "${_reName(name)}Model";

class Member {

  Member({
    required this.fatherModel,
    required String key,
    required dynamic value}) {

    _parseKey(key.trim());
    _parseValue(value);
  }

  final Model fatherModel;
  late String name;  // is the name of member
  late String _unListType;  // is the type of member(Exclude List), eg: bool, num, double, String, Map, NameSerializer
  String? init;  // is the initial value of member
  String? modelTypeJsonName;

  late List<Member> membersForeignToMeOfTypeSerializer;
  bool isPrimaryKey = false;
  bool isList = false;
  bool isMap = false;
  ForeignType foreignType = ForeignType.Non;
  bool notFromJson = false;
  bool notToJson = false;
  bool isFileType =false;
  bool isSaveSync = false;
  bool nullable = false;
  bool isNull = false;
  bool isStatic = false;
  bool isForeign = false;
  bool isSlave = false;
  bool isLoad = false;
  bool isNested = false;
  bool isDateTime = false;

  static final keyDecorators = [
    {
      "name": "@nullable",
      "set": (Member m) => m.nullable = true,
    },
    {
      "name": "@pk",
      "set": (Member m) {m.isPrimaryKey = true; m.nullable = true; m.isNull = true;},
    },
    {
      "name": "@foreign",
      "set": (Member m) {m.isForeign = true; m.nullable = true; m.isNull = true;},
    },
    {
      "name": "@slave",
      "set": (Member m) {m.isSlave = true;},
    },
    {
      "name": "@save",
      "set": (Member m) => m.isSaveSync = true,
    },
    {
      "name": "@load",
      "set": (Member m) => m.isLoad = true,
    },
    {
      "name": "@null",
      "set": (Member m) {m.nullable = true; m.isNull = true;},
    },
    {
      "name": "@static",
      "set": (Member m) {m.isStatic = true; m.notToJson = true; m.notFromJson = true;},
    },
    {
      "name": "@file",
      "set": (Member m) {
        m.isFileType = true;
        m._unListType = "SingleFile";
        m.init = "SingleFile();";
        m.notToJson = true;
      },
    },
    {
      "name": "@dynamic",
      "set": (Member m) {
        m.init = null;
        m._unListType = "dynamic";
      },
    },
    {
      "name": "@nested",
      "set": (Member m) => m.isNested = true,
    },
  ];

  void _parseKey(String key) {

    if (key.startsWith("___")) {
      notFromJson = true; // the member is not in fromJson
      notToJson = true; // the member is not in toJson
    }
    else if (key.startsWith("__"))
      notFromJson = true;
    else if (key.startsWith("_"))
      notToJson = true;

    keyDecorators.forEach((e) {
      final name = e["name"] as String;
      final set = e["set"] as Function(Member);
      if (key.contains(name)) {
        key = key.replaceAll(name, "").trim();
        set(this);
      }
    });



    name = _trim(key);
  }

  void _parseValue(dynamic value) {
    if(value is bool) {
      _unListType = "bool";
      init = value.toString();
    }
    else if(value is double) {
      _unListType = "double";
      init = value.toString();
    }
    else if(value is num) {
      _unListType = "num";
      init = value.toString();
    }
    else if(value is String) {
      if (value.startsWith("\$")) {
        modelTypeJsonName = value.substring(1).trim();
        _unListType = toModelType(modelTypeJsonName!);
        init = "$_unListType()";
      }
      else if(value.trim().startsWith("DateTime")) {
        isDateTime = true;
        _unListType = "DateTime";
        final v = value.trim().replaceFirst("DateTime", "").trim();
        if(v.isNotEmpty)
        init = "$value";
      }
      else {
        _unListType = "String";
        init = "\"$value\"";
      }
    }
    else if(value is Map) {
      _unListType = "Map<String, dynamic>";
      init = "{}";
      isMap = true;
    }
    else if(value is List) {
      isList = true;
      if(value.length == 0) {
        _unListType = "dynamic";
        init = "[]";
      }
      else {
        _parseValue(value.first);
        init = init != null ? "[]" : null;
      }
    }

    if(isNull)
      init = null;
  }

  String get unListType {
    if(isNested)
      return _unListType;
    // the type of foreign member is the type of foreign to Model's primary key
    if(fatherModel.jsonSerialize.config["foreign_type"] == "pk" && isForeign)
      return typeModel.primaryMember.type;
    return _unListType;
  }

  String get type => isList ? "List<$unListType>" : unListType;
  bool get isModelType => type.contains("Model");

  // the type of foreign member is not a Serializer and don't need import serializer
  String get importModels {
    List<String> import = [];
    //if(!isNested) return "";
    if(isModelType && fatherModel.modelTypeName != _unListType) import.add("import \'$modelTypeJsonName.dart\';");
    //if(isFileType) import.add(SingleFileType.import);
    return import.join("\n");
  }

  String _trim(String val) => val.startsWith("_") ? _trim(val.substring(1)).trim() : val.trim();

  Model get typeModel {
    try{
      final found = fatherModel.jsonSerialize.models.singleWhereOrNull((e) => e.jsonName == modelTypeJsonName);
      if (found == null)
        throw(StateError("*** ERROR: can\'t find \"$modelTypeJsonName\" during build \"${fatherModel.jsonName}\"."));
      else
        return found;
    } catch(e) {
      throw(StateError("*** ERROR: find more than one \"$modelTypeJsonName\" during build \"${fatherModel.jsonName}\"."));
    }
  }

  String get member {
    final value = init != null ? " = $init" : "";
    final nullableFlag = nullable ? "?" : "";
    final staticFlag = isStatic ? "static " : "";
    return "$staticFlag$type$nullableFlag $name$value;";
  }

  String? get saves => isSaveSync ? name : null;

  String? get loads => isLoad ? name : null;

  String? get foreign =>
    !isForeign ? null : "if(_ is $unListType) { $name = _; return; }";

  String? get fromJson {
    // ignore member which name start with "__"
    if(notFromJson) return null;
    final jsonMember = "json[\"$name\"]";
    final type = isFileType ? "String" : unListType;
    final eFromJson = isModelType ? "$type().fromJson(e as Map<String, dynamic>)" : "e as $type";
    final memberName = isFileType ? "$name.url" : name;
    if(isDateTime) {
      return "$memberName = $jsonMember == null ? $memberName : DateTime.parse($jsonMember).toLocal()";
    }
    final unListFromJson = isModelType ? 
"""$jsonMember == null
                ? $memberName
                : $unListType().fromJson($jsonMember as Map<String, dynamic>)""" : "$jsonMember == null ? $memberName : $jsonMember as $type";

    final listFromJson = 
"""$jsonMember == null
                ? $memberName
                : $jsonMember.map<$unListType>((e) => $eFromJson).toList()""";

    final memberFromJson = isList ? listFromJson : unListFromJson;
    return "$memberName = $memberFromJson";
  }

  String? get toJson {
    if(notToJson) return null; // ignore member which name start with "_"
    final checknull = nullable ? "?" : "";
    String eToJson = isModelType ? "e.toJson()" : "e";
    String unListToJson = isModelType ? "$name$checknull.toJson()" : "$name";
    if(isNested) {
      eToJson = "e.${typeModel.primaryMember.name}";
      unListToJson = "$name$checknull.${typeModel.primaryMember.name}";
    }
    if(isDateTime) {
      return "\"$name\": $name$checknull.toString(),";
    }
    final listToJson = "$name$checknull.map((e) => $eToJson).toList()";
    final memberToJson = isList ? listToJson : unListToJson;
    return "\"$name\": $memberToJson,";
  }

  String get from {
    if (isStatic) return "";
    final unnullFlag = nullable ? "!" : "";
    final other = "instance.$name";
    final checknull = nullable ? "$other == null ? null : " : "";
    final listFrom = "${checknull}List.from($other$unnullFlag)";
    final modelFrom = "$checknull$unListType().from($other) as $unListType";
    final listModelFrom = "${checknull}List.from(instance.$name$unnullFlag.map((e) => $unListType().from(e)).toList())";
    final from = isList ? (isModelType ? listModelFrom : listFrom) : (isModelType ? modelFrom : other);
    if(isDateTime) {
      if(nullable)
        return "$name = instance.$name == null ? null : DateTime.parse(instance.$name.toString());";
      else
        return "$name = DateTime.parse(instance.$name.toString());";
    }
    return isFileType ? "$name.from($from);" : "$name = $from;";
  }

  String? get jsonEncode => (isForeign || notToJson) 
    ? null : (isList || isMap ? "jsonObj[\"$name\"] = json.encode(jsonObj[\"$name\"]);" : null);
  String? get addToFormData => isFileType ? "if($name.mptFile != null) formData.files.add($name.file);" : null;
  String? get removeMtpFile => isFileType ? "if($name.mptFile != null) $name.mptFile = null;" : null;
}
