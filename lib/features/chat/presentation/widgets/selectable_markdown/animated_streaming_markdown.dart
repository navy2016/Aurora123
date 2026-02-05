import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'selectable_markdown.dart';

class AnimatedStreamingMarkdown extends StatefulWidget {
  final String data;
  final bool isDark;
  final Color textColor;
  final double baseFontSize;

  const AnimatedStreamingMarkdown({
    super.key,
    required this.data,
    required this.isDark,
    required this.textColor,
    this.baseFontSize = 14.0,
  });

  @override
  State<AnimatedStreamingMarkdown> createState() =>
      _AnimatedStreamingMarkdownState();
}

class _AnimatedStreamingMarkdownState extends State<AnimatedStreamingMarkdown> {
  late String _displayedData;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _displayedData = widget.data;
  }

  @override
  void didUpdateWidget(AnimatedStreamingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    // If widget.data is shorter or not a prefix (e.g. edit/delete), sync immediately
    if (_displayedData.length > widget.data.length ||
        !widget.data.startsWith(_displayedData)) {
      _displayedData = widget.data;
      _timer?.cancel();
      // Force rebuild to show immediate change
      if (mounted) setState(() {});
      return;
    }

    // If already equal, do nothing
    if (_displayedData.length == widget.data.length) return;

    // If timer is already running, let it continue, but it will use the new widget.data
    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final totalLength = widget.data.length;
      final currentLength = _displayedData.length;

      if (currentLength >= totalLength) {
        _displayedData = widget.data;
        timer.cancel();
        setState(() {});
        return;
      }

      final distance = totalLength - currentLength;

      // Dynamic step size for smooth catch-up
      // Min 1 char, max proportional to distance (distance/20)
      // This creates an ease-out effect
      int step = max(1, (distance / 20).ceil());
      // Increase minimum speed slightly to avoid crawling at the end
      if (step < 2) step = 2;

      final nextEnd = min(totalLength, currentLength + step);
      setState(() {
        _displayedData = widget.data.substring(0, nextEnd);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectableMarkdown(
      data: _displayedData,
      isDark: widget.isDark,
      textColor: widget.textColor,
      baseFontSize: widget.baseFontSize,
    );
  }
}
