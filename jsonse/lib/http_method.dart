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
  Future<dio.Response?> $name() async =>
    await request(HttpType.post, this, path: \"$url\");
""";

  String _put(String name, String url) =>
"""
  Future<dio.Response?> $name() async =>
    await request(HttpType.put, this, path: \"$url\");
""";

  String _get(String name, String url) =>
"""
  Future<dio.Response?> $name() async =>
    await Global.http.request("get", this, path: \"$url\");
""";
}
