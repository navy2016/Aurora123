import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:aurora/shared/widgets/aurora_bottom_sheet.dart';
import 'package:flutter/material.dart';

import 'package:aurora/l10n/app_localizations.dart';

class ChatAttachmentMenu {
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onPickVideo,
    required VoidCallback onPickFile,
  }) async {
    final theme = fluent.FluentTheme.of(context);
    final isDark = theme.brightness == fluent.Brightness.dark;
    await AuroraBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAttachmentOption(
            context,
            icon: Icons.camera_alt_outlined,
            label: AppLocalizations.of(context)!.takePhoto,
            onTap: () {
              Navigator.pop(ctx);
              onPickCamera();
            },
          ),
          _buildAttachmentOption(
            context,
            icon: Icons.photo_library_outlined,
            label: AppLocalizations.of(context)!.selectFromGallery,
            onTap: () {
              Navigator.pop(ctx);
              onPickGallery();
            },
          ),
          _buildAttachmentOption(
            context,
            icon: Icons.videocam_outlined,
            label: AppLocalizations.of(context)!.selectVideo,
            onTap: () {
              Navigator.pop(ctx);
              onPickVideo();
            },
          ),
          _buildAttachmentOption(
            context,
            icon: Icons.folder_open_outlined,
            label: AppLocalizations.of(context)!.selectFile,
            onTap: () {
              Navigator.pop(ctx);
              onPickFile();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 17)),
          ],
        ),
      ),
    );
  }
}
