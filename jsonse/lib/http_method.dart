class HttpMethods {
  final JsonSerializer fatherSerializer;
  List methodsConfig = [];
  Map<String, dynamic> httpConfig;
  static const Map<String, String> methodMap = {
    'create': 'post',
    'update': 'put',
    'retrieve': 'get',
    'list': 'get',
    'delete': 'delete',
  };

  String get baseUrl => httpConfig['url'];
  String get httpPackage => httpConfig['http_package'];
  String get importHttpPackage => httpPackage != null ? 'import \'$httpPackage\';' : null;
  String get serializerType => fatherSerializer.serializerTypeName;
  bool get hasSave => methodsConfig.indexWhere((e) => e['name'] == 'save') != -1;
  bool get hasUpdate => methodsConfig.indexWhere((e) => e['name'] == 'update') != -1;
  bool get hasDelete => methodsConfig.indexWhere((e) => e['name'] == 'delete') != -1;
  String get uploadFile => fatherSerializer.hasFileType ? 'res = await uploadFile();' : null;
  String get saveSync => fatherSerializer.membersSave.isNotEmpty ? 'if(res) {\n      ${fatherSerializer.membersSave}\n    }' : null;
  HttpMethods(this.fatherSerializer, this.httpConfig) {
    methodsConfig = httpConfig['methods'];
  }

  String get attach {
    var array = <String>[saveSync, uploadFile].where((e) => e != null).toList();
    if(array.isEmpty) return '';

    return '    ' + array.join('\n    ');
  }

  List<String> get methods =>
    methodsConfig.map((e) {
      List<String> query = [];
      String queryset = '';
      if(fatherSerializer.queryset != null) {
          query.add('queries.addAll(queryset.queries);');
      }
      if(fatherSerializer.filter != null) {
          query.add('queries.addAll(filter.queries);');
      }
      if(query.isNotEmpty) {
        query.insert(0, 'if(queries == null) queries = <String, dynamic>{};');
      }
      if(query.isNotEmpty) {
        queryset = query.join('\n    ') + '\n    ';
      }

      String methodName = e['name'];

      if(methodName == 'save') {
        String update = hasUpdate ? 'await update(data:data, queries:queries, cache:cache)' : '';
        String create = 'await create(data:data, queries:queries, cache:cache)';
        return
"""
  Future<bool> save({dynamic data, Map<String, dynamic> queries, bool cache=false}) async {
    bool res = ${fatherSerializer.primaryMember.hidePrimaryMemberName} == null ?
      $create :
      $update;
$attach
    return res;
  }
""";
      }

      String requestUrl = baseUrl + (e["url"] != null ? e["url"] : '');
      String requestType = e["requst"] != null ? e["requst"] : methodMap[methodName];
      String data = 'data:data ?? toJson()';
      String queries = 'queries:queries';
      String cache = 'cache:cache';

      if(requestType == "post") {
        return
"""
  Future<bool> $methodName({dynamic data, Map<String, dynamic> queries, bool cache=false}) async {
    var res = await Http().request(HttpType.POST, '$requestUrl', $data, $queries, $cache);
    fromJson(res?.data, slave:false); // Don't update slave forign members in create to avoid erasing newly added associated data
    return res != null;
  }
""";
      }
      else if(requestType == "put") {
        return
"""
  Future<bool> $methodName({dynamic data, Map<String, dynamic> queries, bool cache=false}) async {
    var res = await Http().request(HttpType.PUT, '$requestUrl', $data, $queries, $cache);
    fromJson(res?.data, slave:false); // Don't update slave forign members in update to avoid erasing newly added associated data
    return res != null;
  }
""";
      }else if(methodName == "list") {
        return
"""
  Future<List<$serializerType>> list({Map<String, dynamic> queries, bool cache=false}) async {
    ${queryset}var res = await Http().request(HttpType.GET, '$requestUrl', $queries, $cache);
    return res != null ? res.data.map<$serializerType>((e) => $serializerType().fromJson(e)).toList() : [];
  }
""";
      }
      else if(requestType == "get") {
        return
"""
  Future<bool> $methodName({Map<String, dynamic> queries, bool cache=false}) async {
    ${queryset}var res = await Http().request(HttpType.GET, '$requestUrl', $queries, $cache);
    fromJson(res?.data);
    return res != null;
  }
""";
      }
      else if(requestType == "delete") {
        return
"""
  Future<bool> $methodName({${fatherSerializer.primaryMember.type} pk}) async {
    if(${fatherSerializer.primaryMember.hidePrimaryMemberName} == null && pk == null) return true;
    if(pk != null) ${fatherSerializer.primaryMember.name} = pk;
    var res = await Http().request(HttpType.DELETE, '$requestUrl');
    /*
    ${fatherSerializer.membersDelete}
    */
    return res != null ? res.statusCode == 204 : false;
  }
""";
      }
    }).toList();
}
