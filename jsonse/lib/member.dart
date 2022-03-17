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
  bool isStatic = false;
  bool isNested = false;
  bool isDateTime = false;
  bool isNull = true;

  static final keyDecorators = [
    {
      "name": "@pk",
      "set": (Member m) {m.isPrimaryKey = true;},
    },
    {
      "name": "@notnull",
      "set": (Member m) {m.isNull = false;},
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
        isDateTime = true;
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
    if(fatherModel.jsonSerialize.config["foreign_type"] == "pk")
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
      final found = fatherModel.jsonSerialize.models.singleWhereOrNull((e) => e.jsonName == modelTypeJsonName);
      if (found == null)
        throw(StateError("*** ERROR: can\'t find \"$modelTypeJsonName\" during build \"${fatherModel.jsonName}\"."));
      else
        return found;
    } catch(e) {
      throw(StateError("*** ERROR: find more than one \"$modelTypeJsonName\" during build \"${fatherModel.jsonName}\"."));
    }
  }

  String get memberType => isList || isModelType ? "<$unListType>" : "";

  String get member {
    if(isStatic) {
      return "static $type $name = $init;";
    }
    final value = init != null ? ", value: $init" : "";
    final creator = isModelType ? ", creator: () => $unListType()" : "";
    return "final $name = Member<$type>(name: \"$name\"$value$creator);";
  }

  String? get toJson {
    if(notToJson) return null; // ignore member which name start with "_"
    return "ret.addAll($name.toJson());";
  }

  String? get fromJson {
    // ignore member which name start with "__"
    if(notFromJson) return null;
    return "$name.fromJson$memberType(json);";
  }

  String get from {
    if (isStatic) return "";
    return isFileType ? "$name.from($from);" : "$name.from$memberType(instance.$name);";
  }

  String? get editWidget {
    if(isStatic) {
      return null;
    }
    final update = isList || isModelType ? "update: update" : "";
    return "$name.editWidget$memberType($update),";
  }

  String? get addToFormData => isFileType ? "if($name.mptFile != null) formData.files.add($name.file);" : null;
  String? get removeMtpFile => isFileType ? "if($name.mptFile != null) $name.mptFile = null;" : null;
}
