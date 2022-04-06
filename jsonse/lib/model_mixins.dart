import 'package:jsonse/model.dart';

mixin ModelClass on AbstractModel {

  String get _classMembersGetter {
    var names = members.where((e) => !e.isStatic).map((e) => e.name).join(", ");
    var addMembers = "";
    if(!isAbstract && father.isNotEmpty) {
      addMembers += " + ${father}Members";
    }
    return
"""  @override
  List<Member> get members => <Member>[$names]$addMembers;
""";
  }

  String get _modelNameGetter {
    return
"""  @override
  String get modelName => "$jsonName";
""";
  }

  String get _urlGetter {
    if(url == null) return "";
    return
"""  @override
  String get url => "$url";
""";
  }

  String get _newInstanceGetter {
    return
"""  @override
  $modelTypeName get newInstance => $modelTypeName();
""";
  }

  String get _httpMethods => httpMethods != null ? httpMethods!.methods.join("\n") : "";

  @override
  String get modelClass {
    final List<String> body = [];
    body.add("// **************************************************************************\n");
    body.add("// GENERATED CODE BY jsonse - DO NOT MODIFY BY HAND\n");
    body.add("// **************************************************************************\n");
    body.add(imports);
    body.add("\n");
    body.add("class $modelTypeName$extendsModel with $modelMixinName {\n");
    body.add("\n");
    body.add("  $classMembers\n");
    body.add("\n");
    body.add(_classMembersGetter);
    body.add("\n");
    body.add(_modelNameGetter);
    body.add("\n");
    body.add(_newInstanceGetter);

    if(_urlGetter.isNotEmpty) {
      body.add("\n");
      body.add(_urlGetter);
    }

    if(_httpMethods.isNotEmpty) {
      body.add("\n");
      body.add(_httpMethods);
    }

    if(initMethod.isNotEmpty) {
      body.add("\n");
      body.add(initMethod);
    }

    body.add("}");
    return body.where((e) => e.isNotEmpty).join("");
  }
}

mixin AbstractModelClass on AbstractModel {

  String get _abstractClassMembersGetter {
    final names = members.where((e) => !e.isStatic).map((e) => e.name).join(", ");
    var addMembers = "";
    if(!isAbstract && father.isNotEmpty) {
      addMembers += " + ${father}Members";
    }
    return
"""
  List<Member> get ${jsonName}Members => <Member>[$names]$addMembers;
""";
  }

  @override
  String get abstractModelClass {
    final List<String> body = [];
    body.add("// **************************************************************************\n");
    body.add("// GENERATED CODE BY jsonse - DO NOT MODIFY BY HAND\n");
    body.add("// **************************************************************************\n");
    body.add(imports);
    body.add("\n");
    body.add("abstract class $modelTypeName $extendsModel {\n");
    body.add("\n");
    body.add("  $classMembers\n");
    body.add("\n");
    body.add(_abstractClassMembersGetter);
    body.add("}");
    return body.where((e) => e.isNotEmpty).join("");
  }
}

mixin ModelMixinClass on AbstractModel {

  String get _imports {
    List<String> imports = [];
    imports.add("import \'package:flutter/material.dart\';");
    imports.add("import \'../${serializer.outputDirName}/common/model.dart\';");
    imports.add("import \'../${serializer.outputDirName}/$jsonName.dart\';");
    return imports.where((e) => e.isNotEmpty) .join("\n") + "\n";
  }

  @override
  String get modelMixinClass {
    final List<String> body = [];
    body.add("// **************************************************************************\n");
    body.add("// GENERATED CODE BY jsonse - DO NOT MODIFY BY HAND\n");
    body.add("// **************************************************************************\n");
    body.add(_imports);
    body.add("\n");
    body.add("mixin $modelMixinName on Model {\n");
    body.add("""

  $modelTypeName get self => this as $modelTypeName;

  @override
  List<Widget> toEditWidgets({void Function()? update}) {
    // implement your edit widget settings
    return super.toEditWidgets(update: update);
  }

  @override
  List<ListTableCell> get listTableCells => [
    // add your custom initial
  ];

  @override
  Widget toWidget({void Function()? update}) {
    return super.toWidget(update: update);
    // implement the show widget
  }
""");
    body.add("}");
    return body.where((e) => e.isNotEmpty).join("");
  }
}
