import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warn, error }

class AppLogger {
  AppLogger._();

  static void _emit(String? message, {int? wrapWidth}) {
    if (message == null || message.isEmpty) return;
    Zone.root.print(message);
  }

  static bool _installed = false;
  static bool _useColor = true;
  static bool _prettyJson = true;

  static const String _reset = '\x1B[0m';
  static const String _dim = '\x1B[90m';
  static const String _cyan = '\x1B[36m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _red = '\x1B[31m';

  static void install({bool useColor = true, bool prettyJson = true}) {
    if (_installed) return;
    _useColor = useColor;
    _prettyJson = prettyJson;

    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null || message.trim().isEmpty) return;
      raw(message, wrapWidth: wrapWidth);
    };

    _installed = true;
  }

  static ZoneSpecification zoneSpecification() {
    return ZoneSpecification(
      print: (self, parent, zone, line) {
        if (line.trim().isEmpty) return;
        raw(line);
      },
    );
  }

  static void debug(String channel, String message,
      {String? category, Object? data}) {
    _write(
      level: AppLogLevel.debug,
      channel: channel,
      category: category,
      message: message,
      data: data,
    );
  }

  static void info(String channel, String message,
      {String? category, Object? data}) {
    _write(
      level: AppLogLevel.info,
      channel: channel,
      category: category,
      message: message,
      data: data,
    );
  }

  static void warn(String channel, String message,
      {String? category, Object? data}) {
    _write(
      level: AppLogLevel.warn,
      channel: channel,
      category: category,
      message: message,
      data: data,
    );
  }

  static void error(String channel, String message,
      {String? category, Object? data}) {
    _write(
      level: AppLogLevel.error,
      channel: channel,
      category: category,
      message: message,
      data: data,
    );
  }

  static void llmRequest({required String url, Object? payload}) {
    _write(
      level: AppLogLevel.info,
      channel: 'LLM',
      category: 'REQUEST',
      message: url,
      data: payload,
      colorOverride: _yellow,
    );
  }

  static void llmResponse({Object? payload}) {
    _write(
      level: AppLogLevel.info,
      channel: 'LLM',
      category: 'RESPONSE',
      message: 'received',
      data: payload,
      colorOverride: _green,
    );
  }

  static void raw(String message, {int? wrapWidth}) {
    final parsed = _parseLegacy(message);
    _write(
      level: parsed.level,
      channel: parsed.channel,
      category: parsed.category,
      message: parsed.message,
      wrapWidth: wrapWidth,
    );
  }

  static void _write({
    required AppLogLevel level,
    required String channel,
    String? category,
    required String message,
    Object? data,
    String? colorOverride,
    int? wrapWidth,
  }) {
    final header = StringBuffer();
    header.write('[${_timestamp()}]');
    header.write('[${_levelName(level)}]');
    header.write('[$channel]');
    if (category != null && category.isNotEmpty) {
      header.write('[$category]');
    }
    if (message.trim().isNotEmpty) {
      header.write(' ${message.trim()}');
    }

    final dataText = _formatData(data);
    final text = dataText.isEmpty
        ? header.toString()
        : '${header.toString()}\n${_indent(dataText, 2)}';

    final color = colorOverride ?? _colorFor(level, channel, category);
    _emit(_applyColor(text, color), wrapWidth: wrapWidth);
  }

  static _ParsedLog _parseLegacy(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      return const _ParsedLog(
        level: AppLogLevel.debug,
        channel: 'APP',
        message: '',
      );
    }

    final normalizedMatch = RegExp(
      r'^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]\[(DEBUG|INFO|WARN|ERROR)\]\[([^\]]+)\](?:\[([^\]]+)\])?\s*(.*)$',
    ).firstMatch(input);
    if (normalizedMatch != null) {
      return _ParsedLog(
        level: _levelFromString(normalizedMatch.group(2)),
        channel: normalizedMatch.group(3)!,
        category: normalizedMatch.group(4),
        message: normalizedMatch.group(5)?.trim() ?? '',
      );
    }

    final novelMatch = RegExp(r'^\[NOVEL\]\[(DEBUG|INFO|WARN|ERROR)\]\s*(.*)$')
        .firstMatch(input);
    if (novelMatch != null) {
      return _ParsedLog(
        level: _levelFromString(novelMatch.group(1)),
        channel: 'NOVEL',
        message: novelMatch.group(2)?.trim() ?? '',
      );
    }

    if (input.startsWith('[AURORA_BOOT]')) {
      final isError = input.contains('[ERROR]');
      final stageMatch = RegExp(r'\[ERROR\]\[([^\]]+)\]').firstMatch(input);
      final stage = stageMatch?.group(1);
      final message = input
          .replaceFirst(
            RegExp(
                r'^\[AURORA_BOOT\](?:\[[^\]]+\])?(?:\[ERROR\])?(?:\[[^\]]+\])?\s*'),
            '',
          )
          .trim();
      return _ParsedLog(
        level: isError ? AppLogLevel.error : AppLogLevel.info,
        channel: 'BOOT',
        category: stage,
        message: message,
      );
    }

    if (input.startsWith('ChatStorage:')) {
      return _ParsedLog(
        level: _guessLevelFromText(input),
        channel: 'CHAT_STORAGE',
        message: input.substring('ChatStorage:'.length).trim(),
      );
    }

    if (input.startsWith('SettingsNotifier')) {
      return _ParsedLog(
        level: _guessLevelFromText(input),
        channel: 'SETTINGS',
        message: input,
      );
    }

    if (input.startsWith('Restoring session') ||
        input.startsWith('Restored topic')) {
      return _ParsedLog(
        level: AppLogLevel.info,
        channel: 'SESSION',
        message: input,
      );
    }

    return _ParsedLog(
      level: _guessLevelFromText(input),
      channel: 'APP',
      message: input,
    );
  }

  static AppLogLevel _guessLevelFromText(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('failed') ||
        lower.contains('exception')) {
      return AppLogLevel.error;
    }
    if (lower.contains('warn') || lower.contains('timeout')) {
      return AppLogLevel.warn;
    }
    return AppLogLevel.info;
  }

  static AppLogLevel _levelFromString(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'DEBUG':
        return AppLogLevel.debug;
      case 'WARN':
        return AppLogLevel.warn;
      case 'ERROR':
        return AppLogLevel.error;
      case 'INFO':
      default:
        return AppLogLevel.info;
    }
  }

  static String _formatData(Object? data) {
    if (data == null) return '';
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return '';
      if (_looksLikeJson(trimmed)) {
        try {
          final decoded = jsonDecode(trimmed);
          return _jsonText(decoded);
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    if (data is Map || data is List) {
      return _jsonText(data);
    }
    return data.toString();
  }

  static bool _looksLikeJson(String text) {
    return (text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'));
  }

  static String _jsonText(Object value) {
    if (_prettyJson) {
      const pretty = JsonEncoder.withIndent('  ');
      return pretty.convert(value);
    }
    return jsonEncode(value);
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  static String _levelName(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.debug:
        return 'DEBUG';
      case AppLogLevel.info:
        return 'INFO';
      case AppLogLevel.warn:
        return 'WARN';
      case AppLogLevel.error:
        return 'ERROR';
    }
  }

  static String _colorFor(AppLogLevel level, String channel, String? category) {
    if (channel == 'LLM' && category == 'REQUEST') return _yellow;
    if (channel == 'LLM' && category == 'RESPONSE') return _green;
    if (channel == 'BOOT') return _cyan;
    switch (level) {
      case AppLogLevel.debug:
        return _dim;
      case AppLogLevel.info:
        return _dim;
      case AppLogLevel.warn:
        return _yellow;
      case AppLogLevel.error:
        return _red;
    }
  }

  static String _applyColor(String text, String color) {
    if (!_useColor || _disableAnsiByEnv()) return text;
    if (Platform.isIOS || Platform.isAndroid) return text;
    return '$color$text$_reset';
  }

  static bool _disableAnsiByEnv() {
    return Platform.environment.containsKey('NO_COLOR');
  }

  static String _indent(String text, int spaces) {
    final pad = ' ' * spaces;
    return text.split('\n').map((line) => '$pad$line').join('\n');
  }
}

class _ParsedLog {
  final AppLogLevel level;
  final String channel;
  final String? category;
  final String message;

  const _ParsedLog({
    required this.level,
    required this.channel,
    this.category,
    required this.message,
  });
}
