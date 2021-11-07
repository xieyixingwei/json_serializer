import 'dart:mirrors';
import 'package:collection/collection.dart';

Iterable<ClassMirror> classHierarchyForClass(ClassMirror t) sync* {
  var tableDefinitionPtr = t;
  while (tableDefinitionPtr.superclass != null) {
    yield tableDefinitionPtr;
    if(tableDefinitionPtr.superclass != null)
      tableDefinitionPtr = tableDefinitionPtr.superclass!;
  }
}

T firstMetadataOfTypeA<T>(DeclarationMirror dm, {TypeMirror? dynamicType}) {
  final tMirror = dynamicType ?? reflectType(T);
  final find = dm.metadata.firstWhereOrNull((im) => im.type.isSubtypeOf(tMirror));
  return find?.reflectee as T;
}

List<T> allMetadataOfType<T>(DeclarationMirror dm) {
  var tMirror = reflectType(T);
  return dm.metadata
      .where((im) => im.type.isSubtypeOf(tMirror))
      .map((im) => im.reflectee)
      .toList()
      .cast<T>();
}

String? getMethodAndClassName(VariableMirror mirror) {
  if (mirror.owner == null || mirror.owner!.owner == null)
    return null;

  return "${MirrorSystem.getName(mirror.owner!.owner!.simpleName)}.${MirrorSystem.getName(mirror.owner!.simpleName)}";
}
