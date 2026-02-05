class StringUtils {
  /// 统计字数（中英文混合）
  /// 规则：
  /// 1. 每个中文字符（包含日韩文）计为 1 个字
  /// 2. 每个连续的英文单词/数字计为 1 个字
  /// 3. 忽略空白字符
  static int countWords(String text) {
    if (text.isEmpty) return 0;

    int total = 0;

    // 统计中文字符、韩文、日文等
    // \u4e00-\u9fa5: 中文
    // \u3040-\u30ff: 日文 (平假名 & 片假名)
    // \uac00-\ud7af: 韩文
    final cjkRegex = RegExp(r'[\u4e00-\u9fa5\u3040-\u30ff\uac00-\ud7af]');
    total += cjkRegex.allMatches(text).length;

    // 统计英文单词和数字
    final wordRegex = RegExp(r'[a-zA-Z0-9]+');
    total += wordRegex.allMatches(text).length;

    return total;
  }

  /// 统计总字符数（不含空白符）
  static int countCharacters(String text, {bool includeWhitespace = false}) {
    if (includeWhitespace) {
      return text.length;
    }
    return text.replaceAll(RegExp(r'\s+'), '').length;
  }
}
