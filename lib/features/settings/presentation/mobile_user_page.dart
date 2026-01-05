import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../shared/utils/avatar_cropper.dart';
import 'settings_provider.dart';

class MobileUserPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const MobileUserPage({super.key, this.onBack});
  @override
  ConsumerState<MobileUserPage> createState() => _MobileUserPageState();
}

class _MobileUserPageState extends ConsumerState<MobileUserPage> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final fluentTheme = fluent.FluentTheme.of(context);
    return Scaffold(
      backgroundColor: fluentTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('用户设置'),
        backgroundColor: fluentTheme.scaffoldBackgroundColor,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _SectionHeader(title: '对话体验', icon: Icons.chat_bubble_outline),
          SwitchListTile(
            title: const Text('智能话题生成'),
            subtitle: const Text('使用 LLM 自动总结作为话题标题'),
            value: settingsState.enableSmartTopic,
            onChanged: (bool value) {
              ref.read(settingsProvider.notifier).toggleSmartTopicEnabled(value);
            },
          ),
          if (settingsState.enableSmartTopic)
            ListTile(
              title: const Text('生成模型'),
              subtitle: Text(settingsState.topicGenerationModel == null
                  ? '未选择 (回退到截断)'
                  : settingsState.topicGenerationModel!.split('@').last),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showModelPicker(context, settingsState);
              },
            ),
          const Divider(),
          _SectionHeader(title: '用户信息', icon: Icons.person_outline),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('用户名称'),
            subtitle: Text(settingsState.userName.isNotEmpty
                ? settingsState.userName
                : '用户'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showTextEditor(
              context,
              '用户名称',
              settingsState.userName,
              (value) => ref
                  .read(settingsProvider.notifier)
                  .setChatDisplaySettings(userName: value),
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: settingsState.userAvatar?.isNotEmpty == true
                  ? FileImage(File(settingsState.userAvatar!))
                  : null,
              child: settingsState.userAvatar?.isNotEmpty != true
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            title: const Text('用户头像'),
            subtitle: const Text('点击更换头像'),
            trailing: const Icon(Icons.image),
            onTap: () => _showAvatarPicker(isUser: true),
          ),
          const Divider(),
          _SectionHeader(title: 'AI 信息', icon: Icons.smart_toy_outlined),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('AI 名称'),
            subtitle: Text(settingsState.llmName.isNotEmpty
                ? settingsState.llmName
                : 'Assistant'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showTextEditor(
              context,
              'AI 名称',
              settingsState.llmName,
              (value) => ref
                  .read(settingsProvider.notifier)
                  .setChatDisplaySettings(llmName: value),
            ),
          ),
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: settingsState.llmAvatar?.isNotEmpty == true
                  ? FileImage(File(settingsState.llmAvatar!))
                  : null,
              child: settingsState.llmAvatar?.isNotEmpty != true
                  ? const Icon(Icons.smart_toy, size: 20)
                  : null,
            ),
            title: const Text('AI 头像'),
            subtitle: const Text('点击更换头像'),
            trailing: const Icon(Icons.image),
            onTap: () => _showAvatarPicker(isUser: false),
          ),
        ],
      ),
    );
  }

  void _showTextEditor(BuildContext context, String title, String currentValue,
      Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑$title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '请输入$title',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAvatarPicker({required bool isUser}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // For rounded corners
      builder: (ctx) {
         return Container(
           decoration: BoxDecoration(
             color: Theme.of(context).scaffoldBackgroundColor,
             borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
           ),
           child: SafeArea(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const SizedBox(height: 8),
                 Container(
                   width: 32,
                   height: 4,
                   decoration: BoxDecoration(
                     color: Colors.grey[300],
                     borderRadius: BorderRadius.circular(2),
                   ),
                 ),
                 const SizedBox(height: 16),
                 Text(
                   '更换${isUser ? '用户' : 'AI'}头像',
                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(height: 16),
                 ListTile(
                   leading: const Icon(Icons.camera_alt),
                   title: const Text('拍照'),
                   onTap: () {
                     Navigator.pop(ctx);
                     _pickImage(ImageSource.camera, isUser);
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.photo_library),
                   title: const Text('从相册选择'),
                   onTap: () {
                     Navigator.pop(ctx);
                     _pickImage(ImageSource.gallery, isUser);
                   },
                 ),
                 if ((isUser ? ref.read(settingsProvider).userAvatar : ref.read(settingsProvider).llmAvatar) != null)
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('移除头像', style: TextStyle(color: Colors.red)),
                      onTap: () {
                         Navigator.pop(ctx);
                         if (isUser) {
                           ref.read(settingsProvider.notifier).setChatDisplaySettings(userAvatar: '');
                         } else {
                           ref.read(settingsProvider.notifier).setChatDisplaySettings(llmAvatar: '');
                         }
                      },
                    ),
                 const SizedBox(height: 16),
               ],
             ),
           ),
         );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, bool isUser) async {
    // Permission Handling
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        if (mounted) _showPermissionDialog('相机');
        return;
      }
      if (!status.isGranted) return;
    } else {
      // For gallery, Android 13+ (SDK 33) uses Photo Picker which doesn't need permissions
      // For older versions, we might need storage permission.
      // However, image_picker usually handles this nicely.
      // We'll check photos permission just in case for older Androids if needed,
      // but usually standard practice keeps it simple.
      // Let's rely on image_picker unless it fails.
      // Actually, for consistency, checking photos/storage is good practice if not using Photo Picker.
      if (Platform.isAndroid) {
         // Simple check: if SDK < 33, check storage/photos. But checking SDK version in Dart is tedious without device_info.
         // We'll try to request photos permission if it's explicitly denied.
         // But Permission.photos is for iOS/Android 13+. Permission.storage is for older.
         // Let's just try to pick, handling error if it happens is complex.
         // Using Permission.photos.request() on Android < 13 will request READ_MEDIA_IMAGES (Android 13) or nothing?
         // Safer to trust ImagePicker plugin for Gallery logic usually.
      }
    }

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final croppedPath = await AvatarCropper.cropImage(context, image.path);
        if (croppedPath != null) {
          if (isUser) {
            ref.read(settingsProvider.notifier).setChatDisplaySettings(userAvatar: croppedPath);
          } else {
            ref.read(settingsProvider.notifier).setChatDisplaySettings(llmAvatar: croppedPath);
          }
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('选择图片失败: $e')),
         );
      }
    }
  }

  void _showPermissionDialog(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('需要$name权限'),
        content: Text('请在设置中允许应用访问$name，以便拍摄头像。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
  void _showModelPicker(BuildContext context, SettingsState settings) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 400,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('选择话题生成模型',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final provider in settings.providers)
                      if (provider.isEnabled)
                        for (final model in provider.models)
                          ListTile(
                            title: Text(model),
                            subtitle: Text(provider.name),
                            selected: settings.topicGenerationModel ==
                                '${provider.id}@$model',
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTopicGenerationModel('${provider.id}@$model');
                              Navigator.pop(context);
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
