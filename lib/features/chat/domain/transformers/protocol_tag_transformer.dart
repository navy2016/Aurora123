import '../message_transformer.dart';
import '../ui_message.dart';
import '../ui_message_part.dart';

class ProtocolTagTransformer extends OutputMessageTransformer {
  static final RegExp _searchPattern =
      RegExp(r'<search>(.*?)</search>', dotAll: true);
  static final RegExp _skillPattern =
      RegExp(r'''<skill\s+name=["'](.*?)["']>(.*?)</skill>''', dotAll: true);
  static final String _searchOpenTag = '<search>';
  static final String _searchCloseTag = '</search>';
  static final String _skillCloseTag = '</skill>';

  const ProtocolTagTransformer();

  @override
  UiMessage visualTransform(UiMessage message, MessageTransformContext context) {
    if (message.role != UiRole.assistant) return message;

    final rawText = message.text;
    if (rawText.isEmpty) return message;

    var cleaned = rawText;
    var changed = false;

    final afterRegex =
        cleaned.replaceAll(_searchPattern, '').replaceAll(_skillPattern, '');
    if (afterRegex != cleaned) {
      cleaned = afterRegex;
      changed = true;
    }

    final lastSearchIndex = cleaned.lastIndexOf(_searchOpenTag);
    if (lastSearchIndex != -1 &&
        cleaned.indexOf(_searchCloseTag, lastSearchIndex) == -1) {
      cleaned = cleaned.substring(0, lastSearchIndex);
      changed = true;
    }

    int? lastSkillIndex;
    for (final match in RegExp(r'<skill\s+name\s*=',
            multiLine: true, dotAll: true)
        .allMatches(cleaned)) {
      lastSkillIndex = match.start;
    }
    if (lastSkillIndex != null &&
        cleaned.indexOf(_skillCloseTag, lastSkillIndex) == -1) {
      cleaned = cleaned.substring(0, lastSkillIndex);
      changed = true;
    }

    if (!changed) return message;

    cleaned = cleaned.trim();
    return message.replaceText(cleaned);
  }

  @override
  UiMessage onGenerationFinish(UiMessage message, MessageTransformContext context) {
    if (message.role != UiRole.assistant) return message;

    final rawText = message.text;
    if (rawText.isEmpty) return message;

    final parts = List<UiMessagePart>.from(message.parts);
    final hasSearch = parts.any((p) => p is UiSearchRequestPart);
    final hasSkill = parts.any((p) => p is UiSkillRequestPart);

    if (!hasSearch) {
      final match = _searchPattern.firstMatch(rawText);
      var query = match?.group(1)?.trim() ?? '';
      if (query.isEmpty) {
        final openIndex = rawText.indexOf(_searchOpenTag);
        if (openIndex != -1) {
          final afterOpen =
              rawText.substring(openIndex + _searchOpenTag.length);
          final closeIndex = afterOpen.indexOf(_searchCloseTag);
          query = (closeIndex == -1
                  ? afterOpen
                  : afterOpen.substring(0, closeIndex))
              .trim();
        }
      }
      if (query.isNotEmpty) {
        parts.add(UiSearchRequestPart(query));
      }
    }

    if (!hasSkill) {
      final match = _skillPattern.firstMatch(rawText);
      final skillName = match?.group(1)?.trim() ?? '';
      final query = match?.group(2)?.trim() ?? '';
      if (skillName.isNotEmpty && query.isNotEmpty) {
        parts.add(UiSkillRequestPart(skillName: skillName, query: query));
      } else {
        final partial = RegExp(r'''<skill\s+name=["'](.*?)["']>(.*)''',
                dotAll: true)
            .firstMatch(rawText);
        final partialName = partial?.group(1)?.trim() ?? '';
        var partialQuery = partial?.group(2) ?? '';
        if (partialQuery.isNotEmpty) {
          final closeIndex = partialQuery.indexOf(_skillCloseTag);
          if (closeIndex != -1) {
            partialQuery = partialQuery.substring(0, closeIndex);
          }
          partialQuery = partialQuery.trim();
        }
        if (partialName.isNotEmpty && partialQuery.isNotEmpty) {
          parts.add(UiSkillRequestPart(
              skillName: partialName, query: partialQuery));
        }
      }
    }

    var cleaned = rawText
        .replaceAll(_searchPattern, '')
        .replaceAll(_skillPattern, '')
        .toString();

    final lastSearchIndex = cleaned.lastIndexOf(_searchOpenTag);
    if (lastSearchIndex != -1 &&
        cleaned.indexOf(_searchCloseTag, lastSearchIndex) == -1) {
      cleaned = cleaned.substring(0, lastSearchIndex);
    }

    int? lastSkillIndex;
    for (final match in RegExp(r'<skill\s+name\s*=',
            multiLine: true, dotAll: true)
        .allMatches(cleaned)) {
      lastSkillIndex = match.start;
    }
    if (lastSkillIndex != null &&
        cleaned.indexOf(_skillCloseTag, lastSkillIndex) == -1) {
      cleaned = cleaned.substring(0, lastSkillIndex);
    }

    cleaned = cleaned.trim();

    parts.removeWhere((p) => p is UiTextPart);
    if (cleaned.isNotEmpty) {
      parts.insert(0, UiTextPart(cleaned));
    }

    return message.copyWith(parts: parts);
  }
}
