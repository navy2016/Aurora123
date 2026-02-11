import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurora/l10n/app_localizations.dart';
import 'markdown_generator.dart';

/// A widget that renders markdown content with native text selection.
/// Uses SelectableText.rich for text blocks and specialized widgets for
/// code blocks, tables, and images.
class SelectableMarkdown extends StatefulWidget {
  final String data;
  final bool isDark;
  final Color textColor;
  final double baseFontSize;

  const SelectableMarkdown({
    super.key,
    required this.data,
    required this.isDark,
    required this.textColor,
    this.baseFontSize = 14.0,
  });

  @override
  State<SelectableMarkdown> createState() => _SelectableMarkdownState();
}

class _SelectableMarkdownState extends State<SelectableMarkdown> {
  late List<Widget> _children;
  String? _selectedText;
  String? _lastInteractedLatex;

  @override
  void initState() {
    super.initState();
    _children = const [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _generateChildren();
  }

  @override
  void didUpdateWidget(SelectableMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.isDark != widget.isDark ||
        oldWidget.textColor != widget.textColor ||
        oldWidget.baseFontSize != widget.baseFontSize) {
      _generateChildren();
    }
  }

  void _generateChildren() {
    final l10n = AppLocalizations.of(context);
    final generator = MarkdownGenerator(
      isDark: widget.isDark,
      textColor: widget.textColor,
      baseFontSize: widget.baseFontSize,
      footnotesTitle: l10n?.footnotes ?? 'Footnotes',
      undefinedFootnoteText: (id) =>
          l10n?.undefinedFootnote(id) ?? 'Undefined footnote: $id',
      onLatexInteract: (latex) {
        _lastInteractedLatex = latex;
      },
    );
    _children = generator.generate(widget.data);
  }

  String? _reconstructSelectionFromSource(String selected) {
    final normalizedSelection = selected.trim();
    if (normalizedSelection.isEmpty) return null;

    // If selection already exists exactly in source, keep default behavior.
    if (widget.data.contains(normalizedSelection)) {
      return normalizedSelection;
    }

    final tokens = normalizedSelection
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.length < 2) return null;

    int searchFrom = 0;
    int? start;
    int end = -1;
    int matched = 0;

    for (final token in tokens) {
      final idx = widget.data.indexOf(token, searchFrom);
      if (idx < 0) {
        continue;
      }
      start ??= idx;
      end = idx + token.length;
      searchFrom = end;
      matched++;
    }

    if (start == null || end <= start) return null;
    if (matched < (tokens.length * 0.6).ceil()) return null;

    final candidate = widget.data.substring(start, end);

    // Guardrail: avoid expanding to an unrelated huge range.
    if (candidate.length > normalizedSelection.length * 8 + 300) {
      return null;
    }

    return candidate;
  }

  @override
  Widget build(BuildContext context) {
    if (_children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Actions(
      actions: <Type, Action<Intent>>{
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (_) {
            final selected = _selectedText;
            String? textToCopy;

            if (selected != null && selected.isNotEmpty) {
              textToCopy =
                  _reconstructSelectionFromSource(selected) ?? selected;
            } else if (_lastInteractedLatex != null &&
                _lastInteractedLatex!.isNotEmpty) {
              textToCopy = _lastInteractedLatex;
            }

            if (textToCopy != null && textToCopy.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: textToCopy));
            }
            return null;
          },
        ),
      },
      child: SelectionArea(
        onSelectionChanged: (selection) {
          _selectedText = selection?.plainText;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _children,
        ),
      ),
    );
  }
}
