import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurora/features/settings/presentation/settings_provider.dart';
import 'package:aurora/l10n/app_localizations.dart';
import '../novel_provider.dart';
import '../novel_state.dart';

class ModelConfigDialog extends ConsumerStatefulWidget {
  const ModelConfigDialog({super.key});

  @override
  ConsumerState<ModelConfigDialog> createState() => _ModelConfigDialogState();
}

class _ModelConfigDialogState extends ConsumerState<ModelConfigDialog> {
  late Map<String, TextEditingController> _controllers;
  int _currentIndex = 0;
  bool _toastVisible = false;
  String _toastMessage = '';
  IconData? _toastIcon;
  Timer? _toastTimer;
  bool _isInitialized = false;
  String? _lastActivePresetId;



  void _showToast(String message, IconData icon) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIcon = icon;
      _toastVisible = true;
    });
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  Widget _buildToastWidget() {
    final theme = FluentTheme.of(context);
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_toastVisible,
        child: Center(
          child: AnimatedOpacity(
            opacity: _toastVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.menuColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_toastIcon != null) ...[
                    Icon(_toastIcon,
                        size: 18, color: theme.accentColor),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    _toastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.typography.body?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _controllers = {
      'outline': TextEditingController(),
      'decompose': TextEditingController(),
      'writer': TextEditingController(),
      'reviewer': TextEditingController(),
    };
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final novelNotifier = ref.read(novelProvider.notifier);
    final novelState = ref.watch(novelProvider);
    final settingsState = ref.watch(settingsProvider);

    // Flatten models into a list for ComboBox
    final allModels = <NovelModelConfig>[];
    for (final provider in settingsState.providers) {
      if (provider.isEnabled && provider.models.isNotEmpty) {
        for (final model in provider.models) {
          if (provider.isModelEnabled(model)) {
            allModels.add(NovelModelConfig(providerId: provider.id, modelId: model));
          }
        }
      }
    }

    // Initialize controllers with current state (only on first build)
    if (!_isInitialized) {
      _controllers['outline']!.text = novelState.outlineModel?.systemPrompt ?? '';
      _controllers['decompose']!.text = novelState.decomposeModel?.systemPrompt ?? '';
      _controllers['writer']!.text = novelState.writerModel?.systemPrompt ?? '';
      _controllers['reviewer']!.text = novelState.reviewerModel?.systemPrompt ?? '';
      _isInitialized = true;
      _lastActivePresetId = novelState.activePromptPresetId;
    } else if (_lastActivePresetId != novelState.activePromptPresetId) {
      // 检查是否发生了预设切换
      _controllers['outline']!.text = novelState.outlineModel?.systemPrompt ?? '';
      _controllers['decompose']!.text = novelState.decomposeModel?.systemPrompt ?? '';
      _controllers['writer']!.text = novelState.writerModel?.systemPrompt ?? '';
      _controllers['reviewer']!.text = novelState.reviewerModel?.systemPrompt ?? '';
      _lastActivePresetId = novelState.activePromptPresetId;
    }

    Widget buildConfigInterface(
      String key,
      String presetPrompt,
      NovelModelConfig? currentConfig,
      void Function(NovelModelConfig?) onModelChanged,
      void Function(String) onPromptChanged,
    ) {
      final selectedBase = currentConfig != null
          ? allModels.firstWhere(
              (m) => m.providerId == currentConfig.providerId && m.modelId == currentConfig.modelId,
              orElse: () => NovelModelConfig(providerId: currentConfig.providerId, modelId: currentConfig.modelId))
          : null;

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: '选择模型',
              child: ComboBox<NovelModelConfig>(
                placeholder: Text(l10n.selectModel),
                items: allModels.map((item) {
                  final providerName = settingsState.providers
                      .firstWhere((p) => p.id == item.providerId, orElse: () => ProviderConfig(id: item.providerId, name: 'Unknown'))
                      .name;
                  return ComboBoxItem<NovelModelConfig>(
                    value: item,
                    child: Text('$providerName - ${item.modelId}', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                value: allModels.contains(selectedBase) ? selectedBase : null,
                onChanged: (val) {
                  if (val != null) {
                    final currentText = _controllers[key]!.text;
                    final newConfig = val.copyWith(systemPrompt: currentText);
                    onModelChanged(newConfig);
                  } else {
                    onModelChanged(null);
                  }
                },
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('系统提示词 (System Prompt)', style: theme.typography.bodyStrong),
                const Spacer(),
                Tooltip(
                  message: '将提示词恢复为系统默认预设',
                  child: IconButton(
                    icon: const Icon(FluentIcons.reset, size: 14),
                    onPressed: () {
                      _controllers[key]!.text = presetPrompt;
                      onPromptChanged(presetPrompt);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextBox(
                controller: _controllers[key],
                maxLines: null,
                keyboardType: TextInputType.multiline,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                placeholder: '在此输入自定义 Prompt...',
                onChanged: onPromptChanged,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
      title: Row(
        children: [
          Text(l10n.modelConfig, style: theme.typography.title),
          const Spacer(),
          // 全局预设管理工具栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.resources.dividerStrokeColorDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.bookmarks, size: 14),
                const SizedBox(width: 8),
                Text('${l10n.novelPreset}:', style: theme.typography.caption),
                const SizedBox(width: 8),
                DropDownButton(
                  title: Text(l10n.selectPreset),
                  items: [
                    MenuFlyoutItem(
                      text: Text(l10n.systemDefault, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        _controllers['outline']!.text = NovelPromptPresets.outline;
                        novelNotifier.setOutlinePrompt(NovelPromptPresets.outline);
                        _controllers['decompose']!.text = NovelPromptPresets.decompose;
                        novelNotifier.setDecomposePrompt(NovelPromptPresets.decompose);
                        _controllers['writer']!.text = NovelPromptPresets.writer;
                        novelNotifier.setWriterPrompt(NovelPromptPresets.writer);
                        _controllers['reviewer']!.text = NovelPromptPresets.reviewer;
                        novelNotifier.setReviewerPrompt(NovelPromptPresets.reviewer);
                        novelNotifier.setActivePromptPresetId(null);
                        
                        _showToast(l10n.systemDefaultRestored, FluentIcons.reset);
                      },
                    ),
                    const MenuFlyoutSeparator(),
                    if (novelState.promptPresets.isEmpty)
                      MenuFlyoutItem(
                        text: Text(l10n.noCustomPresets, style: const TextStyle(fontStyle: FontStyle.italic)),
                        onPressed: () {},
                      )
                    else
                      ...novelState.promptPresets.map((preset) => MenuFlyoutItem(
                        text: Text(preset.name),
                        onPressed: () {
                          // 应用整套预设
                          if (preset.outlinePrompt.isNotEmpty) {
                            _controllers['outline']!.text = preset.outlinePrompt;
                            novelNotifier.setOutlinePrompt(preset.outlinePrompt);
                          }
                          if (preset.decomposePrompt.isNotEmpty) {
                            _controllers['decompose']!.text = preset.decomposePrompt;
                            novelNotifier.setDecomposePrompt(preset.decomposePrompt);
                          }
                          if (preset.writerPrompt.isNotEmpty) {
                            _controllers['writer']!.text = preset.writerPrompt;
                            novelNotifier.setWriterPrompt(preset.writerPrompt);
                          }
                          if (preset.reviewerPrompt.isNotEmpty) {
                            _controllers['reviewer']!.text = preset.reviewerPrompt;
                            novelNotifier.setReviewerPrompt(preset.reviewerPrompt);
                          }
                          novelNotifier.setActivePromptPresetId(preset.id);
                          _showToast(l10n.presetLoaded(preset.name), FluentIcons.check_mark);
                        },
                        trailing: IconButton(
                          icon: const Icon(FluentIcons.delete, size: 10),
                          onPressed: () {
                             novelNotifier.deletePromptPreset(preset.id);
                          },
                        ),
                      )),
                  ],
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: theme.resources.dividerStrokeColorDefault),
                const SizedBox(width: 8),
                Button(
                  onPressed: () => _showSavePresetDialog(context, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.add, size: 12),
                      const SizedBox(width: 4),
                      Text(l10n.newNovelPreset),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: novelState.activePromptPresetId != null 
                    ? '${l10n.save} "${novelState.promptPresets.firstWhere((p) => p.id == novelState.activePromptPresetId).name}"'
                    : l10n.savePresetOverrideHint,
                  child: IconButton(
                    icon: Icon(
                      FluentIcons.save, 
                      size: 14, 
                      color: novelState.activePromptPresetId != null ? theme.accentColor : null
                    ),
                    onPressed: novelState.activePromptPresetId == null ? null : () {
                      final activeId = novelState.activePromptPresetId!;
                      final currentPreset = novelState.promptPresets.firstWhere((p) => p.id == activeId);
                      final updatedPreset = currentPreset.copyWith(
                        outlinePrompt: _controllers['outline']?.text ?? '',
                        decomposePrompt: _controllers['decompose']?.text ?? '',
                        writerPrompt: _controllers['writer']?.text ?? '',
                        reviewerPrompt: _controllers['reviewer']?.text ?? '',
                      );
                      novelNotifier.updatePromptPreset(updatedPreset);
                      _showToast(l10n.presetSaved(updatedPreset.name), FluentIcons.save);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Stack(
        children: [
          Container(
            width: 900,
            height: 600,
            decoration: BoxDecoration(
              border: Border.all(color: theme.resources.dividerStrokeColorDefault),
              borderRadius: BorderRadius.circular(8),
              color: theme.scaffoldBackgroundColor,
            ),
            clipBehavior: Clip.antiAlias,
            child: TabView(
              currentIndex: _currentIndex,
              onChanged: (index) => setState(() => _currentIndex = index),
              closeButtonVisibility: CloseButtonVisibilityMode.never,
              tabs: [
                Tab(
                  text: Text(l10n.outline),
                  icon: const Icon(FluentIcons.text_document),
                  body: buildConfigInterface(
                    'outline',
                    NovelPromptPresets.outline,
                    novelState.outlineModel,
                    novelNotifier.setOutlineModel,
                    novelNotifier.setOutlinePrompt,
                  ),
                ),
                Tab(
                  text: Text(l10n.decompose),
                  icon: const Icon(FluentIcons.org),
                  body: buildConfigInterface(
                    'decompose',
                    NovelPromptPresets.decompose,
                    novelState.decomposeModel,
                    novelNotifier.setDecomposeModel,
                    novelNotifier.setDecomposePrompt,
                  ),
                ),
                Tab(
                  text: Text(l10n.writing),
                  icon: const Icon(FluentIcons.edit),
                  body: buildConfigInterface(
                    'writer',
                    NovelPromptPresets.writer,
                    novelState.writerModel,
                    novelNotifier.setWriterModel,
                    novelNotifier.setWriterPrompt,
                  ),
                ),
                Tab(
                  text: Text(l10n.reviewModel),
                  icon: const Icon(FluentIcons.preview_link),
                  body: buildConfigInterface(
                    'reviewer',
                    NovelPromptPresets.reviewer,
                    novelState.reviewerModel,
                    novelNotifier.setReviewerModel,
                    novelNotifier.setReviewerPrompt,
                  ),
                ),
              ],
            ),
          ),
          _buildToastWidget(),
        ],
      ),
      actions: [
        Button(
          child: Text(l10n.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }


  void _showSavePresetDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 400),
        title: Text(l10n.newNovelPreset),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: l10n.presetName,
              child: TextBox(
                controller: nameController,
                autofocus: true,
                placeholder: '${l10n.pleaseEnter}${l10n.presetName}...',
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.savePresetHint, style: FluentTheme.of(context).typography.caption),
          ],
        ),
        actions: [
          Button(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          FilledButton(
            child: Text(l10n.save),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final preset = NovelPromptPreset.create(
                  name: name,
                  outlinePrompt: _controllers['outline']?.text ?? '',
                  decomposePrompt: _controllers['decompose']?.text ?? '',
                  writerPrompt: _controllers['writer']?.text ?? '',
                  reviewerPrompt: _controllers['reviewer']?.text ?? '',
                );
                ref.read(novelProvider.notifier).addPromptPreset(preset);
                Navigator.pop(ctx);
                _showToast(l10n.presetSaved(name), FluentIcons.save);
              }
            },
          ),
        ],
      ),
    );
  }
}
