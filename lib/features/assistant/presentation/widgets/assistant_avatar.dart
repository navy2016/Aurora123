import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../domain/assistant.dart';
import '../../../../shared/theme/aurora_icons.dart';

class AssistantAvatar extends StatelessWidget {
  final Assistant? assistant;
  final double size;
  final Color? fallbackColor;

  const AssistantAvatar({
    super.key,
    this.assistant,
    this.size = 40,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    if (assistant?.avatar != null && assistant!.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: FileImage(File(assistant!.avatar!)),
        backgroundColor: Colors.transparent,
      );
    }

    final isFluent = fluent.FluentTheme.maybeOf(context) != null;
    final color = fallbackColor ?? (isFluent 
        ? fluent.FluentTheme.of(context).accentColor 
        : Theme.of(context).primaryColor);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        AuroraIcons.robot,
        size: size * 0.6,
        color: color,
      ),
    );
  }
}
