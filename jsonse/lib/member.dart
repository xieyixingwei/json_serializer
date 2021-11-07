
class Member {
  JsonSerializeTool serializeTool;
  String name;  // is the name of member
  String _unListType;  // is the type of member(Exclude List), eg: bool, num, double, String, Map, NameSerializer
  String _init;  // is the initial value of member
  String serializerJsonName;
  JsonSerializer fatherSerializer;
  List<Member> membersForeignToMeOfTypeSerializer;
  bool isPrimaryKey = false;
  bool isList = false;
  bool isMap = false;
  ForeignType foreign = ForeignType.Non;
  JsonType jsonType;
  bool unFromJson = false;
  bool unToJson = false;
  bool isFileType =false;
  NestedType nested = NestedType.Non;
  bool slaveForeign = false;
  bool saveSync = false;

  Member(String key, dynamic value, this.fatherSerializer, this.serializeTool, {JsonType jsonType=JsonType.Map}) {
    this.jsonType = jsonType;
    _parseKey(key);
    _parseValue(value);
  }

  void _parseKey(String key) {
    if(key.contains('@pk')) {
      key = key.replaceAll('@pk', '').trim();
      isPrimaryKey = true;
    }

    if(key.contains('@fk_mm')) {
      key = key.replaceAll('@fk_mm', '').trim();
      foreign = ForeignType.ManyToMany;
      isList = true;
    } else if(key.contains('@fk_mo')) {
      key = key.replaceAll('@fk_mo', '').trim();
      foreign = ForeignType.ManyToOne;
    } else if(key.contains('@fk_oo')) {
      key = key.replaceAll('@fk_oo', '').trim();
      foreign = ForeignType.OneToOne;
    } else if(key.contains('@fk_slave')) {
      key = key.replaceAll('@fk_slave', '').trim();
      slaveForeign = true;
    }

    if(key.contains('@nested_r')) {
      key = key.replaceAll('@nested_r', '').trim();
      nested = NestedType.OnlyRead;
    } else if(key.contains('@nested')) {
      key = key.replaceAll('@nested', '').trim();
      nested = NestedType.WriteRead;
    }

    if(key.contains('@save')) {
      key = key.replaceAll('@save', '').trim();
      saveSync = true;
    }

    unToJson = key.trim().startsWith('_');   // the member is not in toJson
    unFromJson = key.trim().startsWith('__'); // the member is not in fromJson
    name = _trim(key);
  }

  void _parseValue(dynamic value) {
    if(value is bool) {
      _unListType = 'bool';
      _init = value.toString();
    }
    else if(value is double) {
      _unListType = 'double';
      _init = value.toString();
    }
    else if(value is num) {
      _unListType = 'num';
      _init = value.toString();
    }
    else if(value is String) {
      if(value.contains('=null')) {
        _init = null;
        _unListType = value.split('=').first;

        if(isList == false) {
          isList = _unListType.contains('List');
          _unListType = _unListType.replaceAll('List<', '').replaceAll('>', '');
        }

        if(_unListType.startsWith('\$')) {
          serializerJsonName = _unListType.substring(1).trim();
          _unListType = _serializerType(serializerJsonName);
        }
      }
      else if(value.startsWith('\$SingleFile')) {
        isFileType = true;
        _unListType = 'SingleFile';
        var filetype = value.split(' ').last.trim();
        _init = 'SingleFile(\'$name\', FileType.$filetype)';
        unToJson = true;
      }
      else if(value.startsWith('\$[]')) {
        serializerJsonName = value.substring(3).trim();
        _unListType = _serializerType(serializerJsonName);
        _init = '[]';
        isList = true;
      }
      else if (value.startsWith('\$')) {
        serializerJsonName = value.substring(1).trim();
        _unListType = _serializerType(serializerJsonName);
        _init = '$_unListType()';
      }
      else if (value == 'dynamic') {
        _unListType = 'dynamic';
        _init = null;
      }
      else {
        _unListType = 'String';
        _init = '\'$value\'';
      }
    }
    else if(value is Map) {
      _unListType = 'Map<String, dynamic>';
      _init = '{}';
      isMap = true;
    }
    else if(value is List) {
      isList = true;
      if(value.length == 0) {
        _unListType = 'dynamic';
        _init = '[]';
      }
      else {
        _parseValue(value.first);
        _init = _init != null ? '[]' : null;
      }
    }
  }

  // the type of foreign member is the type of foreign to Serializer'sprimary key 
  bool get isSerializerType => _isSerializerType(type);

  // the type of foreign member is not a Serializer and don't need import serializer
  String get importSerializer {
    List<String> import = [];
    if(isForeign && nested == NestedType.Non) return '';
    if(serializerJsonName != null && fatherSerializer.serializerTypeName != _unListType) import.add('import \'$serializerJsonName.dart\';');
    if(isFileType) import.add(SingleFileType.import);
    return import.join('\n');
  }

  String _trim(String val) => val.startsWith('_') ? _trim(val.substring(1)).trim() : val.trim();

  JsonSerializer get typeSerializer {
    try{
      return serializeTool.serializers.singleWhere((e) => e.jsonName == serializerJsonName, orElse: () => null);
    } catch(e) {
      print('*** ERROR: find more than one \'$serializerJsonName\', ${e.toString()}');
    }
    return null;
  }

  bool get isForeign => foreign != ForeignType.Non;
  bool get isForeignManyToMany => foreign == ForeignType.ManyToMany;
  String get unListType {
    if(nested != NestedType.Non)
      return _unListType;
    if(isForeign)
      return typeSerializer.primaryMember.type;
    return _unListType;
  }
  String get type => isList ? 'List<$unListType>' : unListType;
  String get init => isForeignManyToMany ? '[]' : (isForeign ? (isList ? '[]' : null) : _init);

  String get save {
    if(!isSerializerType) return null;
    if(typeSerializer == null) return null;
    if(isForeign) return null;
    if(typeSerializer.httpMethodsObj == null) return null;
    if(!typeSerializer.httpMethodsObj.hasSave) return null;
    if(!saveSync) return null;

    membersForeignToMeOfTypeSerializer = typeSerializer.members.where((e) => e.isForeign ? e.serializerJsonName == fatherSerializer.jsonName : false).toList();
    membersForeignToMeOfTypeSerializer = membersForeignToMeOfTypeSerializer.where((e) => e.foreign != ForeignType.ManyToMany && e.nested == NestedType.Non).toList();
    List<String>eForeignNames = membersForeignToMeOfTypeSerializer.map((e) => e.name).toList();
    String eAssignForeign = eForeignNames.map((e) => 'e.$e = ${fatherSerializer.primaryMember.name};').toList().join(' ');
    return isList ? 'await Future.forEach($name, (e) async {$eAssignForeign await e.save();});' : 'if($name != null){await $name.save();}';
  }

  String get delete {
    if(!isSerializerType) return null;
    if(typeSerializer == null) return null;
    if(isForeign) return null;
    if(typeSerializer.httpMethodsObj == null) return null;
    if(!typeSerializer.httpMethodsObj.hasDelete) return null;
    return isList ? 'if($name != null){$name.forEach((e){e.delete();});}' : 'if($name != null){$name.delete();}';
  }

  String get member {
    String value = init != null ? ' = $init' : '';
    return '$type $name$value;';
  }

  String get fromJson {
    if(unFromJson) return null; // ignore member which name start with '__'
    String jsonMember = jsonType == JsonType.Map ? 'json[\'$name\']' : 'json';
    String type = isFileType ? 'String' : unListType;
    String eFromJson = isSerializerType ? '$type().fromJson(e as Map<String, dynamic>)' : 'e as $type';
    String memberName = isFileType ? '$name.url' : name;
    String unListFromJson = isSerializerType ? 
"""$jsonMember == null
                ? $memberName
                : $unListType().fromJson($jsonMember as Map<String, dynamic>)""" : '$jsonMember == null ? $memberName : $jsonMember as $type';

    String listFromJson = 
"""$jsonMember == null
                ? $memberName
                : $jsonMember.map<$unListType>((e) => $eFromJson).toList()""";

    String memberFromJson = isList ? listFromJson : unListFromJson;
    return '$memberName = $memberFromJson';
  }

  String get toJson {
    if(unToJson) return null; // ignore member which name start with '_'
    String eToJson = isSerializerType ? 'e.toJson()' : 'e';
    String unListToJson = isSerializerType ? '$name == null ? null : $name.toJson()' : '$name';
    if(nested == NestedType.OnlyRead) {
      eToJson = 'e.${typeSerializer.primaryMember.name}';
      unListToJson = '$name == null ? null : $name.${typeSerializer.primaryMember.name}';
    }
    String listToJson = '$name == null ? null : $name.map((e) => $eToJson).toList()';
    String memberToJson = isList ? listToJson : unListToJson;
    return jsonType == JsonType.Map ? '\'$name\': $memberToJson,' : '$memberToJson;';
  }

  String get from {
    String commonFrom = 'instance.$name';
    String listFrom = 'List.from($commonFrom)';
    String serializerFrom = '$unListType().from($commonFrom)';
    String listSerializerFrom = 'List.from(instance.$name.map((e) => $unListType().from(e)).toList())';
    String from = isList ? (isSerializerType ? listSerializerFrom : listFrom) : (isSerializerType ? serializerFrom : commonFrom);
    return isFileType ? '$name.from($from);' : '$name = $from;';
  }

  String get hidePrimaryMemberName => isPrimaryKey ? '_$name' : null;
  String get hidePrimaryMember => isPrimaryKey ? '$unListType $hidePrimaryMemberName;' : null;
  String get hidePrimaryMemberFromJson => isPrimaryKey ? '$hidePrimaryMemberName = $name' : null;
  String get hidePrimaryMemberFrom => isPrimaryKey ? '$hidePrimaryMemberName = instance.$hidePrimaryMemberName;' : null;

  String get jsonEncode => (isForeign || isForeignManyToMany || unToJson) ? null : (isList || isMap ? 'jsonObj[\'$name\'] = json.encode(jsonObj[\'$name\']);' : null);
  String get addToFormData => isFileType ? 'if($name.mptFile != null) formData.files.add($name.file);' : null;
  String get removeMtpFile => isFileType ? 'if($name.mptFile != null) $name.mptFile = null;' : null;
}
