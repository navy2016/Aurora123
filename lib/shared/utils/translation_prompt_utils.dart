class TranslationPromptUtils {
  static const String _zhSourceMarker = '原文内容：';
  static const String _zhPromptHint = '你是一位精通多国语言的专业翻译专家';
  static const String _enSourceMarker = 'Source text:';
  static const String _enPromptHint = 'You are a professional translator';

  static String extractSourceText(String content) {
    final markerPairs = <MapEntry<String, String>>[
      const MapEntry(_zhSourceMarker, _zhPromptHint),
      const MapEntry(_enSourceMarker, _enPromptHint),
    ];

    int bestMarkerIndex = -1;
    String? bestMarker;

    for (final pair in markerPairs) {
      final marker = pair.key;
      final hint = pair.value;
      final markerIndex = content.lastIndexOf(marker);
      if (markerIndex == -1) continue;

      final prefix = content.substring(0, markerIndex);
      if (!prefix.contains(hint)) continue;

      if (markerIndex > bestMarkerIndex) {
        bestMarkerIndex = markerIndex;
        bestMarker = marker;
      }
    }

    if (bestMarkerIndex == -1 || bestMarker == null) return content;

    var extracted = content.substring(bestMarkerIndex + bestMarker.length);
    if (extracted.startsWith('\r\n')) {
      extracted = extracted.substring(2);
    } else if (extracted.startsWith('\n') || extracted.startsWith('\r')) {
      extracted = extracted.substring(1);
    }
    return extracted;
  }
}
