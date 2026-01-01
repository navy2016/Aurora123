import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowButtons extends StatefulWidget {
  const WindowButtons({super.key});

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    return fluent.Row( // Explicit fluent.Row or just Row? Imports show alias.
      // But Row is Flutter Material usually. Fluent also has Row? No, Fluent uses Flutter widgets.
      // Wait, 'fluent_ui' exports material widgets? 
      // Usually Row is from widgets library.
      // Let's use fluent.Row? No, standard Row.
      children: [
        fluent.IconButton(
          icon: fluent.Icon(fluent.FluentIcons.chrome_minimize,
              size: 10, color: theme.typography.caption?.color),
          onPressed: () => windowManager.minimize(),
        ),
        FutureBuilder<bool>(
          future: windowManager.isMaximized(),
          builder: (context, snapshot) {
            final isMaximized = snapshot.data ?? false;
            return fluent.IconButton(
              icon: fluent.Icon(
                  isMaximized
                      ? fluent.FluentIcons.chrome_restore
                      : fluent.FluentIcons.square_shape,
                  size: 10,
                  color: theme.typography.caption?.color),
              onPressed: () {
                if (isMaximized) {
                  windowManager.restore();
                } else {
                  windowManager.maximize();
                }
                setState(() {});
              },
            );
          },
        ),
        fluent.IconButton(
          icon: fluent.Icon(fluent.FluentIcons.chrome_close,
              size: 10, color: theme.typography.caption?.color),
          onPressed: () => windowManager.close(),
          style: fluent.ButtonStyle(
            backgroundColor: fluent.ButtonState.resolveWith((states) {
              if (states.isHovering) return fluent.Colors.red;
              return fluent.Colors.transparent;
            }),
            foregroundColor: fluent.ButtonState.resolveWith((states) {
              if (states.isHovering) return fluent.Colors.white;
              return theme.typography.caption?.color;
            }),
          ),
        ),
      ],
    );
  }

  @override
  void onWindowMaximize() => setState(() {});
  @override
  void onWindowUnmaximize() => setState(() {});
  @override
  void onWindowRestore() => setState(() {});
}
