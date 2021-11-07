class JsonSerializer {
  JsonSerializeTool serializeTool;
  List<Member> members = [];
  HttpMethods httpMethodsObj;
  String jsonName;
  String serializerTypeName;
  JsonType jsonType = JsonType.Map;
  String jsonSrc;
  Filter filter;
  QuerySet queryset;

  JsonSerializer(this.serializeTool, this.jsonName, this.jsonSrc) {
    var obj;
    try{
      obj = json.decode(jsonSrc);
    } catch(e) {
      print('*** ERROR: from \'${this.jsonName}.json\' parse Json Error: $e');
      return;
    }

    if(obj['__name__'] != null) {
      jsonName = obj['__name__'].trim();
      obj.remove('__name__');
    }

    serializerTypeName = _serializerType(jsonName);

    if(obj['__filter__'] != null) {
      filter = Filter(jsonName, this, obj['__filter__']);
      obj.remove('__filter__');
    }

    if(obj['__queryset__'] != null) {
      queryset = QuerySet(jsonName, this, obj['__queryset__']);
      obj.remove('__queryset__');
    }

    Map<String, dynamic> http;
    if(obj['__http__'] != null) {
      http = obj['__http__'];
      obj.remove('__http__');
    }

    if(obj['__json__'] != null) {
      Map<String, dynamic> jsonConfig = obj['__json__'];
      obj.remove('__json__');

      jsonType = jsonConfig['type'] is List ? JsonType.List : jsonType;

      String key = jsonConfig['member'].keys.first;
      dynamic value = jsonConfig['member'].values.first;
      members.add(Member(key, value, this, serializeTool, jsonType: jsonType));
    }
    else {
      obj.forEach((String key, dynamic value) {
        members.add(Member(key, value, this, serializeTool));
      });
    }

    if(http != null)
      httpMethodsObj = HttpMethods(this, http);
  }

  String get membersSave => members.map((e) => e.save).toList().where((e) => e != null).join('\n      ');
  String get membersDelete => members.map((e) => e.delete).toList().where((e) => e != null).join('\n    ');
  Member get primaryMember => members.firstWhere((e) => e.isPrimaryKey, orElse: () => null);

  List<Member> get ordinaryMembers => members.where((m) => m.slaveForeign == false).toList();
  List<Member> get foreignSlaveMembers => members.where((m) => m.slaveForeign).toList();

  String get fromJsonMembers {
    var fromJsons = ordinaryMembers.map((e) => e.fromJson).toList();
    fromJsons.add(primaryMember?.hidePrimaryMemberFromJson);
    if(foreignSlaveMembers.isNotEmpty) {
      fromJsons.add('if(!slave) return this');
      fromJsons.addAll(foreignSlaveMembers.map((e) => e.fromJson).toList());
    }
    return fromJsons.where((e) => e != null).join(';\n    ');
  }

  String get fromJson =>
"""  $serializerTypeName fromJson(${_jsonType(jsonType)} json, {bool slave = true}) {
    if(json == null) return this;
    $fromJsonMembers;
    return this;
  }""";

  String get toJsonMembers => members.map((e) => e.toJson).toList().where((e) => e != null).join('\n    ');
  String get toJson =>
    jsonType == JsonType.Map ?
"""  Map<String, dynamic> toJson() => <String, dynamic>{
    $toJsonMembers
  }..removeWhere((k, v) => v==null);""" :
"""
  List toJson() =>
    $toJsonMembers
""";

  String get fromMembers => (members.map((e) => e.from).toList()
                             + [primaryMember?.hidePrimaryMemberFrom]).where((e) => e != null).join('\n    ');
  String get from =>
"""  $serializerTypeName from($serializerTypeName instance) {
    if(instance == null) return this;
    $fromMembers
    return this;
  }""";

  String get addToFormDataOfMembers => members.map((e) => e.addToFormData).where((e) => e != null).toList().join('\n    ');
  String get removeMtpFiles => members.map((e) => e.removeMtpFile).where((e) => e != null).toList().join('\n      ');
  bool get hasFileType => members.where((e) => e.isFileType).isNotEmpty;

  String get uploadFile => hasFileType ?
"""
  Future<bool> uploadFile() async {
    var jsonObj = {'${primaryMember.name}': ${primaryMember.name}};
    var formData = FormData.fromMap(jsonObj, ListFormat.multi);
    $addToFormDataOfMembers
    bool ret = true;
    if(formData.files.isNotEmpty) {
      ret = await update(data:formData);
      $removeMtpFiles
    }
    return ret;
  }
""" : '';

  String get importStr {
    var array = members.map((e) => e.importSerializer).toSet();
    if(httpMethodsObj != null) array.add(serializeTool.importHttpPackage ?? httpMethodsObj.importHttpPackage);
    if(queryset != null) array.add(queryset.import);
    return array.join('\n');
  }

  String get memberStr {
    var array = ([primaryMember?.hidePrimaryMember] + members.map((e) => e.member).toList()).where((e) => e != null).toList();
    if(filter != null) array.add('${filter.filterClassName} filter = ${filter.filterClassName}();');
    if(queryset != null) array.add('${queryset.querySetClassName} queryset = ${queryset.querySetClassName}();');
    return array.join('\n  ');
  }

  String get httpMethods => httpMethodsObj != null ? httpMethodsObj.methods.join('\n') : '';
  String get filterClass {
    if(filter == null) return '';
    var filterMember = members.where((e) => e.isSerializerType && e.typeSerializer.filter != null
                                            && e.typeSerializer.filter.filterClassName == filter.filterClassName);
    if(filterMember.isNotEmpty) return '';
    return filter.filterClass;
  }

  String get content =>
"""
// **************************************************************************
// GENERATED CODE BY json_serializer.dart - DO NOT MODIFY BY HAND
// JsonSerializer
// **************************************************************************
$importStr

class $serializerTypeName {
  $serializerTypeName();

  $memberStr

$httpMethods
$fromJson

$toJson

$uploadFile
$from
}

$filterClass""";

  Future save(String distPath) async {
    if(members.where((e) => e.isFileType).isNotEmpty) await SingleFileType().save(distPath);
    if(queryset != null) await queryset.save(distPath);

    await File(path.join(distPath, '$jsonName.dart')).writeAsString(content);
  }
}
