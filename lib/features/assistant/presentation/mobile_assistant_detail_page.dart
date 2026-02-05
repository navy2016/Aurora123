import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurora/l10n/app_localizations.dart';
import 'package:aurora/shared/widgets/aurora_bottom_sheet.dart';
import '../domain/assistant.dart';
import 'widgets/assistant_avatar.dart';
import 'assistant_provider.dart';
import '../../settings/presentation/widgets/mobile_settings_widgets.dart';
import '../../skills/presentation/skill_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class MobileAssistantDetailPage extends ConsumerStatefulWidget {
  final Assistant assistant;

  const MobileAssistantDetailPage({super.key, required this.assistant});

  @override
  ConsumerState<MobileAssistantDetailPage> createState() =>
      _MobileAssistantDetailPageState();
}

class _MobileAssistantDetailPageState
    extends ConsumerState<MobileAssistantDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _systemPromptController;
  late Assistant _currentAssistant;

  @override
  void initState() {
    super.initState();
    _currentAssistant = widget.assistant;
    _nameController = TextEditingController(text: _currentAssistant.name);
    _descriptionController =
        TextEditingController(text: _currentAssistant.description);
    _systemPromptController =
        TextEditingController(text: _currentAssistant.systemPrompt);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = _currentAssistant.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      systemPrompt: _systemPromptController.text,
    );
    await ref.read(assistantProvider.notifier).saveAssistant(updated);
    if (mounted) {
      setState(() {
        _currentAssistant = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
      appBar: AppBar(
        title: const Text(''),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _showDeleteDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Basic Info
          _buildHeroSection(context, theme, l10n),

          MobileSettingsSection(
            title: '基本配置',
            children: [
              _buildTextFieldTile(
                controller: _nameController,
                label: '名称',
                onChanged: (_) => _save(),
              ),
              _buildTextFieldTile(
                controller: _descriptionController,
                label: '描述',
                onChanged: (_) => _save(),
              ),
            ],
          ),

          MobileSettingsSection(
            title: '核心设定',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.systemPrompt,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _systemPromptController,
                      maxLines: 10,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: l10n.systemPromptPlaceholder,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: theme.cardColor.withValues(alpha: 0.5),
                      ),
                      onChanged: (_) => _save(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          MobileSettingsSection(
            title: '能力配置',
            children: [
              MobileSettingsTile(
                leading: const Icon(Icons.extension_outlined),
                title: '技能管理',
                subtitle: '已启用 ${_currentAssistant.skillIds.length} 个技能',
                onTap: () => _showSkillPicker(context),
              ),
              MobileSettingsTile(
                leading: const Icon(Icons.memory_outlined),
                title: '长期记忆',
                subtitle: _currentAssistant.enableMemory ? '已开启' : '已关闭',
                trailing: Switch.adaptive(
                  value: _currentAssistant.enableMemory,
                  onChanged: (v) {
                    _updateAssistant(
                        _currentAssistant.copyWith(enableMemory: v));
                  },
                ),
                onTap: () {
                  _updateAssistant(_currentAssistant.copyWith(
                      enableMemory: !_currentAssistant.enableMemory));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            children: [
              _buildAvatar(context, _currentAssistant, size: 100),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldTile({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
        ),
        onChanged: onChanged,
      ),
    );
  }

  void _updateAssistant(Assistant updated) {
    setState(() {
      _currentAssistant = updated;
    });
    ref.read(assistantProvider.notifier).saveAssistant(updated);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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
          ),
        ],
      );

      if (croppedFile != null) {
        _updateAssistant(_currentAssistant.copyWith(avatar: croppedFile.path));
      }
    }
  }

  void _showSkillPicker(BuildContext context) {
    final skills = ref
        .read(skillProvider)
        .skills
        .where((s) => s.isEnabled && s.forAI)
        .toList();
    if (skills.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无可用技能')));
      return;
    }

    AuroraBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuroraBottomSheet.buildTitle(context, '配置技能'),
            const Divider(height: 1),
            Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: skills.map((skill) {
                  final isSelected =
                      _currentAssistant.skillIds.contains(skill.id);
                  return CheckboxListTile(
                    title: Text(skill.name),
                    subtitle: Text(skill.description,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    value: isSelected,
                    onChanged: (v) {
                      final newIds =
                          List<String>.from(_currentAssistant.skillIds);
                      if (v == true) {
                        newIds.add(skill.id);
                      } else {
                        newIds.remove(skill.id);
                      }
                      // Update local state and parent state
                      final updated =
                          _currentAssistant.copyWith(skillIds: newIds);
                      // Update the main page state
                      setState(() {
                        _currentAssistant = updated;
                      });
                      // Update the bottom sheet state
                      setSheetState(() {});
                      ref
                          .read(assistantProvider.notifier)
                          .saveAssistant(updated);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除助理'),
        content: Text('确认要删除助理 "${_currentAssistant.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(assistantProvider.notifier)
                  .deleteAssistant(_currentAssistant.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(this.context); // close page
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, Assistant assistant,
      {double size = 40}) {
    return AssistantAvatar(assistant: assistant, size: size);
  }
}
