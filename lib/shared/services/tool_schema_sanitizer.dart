import 'llm_transport_mode.dart';

class ToolSchemaSanitizer {
  static List<Map<String, dynamic>>? sanitizeToolsForTransportMode(
    List<Map<String, dynamic>>? tools,
    LlmTransportMode mode,
  ) {
    if (tools == null) return null;
    if (tools.isEmpty) return const [];

    return tools.map((tool) {
      final type = tool['type']?.toString();
      if (type != 'function') {
        return _sanitizeMapKeys(tool) as Map<String, dynamic>;
      }

      final fn = tool['function'];
      if (fn is! Map) {
        return _sanitizeMapKeys(tool) as Map<String, dynamic>;
      }

      final nextFn = Map<String, dynamic>.from(_sanitizeMapKeys(fn) as Map);
      final rawParams = fn['parameters'];
      if (rawParams is Map) {
        nextFn['parameters'] = mode == LlmTransportMode.geminiNative
            ? _sanitizeGeminiSchemaValue(rawParams)
            : _sanitizeMapKeys(rawParams);
      }

      final next = Map<String, dynamic>.from(_sanitizeMapKeys(tool) as Map);
      next['function'] = nextFn;
      return next;
    }).toList(growable: false);
  }

  static dynamic _sanitizeGeminiSchemaValue(dynamic value) {
    if (value is Map) {
      final sanitized = <String, dynamic>{};
      value.forEach((key, entryValue) {
        final keyStr = key.toString();
        // Gemini native Schema rejects JSON Schema metadata keys like "$schema".
        if (keyStr.startsWith(r'$')) return;
        sanitized[keyStr] = _sanitizeGeminiSchemaValue(entryValue);
      });
      return sanitized;
    }

    if (value is List) {
      return value.map(_sanitizeGeminiSchemaValue).toList();
    }

    return value;
  }

  static dynamic _sanitizeMapKeys(dynamic value) {
    if (value is Map) {
      final sanitized = <String, dynamic>{};
      value.forEach((key, entryValue) {
        sanitized[key.toString()] = _sanitizeMapKeys(entryValue);
      });
      return sanitized;
    }

    if (value is List) {
      return value.map(_sanitizeMapKeys).toList();
    }

    return value;
  }
}

