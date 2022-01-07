import 'package:jsonse/cli/commands/command.dart';
import 'argument.dart';
import 'package:jsonse/json_serialize.dart';

class JsonseCommand extends Command {
  @Option("in",
    abbr: "i",
    help: "The directory/file name to store json object",
    defaultsTo: "jsons")
  String get input => decode("in");

  @Option("out",
    abbr: "o",
    help: "The directory/file name to store dart object",
    defaultsTo: "models")
  String get output => decode("out");

  @Option("config",
    abbr: "c",
    help: "The config file.",
    defaultsTo: "_config.json")
  String get config => decode("config");

  @Flag("raw",
    help: "only build json object to dart object, exclude http-methods and filter and so on.",
    defaultsTo: false)
  bool get raw => decode("raw");

  @override
  Future<int> handle() async {
    print("--- run json serialize");

    final js = JsonSerialize(input: input, output: output, configfile: config);
    await js.run();
    return 0;
  }

  @override
  Future cleanup() async {
    
  }

  @override
  String get name {
    return "build";
  }

  @override
  String get description {
    return "build json object to dart object.";
  }
}
