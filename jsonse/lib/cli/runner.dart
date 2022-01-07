import 'dart:async';
import 'package:jsonse/cli/commands/command.dart';
import 'package:jsonse/cli/commands/jsonse.dart';

class Runner extends Command {
  Runner() {
    registerCommand(JsonseCommand());
  }

  @override
  Future<int> handle() async {
    printHelp();
    return 0;
  }

  @override
  String get name => "jsonse";

  @override
  String get description =>
    "jsonse is a tool for serialize json object to dart object.";
}
