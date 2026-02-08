import 'dart:io';
import 'package:yaml/yaml.dart';
import '../domain/skill_entity.dart';

class SkillParser {
  static Future<Skill?> parse(Directory directory, {String? language}) async {
    File skillMdFile;

    if (language != null && language.isNotEmpty) {
      final langFile = File('${directory.path}/SKILL_$language.md');
      if (await langFile.exists()) {
        skillMdFile = langFile;
      } else {
        skillMdFile = File('${directory.path}/SKILL.md');
      }
    } else {
      skillMdFile = File('${directory.path}/SKILL.md');
    }

    if (!await skillMdFile.exists()) return null;

    final content = await skillMdFile.readAsString();

    final frontmatterMatch =
        RegExp(r'^\s*---\s*\r?\n([\s\S]*?)\s*---\s*(?:\r?\n|$)')
            .firstMatch(content);
    if (frontmatterMatch == null) return null;

    final yamlString = frontmatterMatch.group(1) ?? '';
    final instructions = content.substring(frontmatterMatch.end).trim();

    final yaml = loadYaml(yamlString);
    if (yaml is! YamlMap) return null;

    final id = yaml['id']?.toString() ??
        directory.path.split(Platform.pathSeparator).last;
    final parsedName = yaml['name']?.toString().trim() ?? '';
    final name = parsedName.isNotEmpty ? parsedName : id;
    final description = yaml['description']?.toString() ?? '';
    final isEnabled = yaml['enabled'] is bool ? yaml['enabled'] as bool : true;
    final isLocked = yaml['locked'] is bool ? yaml['locked'] as bool : false;
    final forAI = yaml['for_ai'] is bool ? yaml['for_ai'] as bool : true;
    final platforms =
        (yaml['platforms'] as YamlList?)?.map((e) => e.toString()).toList() ??
            ['all'];

    // Parse tools if any
    final tools = <SkillTool>[];
    if (yaml['tools'] is YamlList) {
      for (final toolYaml in yaml['tools']) {
        if (toolYaml is YamlMap) {
          final toolData = _convertYamlMapToMap(toolYaml);
          // Standard fields
          final tName = toolData['name']?.toString() ?? '';
          final tDesc = toolData['description']?.toString() ?? '';
          final tSchemaRaw = toolData['input_schema'];
          final tSchema = tSchemaRaw is Map
              ? tSchemaRaw.map((key, value) => MapEntry('$key', value))
              : <String, dynamic>{};
          final tType = toolData['type']?.toString() ?? 'shell';
          final tCommand = toolData['command']?.toString() ?? '';

          final inputExamples =
              (toolData['input_examples'] ?? toolData['examples'] ?? []);
          final parsedExamples = <Map<String, dynamic>>[];
          if (inputExamples is List) {
            for (final example in inputExamples) {
              if (example is YamlMap) {
                parsedExamples.add(_convertYamlMapToMap(example));
              } else if (example is Map) {
                parsedExamples
                    .add(example.map((key, value) => MapEntry('$key', value)));
              }
            }
          }

          // Everything else goes to extra
          final extra = Map<String, dynamic>.from(toolData)
            ..remove('name')
            ..remove('description')
            ..remove('input_schema')
            ..remove('type')
            ..remove('command')
            ..remove('input_examples')
            ..remove('examples');

          tools.add(SkillTool(
            name: tName,
            description: tDesc,
            inputSchema: tSchema,
            type: tType,
            command: tCommand,
            extra: extra,
            inputExamples: parsedExamples,
          ));
        }
      }
    }

    return Skill(
      id: id,
      name: name,
      description: description,
      instructions: instructions,
      tools: tools,
      metadata: _convertYamlMapToMap(yaml),
      path: directory.path,
      isEnabled: isEnabled,
      isLocked: isLocked,
      forAI: forAI,
      platforms: platforms,
    );
  }

  static Map<String, dynamic> _convertYamlMapToMap(dynamic yamlMap) {
    if (yamlMap is! YamlMap) return {};
    final map = <String, dynamic>{};
    yamlMap.forEach((key, value) {
      if (value is YamlMap) {
        map[key.toString()] = _convertYamlMapToMap(value);
      } else if (value is YamlList) {
        map[key.toString()] = value
            .map((e) => e is YamlMap ? _convertYamlMapToMap(e) : e)
            .toList();
      } else {
        map[key.toString()] = value;
      }
    });
    return map;
  }
}
