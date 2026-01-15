import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Generates a list of widgets from markdown text.
/// Continuous inline/block text is merged into SelectableText.rich,
/// while code blocks, tables, and images break the flow.
class MarkdownGenerator {
  final bool isDark;
  final Color textColor;
  final double baseFontSize;

  MarkdownGenerator({
    required this.isDark,
    required this.textColor,
    this.baseFontSize = 14.0,
  });

  /// Parse markdown and return a list of widgets
  List<Widget> generate(String markdownText) {
    final preprocessedText = _preprocessMarkdown(markdownText);
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
    );
    final nodes = document.parseLines(preprocessedText.split('\n'));

    final List<Widget> widgets = [];
    final List<InlineSpan> currentSpans = [];

    int widgetIndex = 0;

    void flushSpans() {
      // Remove trailing newlines to avoid extra spacing before barriers
      while (currentSpans.isNotEmpty &&
          currentSpans.last is TextSpan &&
          (currentSpans.last as TextSpan).text == '\n\n') {
        currentSpans.removeLast();
      }
      // Also trim single newlines at the very end
      if (currentSpans.isNotEmpty &&
          currentSpans.last is TextSpan &&
          (currentSpans.last as TextSpan).text == '\n') {
        currentSpans.removeLast();
      }

      if (currentSpans.isNotEmpty) {
        widgets.add(
          SelectionArea(
            child: Text.rich(
              TextSpan(children: List.from(currentSpans)),
              key: ValueKey('text_${widgetIndex++}'),
              style: TextStyle(
                color: textColor,
                fontSize: baseFontSize,
                height: 1.5,
              ),
            ),
          ),
        );
        currentSpans.clear();
      }
    }

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is md.Element && _isHardBarrier(node.tag)) {
        flushSpans();
        widgets.add(_buildBarrierWidget(node, widgetIndex++));
      } else {
        // Use the new context-aware traversal
        final spans = _visit(node, GeneratorContext());

        // Remove trailing newline from the block's content itself
        // (This handles the case where preprocessing added a hard break at the end of a block)
        if (spans.isNotEmpty) {
          if (spans.last is TextSpan && (spans.last as TextSpan).text == '\n') {
            spans.removeLast();
          }
        }

        currentSpans.addAll(spans);

        // Add block separation if needed
        if (_isBlockElement(node is md.Element ? node.tag : '')) {
          // Ensure double newline after top-level blocks for spacing,
          // but check if we are not the last node
          if (i < nodes.length - 1) {
            currentSpans.add(const TextSpan(text: '\n\n'));
          }
        } else {
          // For text nodes or others at top level, a single newline is usually implicit from split handling
          // but standard markdown accumulates.
          // We add a newline to simulate line break if it was a distinct line in source.
          currentSpans.add(const TextSpan(text: '\n'));
        }
      }
    }

    flushSpans();
    return widgets;
  }

  /// Preprocess markdown to enforce hard line breaks for single newlines,
  /// except inside code blocks.
  String _preprocessMarkdown(String text) {
    final StringBuffer buffer = StringBuffer();
    final List<String> segments = text.split('```');

    for (int i = 0; i < segments.length; i++) {
      String segment = segments[i];
      if (i % 2 == 0) {
        // Outside code block: replace newlines with double space + newline
        // (Markdown hard break).
        // We avoid replacing newlines that are already followed by spaces or other structure if possible,
        // but broadly replacing \n with "  \n" works for "Chat" style.
        // Also need to be careful not to break list markers.
        // Actually, just replacing \n with "  \n" is risky for lists.
        // BUT, since we are doing custom list rendering, maybe we don't need to force markdown parser to see hard breaks?
        // If we want "text\ntext" to be distinct lines, the parser treats it as one p block "text text".
        // Use "  \n" makes it "text<br>text".

        // We will do a simple pass: Regex remove single newlines?
        // No, let's try a safer approach:
        // Identify lines. If line ends with non-space, add "  ".
        final lines = segment.split('\n');
        for (int j = 0; j < lines.length; j++) {
          String line = lines[j];
          if (line.trim().isNotEmpty && !line.trimRight().endsWith('  ')) {
            buffer.write('$line  \n');
          } else {
            buffer.write('$line\n');
          }
        }
      } else {
        // Inside code block: keep as is, just re-add the backticks we split by
        buffer.write('```$segment```');
      }
    }
    return buffer.toString();
  }

  bool _isHardBarrier(String tag) {
    return tag == 'pre' || tag == 'table' || tag == 'img' || tag == 'hr';
  }

  bool _isBlockElement(String tag) {
    return [
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'blockquote',
      'ul',
      'ol',
      'div'
    ].contains(tag);
  }

  /// The main recursive visitor
  List<InlineSpan> _visit(md.Node node, GeneratorContext context) {
    if (node is md.Text) {
      // Check if text is just a newline or empty?
      // Preprocessing usually handles line breaks.
      return [TextSpan(text: node.text, style: context.currentStyle)];
    }

    if (node is md.Element) {
      final tag = node.tag;

      // --- Block Elements ---

      if (tag == 'ul' || tag == 'ol') {
        final List<InlineSpan> spans = [];
        // If this list is nested (indent > 0), ensure we start on a new line?
        // Handled by parent li processing generally.

        int listIndex = 0;
        for (final child in node.children ?? []) {
          if (child is md.Element && child.tag == 'li') {
            // Pass context to li
            final childContext = context.copyWith(
              indentLevel: context.indentLevel + 1,
              listType: tag,
              listIndex: listIndex,
            );
            spans.addAll(_processListItem(child, childContext));
            listIndex++;
          } else {
            // Non-li child in list? Just visit.
            spans.addAll(_visit(child, context));
          }
        }
        return spans;
      }

      // --- Inline / formatting Elements ---

      // Calculate style for this element
      TextStyle? style = context.currentStyle;

      switch (tag) {
        case 'h1':
          style = _headingStyle(1);
          break;
        case 'h2':
          style = _headingStyle(2);
          break;
        case 'h3':
          style = _headingStyle(3);
          break;
        case 'h4':
          style = _headingStyle(4);
          break;
        case 'h5':
          style = _headingStyle(5);
          break;
        case 'h6':
          style = _headingStyle(6);
          break;
        case 'strong':
        case 'b':
          style = (style ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.bold);
          break;
        case 'em':
        case 'i':
          style = (style ?? const TextStyle())
              .copyWith(fontStyle: FontStyle.italic);
          break;
        case 'del':
        case 's':
          style = (style ?? const TextStyle())
              .copyWith(decoration: TextDecoration.lineThrough);
          break;
        case 'code':
          style = (style ?? const TextStyle()).copyWith(
            fontFamily: 'monospace',
            backgroundColor:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          );
          break;
        case 'a':
          style = (style ?? const TextStyle()).copyWith(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          );
          // Link handling needs tap recognizer, which requires TextSpan specific logic.
          // We'll handle it below.
          break;
      }

      final childContext = context.copyWith(currentStyle: style);
      final List<InlineSpan> childrenSpans = [];

      for (final child in node.children ?? []) {
        childrenSpans.addAll(_visit(child, childContext));
      }

      // Post-process specific tags
      if (tag == 'a') {
        final href = node.attributes['href'] ?? '';
        return [
          TextSpan(
              children: childrenSpans,
              style: style,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  final uri = Uri.tryParse(href);
                  if (uri != null) launchUrl(uri);
                })
        ];
      } else if (tag == 'p') {
        // Return children. Top level loop adds spacing.
        // If nested deeply, might need check.
        return childrenSpans;
      } else if (tag == 'br') {
        return [const TextSpan(text: '\n')];
      } else if (tag.startsWith('h')) {
        // Headings usually block
        return [
          TextSpan(children: childrenSpans),
        ];
        // Note: we might want explicit \n here if not handled at top level?
      } else if (tag == 'blockquote') {
        // Wrap in a visual indicator?
        // Hard to do in TextSpan.
        // We can prefix lines with "> ".
        // But children are flattened.
        // Let's just return children with italic style logic above.
        return childrenSpans;
      }

      // Default: return styled children
      return [TextSpan(children: childrenSpans, style: style)];
    }

    return [];
  }

  List<InlineSpan> _processListItem(md.Element li, GeneratorContext context) {
    final List<InlineSpan> spans = [];

    // 1. Newline
    // Only add newline if it's NOT the first item of a top-level list.
    // Top-level blocks are separated by \n\n in the main loop.
    // Nested items always need a newline to separate from parent text.
    if (context.indentLevel > 1 || context.listIndex > 0) {
      spans.add(const TextSpan(text: '\n'));
    }

    // 2. Indentation
    // Level 0 is inside the first ul/ol (so indentation 1 conceptually?)
    // User wants hierarchy.
    // context.indentLevel starts at 1 for the first level typically.
    if (context.indentLevel > 1) {
      spans.add(TextSpan(text: '    ' * (context.indentLevel - 1)));
    }

    // 3. Marker
    String marker;
    if (context.listType == 'ol') {
      marker = '${context.listIndex + 1}. ';
    } else {
      // Vary bullet based on indentation level
      // Level 1: • (Disc)
      // Level 2: ◦ (Circle)
      // Level 3: ▪ (Square)
      final int styleIndex = (context.indentLevel - 1) % 3;
      switch (styleIndex) {
        case 1:
          marker = '◦ ';
          break;
        case 2:
          marker = '▪ ';
          break;
        case 0:
        default:
          marker = '• ';
          break;
      }
    }

    spans.add(TextSpan(
      text: marker,
      style: (context.currentStyle ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    ));

    // 4. Content
    // Recursively visit children.
    // IMPORTANT: Children might include nested lists (ul/ol).
    // Nested lists will trigger _visit('ul') -> calls _processListItem with increased indent.
    for (final child in li.children ?? []) {
      spans.addAll(_visit(child, context));
    }

    return spans;
  }

  TextStyle _headingStyle(int level) {
    double size = baseFontSize;
    switch (level) {
      case 1:
        size *= 1.5;
        break;
      case 2:
        size *= 1.4;
        break;
      case 3:
        size *= 1.3;
        break;
      case 4:
        size *= 1.2;
        break;
      case 5:
        size *= 1.1;
        break;
      case 6:
        size *= 1.0;
        break;
    }
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: textColor,
    );
  }

  // ... _buildBarrierWidget methods (copy from original) ...
  Widget _buildBarrierWidget(md.Element element, int index) {
    switch (element.tag) {
      case 'pre':
        return _buildCodeBlock(element, index);
      case 'table':
        return _buildTable(element, index);
      case 'img':
        return _buildImage(element, index);
      case 'hr':
        return const Divider(height: 24, thickness: 1);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCodeBlock(md.Element element, int index) {
    String code = '';
    String? language;

    if (element.children != null && element.children!.isNotEmpty) {
      final codeElement = element.children!.first;
      if (codeElement is md.Element && codeElement.tag == 'code') {
        code = codeElement.textContent;
        language =
            codeElement.attributes['class']?.replaceFirst('language-', '');
      } else {
        code = element.textContent;
      }
    } else {
      code = element.textContent;
    }

    if (code.endsWith('\n')) {
      code = code.substring(0, code.length - 1);
    }

    return Container(
      key: ValueKey('code_$index'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language ?? 'code',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                _CopyButton(
                  text: code,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                code,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(md.Element element, int index) {
    final List<TableRow> rows = [];
    final Map<int, int> colMaxLengths = {};
    int colCount = 0;

    // Helper to process rows and gather stats
    void processRow(md.Element row, {required bool isHeader}) {
      int cellIndex = 0;
      final List<Widget> cells = [];
      for (final cellNode in row.children ?? []) {
        if (cellNode is md.Element &&
            (cellNode.tag == 'th' || cellNode.tag == 'td')) {
          final text = cellNode.textContent;
          final len = text.length;
          colMaxLengths[cellIndex] = (colMaxLengths[cellIndex] ?? 0) < len
              ? len
              : colMaxLengths[cellIndex]!;

          cells.add(
            Padding(
              padding: const EdgeInsets.all(8),
              child: SelectionArea(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: baseFontSize,
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
          cellIndex++;
        }
      }
      if (cellIndex > colCount) colCount = cellIndex;

      rows.add(TableRow(
        decoration: isHeader
            ? BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.03),
              )
            : null,
        children: cells,
      ));
    }

    for (final child in element.children ?? []) {
      if (child is md.Element) {
        if (child.tag == 'thead' || child.tag == 'tbody') {
          for (final rowNode in child.children ?? []) {
            if (rowNode is md.Element && rowNode.tag == 'tr') {
              processRow(rowNode, isHeader: child.tag == 'thead');
            }
          }
        } else if (child.tag == 'tr') {
          processRow(child, isHeader: false);
        }
      }
    }

    // Calculate column widths
    // We use FlexColumnWidth based on max character length.
    // Minimum flex is 1. We might want to cap the ratio or use a heuristic.
    // E.g. Header keys are usually short (~10), Content is long (~100).
    // Ratio 1:10.
    final Map<int, TableColumnWidth> columnWidths = {};
    for (int i = 0; i < colCount; i++) {
      // Estimate width:
      // Chinese characters are visual wide, but length is 1.
      // We can just use raw length as a rough proxy.
      // Add a base buffer of 5 to avoid crushing very short columns too much.
      int length = colMaxLengths[i] ?? 0;
      double flex = (length + 5).toDouble();
      columnWidths[i] = FlexColumnWidth(flex);
    }

    // Fallback if empty
    if (columnWidths.isEmpty && colCount > 0) {
      for (int i = 0; i < colCount; i++) {
        columnWidths[i] = const FlexColumnWidth();
      }
    }

    return Container(
      key: ValueKey('table_$index'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        columnWidths: columnWidths,
        defaultColumnWidth: const FlexColumnWidth(),
        children: rows,
      ),
    );
  }

  Widget _buildImage(md.Element element, int index) {
    final src = element.attributes['src'] ?? '';
    final alt = element.attributes['alt'] ?? '';
    if (src.isEmpty) {
      return Text('[$alt]', style: TextStyle(color: textColor));
    }
    return Container(
      key: ValueKey('img_$index'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Image.network(
        src,
        errorBuilder: (context, error, stackTrace) {
          return Text('[$alt]', style: TextStyle(color: textColor));
        },
      ),
    );
  }
}

/// Context passed down during recursive traversal
class GeneratorContext {
  final int indentLevel;
  final String? listType; // 'ul' or 'ol'
  final int listIndex;
  final TextStyle? currentStyle;

  GeneratorContext({
    this.indentLevel = 0,
    this.listType,
    this.listIndex = 0,
    this.currentStyle,
  });

  GeneratorContext copyWith({
    int? indentLevel,
    String? listType,
    int? listIndex,
    TextStyle? currentStyle,
  }) {
    return GeneratorContext(
      indentLevel: indentLevel ?? this.indentLevel,
      listType: listType ?? this.listType,
      listIndex: listIndex ?? this.listIndex,
      currentStyle: currentStyle ?? this.currentStyle,
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  final Color color;

  const _CopyButton({required this.text, required this.color});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _hasCopied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (mounted) {
          setState(() {
            _hasCopied = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _hasCopied = false;
              });
            }
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _hasCopied ? Icons.check : Icons.copy,
          size: 16,
          color: _hasCopied ? Colors.green : widget.color,
        ),
      ),
    );
  }
}
