import 'package:flutter/material.dart';

class AuroraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool showBorder;
  final double borderOpacity;
  final Color? backgroundColor;
  final Color? borderColor;
  final Clip clipBehavior;

  const AuroraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 16,
    this.showBorder = true,
    this.borderOpacity = 0.1,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderColor =
        borderColor ?? theme.dividerColor.withValues(alpha: borderOpacity);

    return Card(
      margin: margin,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: backgroundColor ?? theme.cardColor,
      clipBehavior: clipBehavior,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: showBorder
            ? BorderSide(color: effectiveBorderColor)
            : BorderSide.none,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
