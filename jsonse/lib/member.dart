import 'package:jsonse/model.dart';
import 'package:collection/collection.dart';

// 首字母大写
String _capitalize(String str) => "${str[0].toUpperCase()}${str.substring(1)}";

String trimName(String name) {
  name = name.trim();
  name = name.indexOf("_") > 0
        ? name.split("_").map<String>((String e) => _capitalize(e)).toList().join("")
        : _capitalize(name);
  return name;
}

String toModelType(String name) => "${trimName(name)}Model";

class Member {

  Member({
    required this.fatherModel,
    required String key,
    required dynamic value}) {

    _parseKey(key.trim());
    _parseValue(value);
  }

  final AbstractModel fatherModel;
  late String name;  // is the name of member
  late String _unListType;  // is the type of member(Exclude List), eg: bool, num, double, String, Map, NameSerializer
  String? init;  // is the initial value of member
  String? modelTypeJsonName;

  bool isPrimaryKey = false;
  bool isList = false;
  bool isMap = false;
  bool isForeign = false;
  bool notToJson = false;
  bool isFileType =false;
  bool isStatic = false;
  bool isNested = false;
  bool isNull = true;

  static final keyDecorators = [
    {
      "name": "@pk",
      "set": (Member m) {m.isPrimaryKey = true;},
    },
    {
      "name": "@foreign",
      "set": (Member m) {m.isForeign = true;},
    },
    {
      "name": "@notnull",
      "set": (Member m) {m.isNull = false;},
    },
    {
      "name": "@static",
      "set": (Member m) {m.isStatic = true; m.notToJson = true;},
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
    if (key.startsWith("_")) {
      notToJson = true;
    }

    keyDecorators.forEach((e) {
      final name = e["name"] as String;
      final set = e["set"] as Function(Member);
      if (key.contains(name)) {
        key = key.replaceAll(name, "").trim();
        set(this);
      }
    });

    name = _trimKey(key);
  }

  void _parseValue(dynamic value) {
    if(value is bool) {
      _unListType = "bool";
    }
    else if(value is double) {
      _unListType = "double";
      if(value != 0) {
        init = value.toString();
      }
    }
    else if(value is num) {
      _unListType = "num";
      if(value != 0) {
        init = value.toString();
      }
    }
    else if(value is String) {
      if (value.startsWith("\$")) {
        modelTypeJsonName = value.substring(1).trim();
        _unListType = toModelType(modelTypeJsonName!);
      }
      else if(value.trim().startsWith("DateTime")) {
        _unListType = "DateTime";
        final v = value.trim().replaceFirst("DateTime", "").trim();
        if(v.isNotEmpty)
        init = "$value";
      }
      else {
        _unListType = "String";
        if(value.trim().isNotEmpty) {
          init = "\"$value\"";
        }
      }
    }
    else if(value is Map) {
      _unListType = "Map<String, dynamic>";
      isMap = true;
    }
    else if(value is List) {
      isList = true;
      if(value.length == 0) {
        _unListType = "dynamic";
      }
      else {
        _parseValue(value.first);
      }
    }
  }

  String get unListType {
    if(isNested)
      return _unListType;
    // the type of foreign member is the type of foreign to Model's primary key
    if(fatherModel.serializer.config["foreign_type"] == "pk")
      return typeModel.primaryMember.type;
    return _unListType;
  }

  String get type => isList ? "List<$unListType>" : unListType;
  bool get isModelType => unListType.contains("Model");

  // the type of foreign member is not a Serializer and don't need import serializer
  String get importModels {
    List<String> import = [];
    //if(!isNested) return "";
    if(isModelType && fatherModel.modelTypeName != _unListType) import.add("import \'$modelTypeJsonName.dart\';");
    //if(isFileType) import.add(SingleFileType.import);
    return import.join("\n");
  }

  String _trimKey(String val) => val.startsWith("_") ? _trimKey(val.substring(1)).trim() : val.trim();

  Model get typeModel {
    try{
      final found = fatherModel.serializer.models.singleWhereOrNull((e) => e.jsonName == modelTypeJsonName);
      if (found == null)
        throw(StateError("*** ERROR: can\'t find \"$modelTypeJsonName\" during build \"${fatherModel.jsonName}\"."));
      else
        return found;
    } catch(e) {
      throw(StateError("*** ERROR: find more than one \"$modelTypeJsonName\" during build \"${fatherModel.jsonName}\"."));
    }
  }

  String get memberType => isList || isModelType ? "<$unListType>" : "";

  @override
  String toString() {
    if(isStatic) {
      return "static $type $name = $init;";
    }
    final value = init != null ? ", value: $init" : "";
    final creator = isModelType ? ", creator: () => $unListType()" : "";
    final isPk = isPrimaryKey ? ", isPk: true" : "";
    final foreign = isForeign ? ", isForeign: true" : "";
    final isToJson = notToJson ? ", isToJson: false" : "";
    return "final $name = Member<$type, $unListType>(name: \"$name\"$value$creator$isPk$foreign$isToJson);";
  }

  String? get addToFormData => isFileType ? "if($name.mptFile != null) formData.files.add($name.file);" : null;
  String? get removeMtpFile => isFileType ? "if($name.mptFile != null) $name.mptFile = null;" : null;
}
