import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class McpBindingsData {
  final Map<String, List<String>> assistant;
  final Map<String, List<String>> session;

  const McpBindingsData({
    this.assistant = const {},
    this.session = const {},
  });
}

class McpBindingsStorage {
  static const int currentVersion = 1;

  Future<File> get _configFile async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'mcp_bindings.json'));
  }

  Future<McpBindingsData> load() async {
    try {
      final file = await _configFile;
      if (!await file.exists()) return const McpBindingsData();

      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map) return const McpBindingsData();

      final map = decoded.map((k, v) => MapEntry('$k', v));
      final rawAssistant = map['assistant'];
      final rawSession = map['session'];

      return McpBindingsData(
        assistant: _parseOverrides(rawAssistant),
        session: _parseOverrides(rawSession),
      );
    } catch (_) {
      return const McpBindingsData();
    }
  }

  Map<String, List<String>> _parseOverrides(dynamic value) {
    final result = <String, List<String>>{};
    if (value is! Map) return result;
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final rawList = entry.value;
      if (rawList is! List) continue;
      final ids = rawList
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      result[key] = ids;
    }
    return result;
  }

  Future<void> save(McpBindingsData data) async {
    final payload = const JsonEncoder.withIndent('  ').convert({
      'version': currentVersion,
      'assistant': data.assistant,
      'session': data.session,
    });

    final file = await _configFile;
    final dir = file.parent;
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (_) {}

    final tmp = File(p.join(dir.path, 'mcp_bindings.json.tmp'));
    try {
      await tmp.writeAsString(payload);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tmp.rename(file.path);
    } catch (_) {
      try {
        await file.writeAsString(payload);
      } catch (_) {}
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }
}

