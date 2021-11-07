class QuerySet {
  final JsonSerializer fatherSerializer;
  String serializerJsonName;
  List<Member> _members = [];
  String name;

  QuerySet(this.serializerJsonName, this.fatherSerializer, Map<String, dynamic> obj) {
    if(obj['__name__'] != null) {
      name = obj['__name__'];
      obj.remove('__name__');
    } else {
      name = serializerJsonName;
    }

    obj.forEach((String key, dynamic value) {
      _members.add(Member(key, value, this.fatherSerializer, this.fatherSerializer.serializeTool));
    });
  }

  JsonSerializer get onSerializer => fatherSerializer.serializeTool.serializers.singleWhere((e) => e.jsonName == serializerJsonName, orElse:()=>null);
  String get querySetClassName => '${_reName(name)}QuerySet';
  String get saveFileName => '${name}_queryset';
  String get members => _members.map((e) => '${e.type} ${e.name} = ${e.init};').toList().join('\n  ');
  String get _queries => _members.map((e) => '\'${e.name}\': ${e.name},').toList().join('\n    ');
  String get clearMembers => _members.map((e) => '${e.name} = null;').toList().join('\n    ');
  String get import => 'import \'$saveFileName.dart\';';

  String get queries => 
"""Map<String, dynamic> get queries => <String, dynamic>{
    $_queries
  }..removeWhere((String key, dynamic value) => value == null);""";

  String get clear => 
"""void clear() {
    $clearMembers
  }""";

  String get content =>
"""class $querySetClassName {
  $members

  $queries

  $clear
}""";

  Future save(String distPath) async {
    if(_members.isEmpty) return;
    var file = File(path.join(distPath, '$saveFileName.dart'));
    await file.writeAsString(content);
  }
}
