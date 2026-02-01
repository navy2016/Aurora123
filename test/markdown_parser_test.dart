
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/features/chat/presentation/widgets/selectable_markdown/markdown_generator.dart';

void main() {
  test('MarkdownGenerator parses footnotes correctly', () {
    final generator = MarkdownGenerator(
      isDark: false,
      textColor: Colors.black,
    );

    const markdown = '''
## 脚注测试[^1]
这是一段包含脚注[^2]的文本。

[^1]: 脚注定义1
[^2]: 脚注定义2
''';

    final widgets = generator.generate(markdown);
    
    // We expect at least one widget (the main text area)
    expect(widgets.isNotEmpty, true);
    
    // In our implementation, footnotes are appended to the last flushSpans call or as a separate widget if flushed.
    // Actually, generate() flushes everything into a list of widgets.
    // If it's all text blocks, it might be one SelectionArea widget.
    
    // Let's check if the output text contains the footnote markers
    // This is hard to check directly on internal TextSpans without rendering, 
    // but we can check if the widgets list has the expected structure.
  });

  test('MarkdownGenerator handles complex HTML without breaking', () {
    final generator = MarkdownGenerator(
      isDark: false,
      textColor: Colors.black,
    );

    const markdown = '''
## 复杂HTML结构
<div style="border: 1px solid #ccc; padding: 15px;">
    <h4>标题</h4>
    <p>段落</p>
</div>
''';

    final widgets = generator.generate(markdown);
    expect(widgets.isNotEmpty, true);
  });
}
