import 'package:jsonse/model.dart';

class HttpMethods {

  HttpMethods(this.fatherModel, this.https);

  final List https;
  final Model fatherModel;

  List<String> get methods {
    return https.map((e) {
      final method = e as Map;
      final methodName = method["name"];
      final url = method["url"] ?? fatherModel.url;
      final requestType = method["request"];
      if(methodName == null || url == null || requestType == null) {
        throw(StateError("*** ERROR: __http__ object lacks \'name\' or \'url\' or \'request\'."));
      }
      switch(requestType) {
        case "post": return _post(methodName, url);
        case "put": return _put(methodName, url);
        case "get": return _get(methodName, url);
      }
      return "";
    }).where((e) => e.isNotEmpty).toList();
  }

  String _post(String name, String url) =>
"""
  Future<dio.Response?> $name({List<String>? ignore, bool serialize = true}) async {
    final jsonData = toJson();
    if(ignore != null) {
      jsonData.removeWhere((key, val) => ignore.contains(key));
    }
    var res = await Global.http.request("post", \"$url\", data: jsonData, queries: queries);
    if(serialize) {
      // Don't update slave forign members in create to avoid erasing newly added associated data
      fromJson(res?.data);
    }
    return res;
  }
""";

  String _put(String name, String url) =>
"""
  Future<dio.Response?> $name({List<String>? ignore, bool serialize = true}) async {
    final jsonData = toJson();
    if(ignore != null) {
      jsonData.removeWhere((key, val) => ignore.contains(key));
    }
    var res = await Global.http.request("put", \"$url\", data: jsonData, queries: queries);
    if(serialize) {
      // Don't update slave forign members in create to avoid erasing newly added associated data
      fromJson(res?.data);
    }
    return res;
  }
""";

  String _get(String name, String url) =>
"""
  Future<dio.Response?> $name({bool serialize = true}) async {
    var res = await Global.http.request("get", \"$url\", queries: queries);
    if(serialize) {
      fromJson(res?.data);
    }
    return res;
  }
""";
}
