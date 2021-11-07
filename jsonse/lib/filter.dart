class Filter {
  final JsonSerializer fatherSerializer;
  String serializerJsonName;
  List<Map<String, String>> _filters = [];

  Filter(this.serializerJsonName, this.fatherSerializer, Map<String, dynamic> obj) {
    obj.forEach((String key, dynamic values) {
        key = key.trim();
        if(key == '__serializer__') {
          serializerJsonName = values.trim().startsWith('\$') ? values.trim().substring(1) : values.trim();
          return;
        }
        values.forEach((e) {
          e = e.trim();
          if(e == 'exact')
            _filters.add({'$key': '$key'});
          else if(e == 'icontains')
            _filters.add({'$key': '${key}__icontains'});
          else
            _filters.add({'$key': '${key}__$e'});
        });
      });
  }

  JsonSerializer get onSerializer => fatherSerializer.serializeTool.serializers.singleWhere((e) => e.jsonName == serializerJsonName, orElse:()=>null);
  String type(String name) {
    var member = onSerializer.members.firstWhere((e) => e.name == name);
    if(member.isSerializerType)
      return member.typeSerializer.primaryMember.unListType;
    else
      return member.unListType;
  }
  String get members => _filters.map((e) => '${type(e.keys.first)} ${e.values.first};').toList().join('\n  ');
  String get _queries => _filters.map((e) => '\'${e.values.first}\': ${e.values.first},').toList().join('\n    ');
  String get clearMembers => _filters.map((e) => '${e.values.first} = null;').toList().join('\n    ');
  String get filterClassName => '${_reName(serializerJsonName)}Filter';

  String get queries => 
"""Map<String, dynamic> get queries => <String, dynamic>{
    $_queries
  }..removeWhere((String key, dynamic value) => value == null);""";

  String get clear => 
"""void clear() {
    $clearMembers
  }""";

  String get filterClass => _filters.isEmpty ? '' :
"""
class $filterClassName {
  $members

  $queries

  $clear
}
""";
}
