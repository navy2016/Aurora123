import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Snaps selection gestures that start in whitespace (outside any child's glyph
/// bounding boxes) back onto the nearest selectable child, so drag-selection can
/// begin reliably even for complex Markdown layouts.
class _SnappingSelectionContainerDelegate
    extends StaticSelectionContainerDelegate {
  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    final Offset? snapped = _maybeSnapPosition(event.globalPosition);
    if (snapped == null) {
      return super.handleSelectionEdgeUpdate(event);
    }

    final SelectionEdgeUpdateEvent snappedEvent =
        event.type == SelectionEventType.startEdgeUpdate
            ? SelectionEdgeUpdateEvent.forStart(
                globalPosition: snapped,
                granularity: event.granularity,
              )
            : SelectionEdgeUpdateEvent.forEnd(
                globalPosition: snapped,
                granularity: event.granularity,
              );
    return super.handleSelectionEdgeUpdate(snappedEvent);
  }

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    final Offset? snapped = _maybeSnapPosition(event.globalPosition);
    if (snapped == null) {
      return super.handleSelectWord(event);
    }
    return super
        .handleSelectWord(SelectWordSelectionEvent(globalPosition: snapped));
  }

  @override
  SelectionResult handleSelectParagraph(SelectParagraphSelectionEvent event) {
    final Offset? snapped = _maybeSnapPosition(event.globalPosition);
    if (snapped == null) {
      return super.handleSelectParagraph(event);
    }
    return super.handleSelectParagraph(
      SelectParagraphSelectionEvent(
        globalPosition: snapped,
        absorb: event.absorb,
      ),
    );
  }

  Offset? _maybeSnapPosition(Offset globalPosition) {
    if (!hasSize || selectables.isEmpty) return null;

    // Only snap when the pointer is within this container; if it is outside,
    // allow selection to flow to siblings/parents (e.g. dragging beyond bounds).
    final Rect globalContainerRect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & containerSize,
    );
    if (!globalContainerRect.contains(globalPosition)) return null;

    // If the position is already inside a selectable's bounds, keep native behavior.
    final Rect? nearest = _nearestSelectableRect(globalPosition);
    if (nearest == null || nearest.contains(globalPosition)) return null;

    return _clampOffsetToRect(globalPosition, nearest);
  }

  Rect? _nearestSelectableRect(Offset globalPosition) {
    Rect? bestRect;
    double bestDy = double.infinity;
    double bestDx = double.infinity;

    for (final Selectable selectable in selectables) {
      if (selectable.boundingBoxes.isEmpty) continue;
      final Rect localRect = _unionRects(selectable.boundingBoxes);
      if (localRect.isEmpty) continue;
      final Rect rect = MatrixUtils.transformRect(
        selectable.getTransformTo(null),
        localRect,
      );
      if (rect.isEmpty) continue;
      if (rect.contains(globalPosition)) {
        return rect;
      }

      final double dy =
          _distanceToRange(globalPosition.dy, rect.top, rect.bottom);
      final double dx =
          _distanceToRange(globalPosition.dx, rect.left, rect.right);

      const double epsilon = 0.5;
      final bool betterDy = dy < bestDy - epsilon;
      final bool equalDy = (dy - bestDy).abs() <= epsilon;
      if (betterDy || (equalDy && dx < bestDx)) {
        bestRect = rect;
        bestDy = dy;
        bestDx = dx;
      }
    }

    return bestRect;
  }

  static double _distanceToRange(double value, double min, double max) {
    if (value < min) return min - value;
    if (value > max) return value - max;
    return 0.0;
  }

  static Rect _unionRects(List<Rect> rects) {
    Rect result = rects.first;
    for (int i = 1; i < rects.length; i += 1) {
      result = result.expandToInclude(rects[i]);
    }
    return result;
  }

  static Offset _clampOffsetToRect(Offset value, Rect rect) {
    const double epsilon = 0.5;

    final double xMin = rect.left + epsilon;
    final double xMax = rect.right - epsilon;
    final double yMin = rect.top + epsilon;
    final double yMax = rect.bottom - epsilon;

    final double x =
        xMin <= xMax ? value.dx.clamp(xMin, xMax).toDouble() : rect.center.dx;
    final double y =
        yMin <= yMax ? value.dy.clamp(yMin, yMax).toDouble() : rect.center.dy;

    return Offset(x, y);
  }
}

class _SelectableMarkdownState extends State<SelectableMarkdown> {
  late List<Widget> _children;
  late final _SnappingSelectionContainerDelegate _selectionDelegate;

  @override
  void initState() {
    super.initState();
    _children = const [];
    _selectionDelegate = _SnappingSelectionContainerDelegate();
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
    );
    _children = generator.generate(widget.data);
  }

  @override
  void dispose() {
    _selectionDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_children.isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectionArea(
      child: SelectionContainer(
        delegate: _selectionDelegate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _children,
        ),
      ),
    );
  }
}
