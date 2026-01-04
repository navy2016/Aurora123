import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:crop_image/crop_image.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:path_provider/path_provider.dart';

class AvatarCropper {
  static Future<String?> cropImage(BuildContext context, String path) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪头像',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: '裁剪头像',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      );
      return cropped?.path;
    } else {
      // Desktop - Use pure Dart crop_image with Fluent UI Dialog
      return await showDialog<String>(
        context: context,
        builder: (context) => _DesktopCropDialog(imagePath: path),
      );
    }
  }
}

class _DesktopCropDialog extends StatefulWidget {
  final String imagePath;
  const _DesktopCropDialog({required this.imagePath});

  @override
  State<_DesktopCropDialog> createState() => _DesktopCropDialogState();
}

class _DesktopCropDialogState extends State<_DesktopCropDialog> {
  final _controller = CropController(
    aspectRatio: 1.0,
    defaultCrop: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
  );

  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return fluent.ContentDialog(
      title: const Text('裁剪头像'),
      content: Container(
        width: 500,
        height: 400,
        child: Column(
          children: [
             Expanded(
               child: CropImage(
                 controller: _controller,
                 image: Image.file(File(widget.imagePath)),
                 gridColor: Colors.white70,
                 gridCornerSize: 20,
                 touchSize: 20,
                 alwaysMove: true,
               ),
             ),
          ],
        ),
      ),
      actions: [
        fluent.Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        fluent.FilledButton(
          onPressed: _processing ? null : _save,
          child: _processing 
              ? const SizedBox(width: 16, height: 16, child: fluent.ProgressRing(strokeWidth: 2)) 
              : const Text('确定'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _processing = true);
    try {
      final bitmap = await _controller.croppedBitmap();
      final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('Failed to encode image');
      
      final bytes = data.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/avatar_crop_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      
      if (mounted) Navigator.pop(context, file.path);
    } catch (e) {
      debugPrint('Crop error: $e');
      if (mounted) Navigator.pop(context);
    }
  }
}
