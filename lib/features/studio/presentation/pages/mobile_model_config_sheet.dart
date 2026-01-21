import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurora/features/settings/presentation/settings_provider.dart';
import 'package:aurora/l10n/app_localizations.dart';
import '../novel/novel_provider.dart';
import '../novel/novel_state.dart';

class MobileModelConfigSheet extends ConsumerStatefulWidget {
  const MobileModelConfigSheet({super.key});

  @override
  ConsumerState<MobileModelConfigSheet> createState() => _MobileModelConfigSheetState();
}

class _MobileModelConfigSheetState extends ConsumerState<MobileModelConfigSheet> {
  late Map<String, TextEditingController> _controllers;
  bool _isInitialized = false;

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
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final novelNotifier = ref.read(novelProvider.notifier);
    final novelState = ref.watch(novelProvider);
    final settingsState = ref.watch(settingsProvider);

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

    if (!_isInitialized) {
      _controllers['outline']!.text = novelState.outlineModel?.systemPrompt ?? '';
      _controllers['decompose']!.text = novelState.decomposeModel?.systemPrompt ?? '';
      _controllers['writer']!.text = novelState.writerModel?.systemPrompt ?? '';
      _controllers['reviewer']!.text = novelState.reviewerModel?.systemPrompt ?? '';
      _isInitialized = true;
    }

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            title: Text(l10n.modelConfig),
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              children: [
                _buildModelSection(
                  context,
                  'outline',
                  '大纲模型 (Outline Model)',
                  NovelPromptPresets.outline,
                  novelState.outlineModel,
                  allModels,
                  settingsState,
                  novelNotifier.setOutlineModel,
                  novelNotifier.setOutlinePrompt,
                ),
                _buildModelSection(
                  context,
                  'decompose',
                  '拆解模型 (Decomposition Model)',
                  NovelPromptPresets.decompose,
                  novelState.decomposeModel,
                  allModels,
                  settingsState,
                  novelNotifier.setDecomposeModel,
                  novelNotifier.setDecomposePrompt,
                ),
                _buildModelSection(
                  context,
                  'writer',
                  '写作模型 (Writer Model)',
                  NovelPromptPresets.writer,
                  novelState.writerModel,
                  allModels,
                  settingsState,
                  novelNotifier.setWriterModel,
                  novelNotifier.setWriterPrompt,
                ),
                _buildModelSection(
                  context,
                  'reviewer',
                  '审查模型 (Reviewer Model)',
                  NovelPromptPresets.reviewer,
                  novelState.reviewerModel,
                  allModels,
                  settingsState,
                  novelNotifier.setReviewerModel,
                  novelNotifier.setReviewerPrompt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSection(
    BuildContext context,
    String key,
    String label,
    String presetPrompt,
    NovelModelConfig? currentConfig,
    List<NovelModelConfig> allModels,
    SettingsState settingsState,
    void Function(NovelModelConfig?) onModelChanged,
    void Function(String) onPromptChanged,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    final selectedBase = currentConfig != null 
        ? allModels.firstWhere(
            (m) => m.providerId == currentConfig.providerId && m.modelId == currentConfig.modelId, 
            orElse: () => NovelModelConfig(providerId: currentConfig.providerId, modelId: currentConfig.modelId))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<NovelModelConfig>(
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          hint: Text(l10n.selectModel),
          value: allModels.contains(selectedBase) ? selectedBase : null,
          items: allModels.map((item) {
            final providerName = settingsState.providers
                .firstWhere((p) => p.id == item.providerId, orElse: () => ProviderConfig(id: item.providerId, name: 'Unknown'))
                .name;
            return DropdownMenuItem<NovelModelConfig>(
              value: item,
              child: Text('$providerName - ${item.modelId}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              final currentText = _controllers[key]!.text;
              final newConfig = val.copyWith(systemPrompt: currentText);
              onModelChanged(newConfig);
            } else {
              onModelChanged(null);
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('System Prompt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {
                _controllers[key]!.text = presetPrompt;
                onPromptChanged(presetPrompt);
              },
              child: const Text('使用预设', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        TextField(
          controller: _controllers[key],
          maxLines: null,
          minLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '输入该模型的系统提示词...',
          ),
          onChanged: onPromptChanged,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
