import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/features/studio/presentation/novel/novel_provider.dart';

void main() {
  group('NovelPromptPresets', () {
    test('keeps required core prompts non-empty', () {
      expect(NovelPromptPresets.outline, isNotEmpty);
      expect(NovelPromptPresets.writerBase, isNotEmpty);
      expect(NovelPromptPresets.reviewer, isNotEmpty);
      expect(NovelPromptPresets.reviser, isNotEmpty);
    });

    test('writer getter maps to writerBase', () {
      expect(NovelPromptPresets.writer, equals(NovelPromptPresets.writerBase));
    });
  });
}
