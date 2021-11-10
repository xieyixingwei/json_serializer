// **************************************************************************
// GENERATED CODE BY json_serializer.dart - DO NOT MODIFY BY HAND
// JsonSerializer
// **************************************************************************


class TestModel {
  TestModel();

  String? name;
  num? age = 23;
  List<String> brothers = [];
  List<dynamic> tags = [];


  TestModel fromJson(Map<String, dynamic> json, {bool slave = true}) {
    name = json['name'] == null ? name : json['name'] as String;
    age = json['age'] == null ? age : json['age'] as num;
    brothers = json['brothers'] == null
                ? brothers
                : json['brothers'].map<String>((e) => e as String).toList();
    tags = json['tags'] == null
                ? tags
                : json['tags'].map<dynamic>((e) => e as dynamic).toList();
    return this;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    "name": name,
    "age": age,
    "brothers": brothers.map((e) => e).toList(),
    "tags": tags.map((e) => e).toList(),
  }..removeWhere((k, v) => v==null);


  TestModel from(TestModel instance) {
    name = instance.name;
    age = instance.age;
    brothers = List.from(instance.brothers);
    tags = List.from(instance.tags);
    return this;
  }
}

