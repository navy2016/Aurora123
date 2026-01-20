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
    }

    Widget buildModelSelector(
      String key,
      String label, 
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

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.resources.dividerStrokeColorDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.typography.subtitle),
            const SizedBox(height: 12),
            
            // Model Selector
            Row(
              children: [
                Expanded(
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
              ],
            ),
            const SizedBox(height: 16),
            
            // System Prompt Label with Reset Button
            Row(
              children: [
                Text('System Prompt', style: theme.typography.bodyStrong),
                const Spacer(),
                HyperlinkButton(
                  onPressed: () {
                    _controllers[key]!.text = presetPrompt;
                    onPromptChanged(presetPrompt);
                  },
                  child: const Text('使用预设'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Prompt TextBox
            TextBox(
              controller: _controllers[key],
              maxLines: null,
              minLines: 4,
              placeholder: '输入该模型的系统提示词...',
              onChanged: onPromptChanged,
            ),
            
            // Show preset hint
            const SizedBox(height: 8),
            Expander(
              header: Text('查看预设提示词', style: theme.typography.caption),
              content: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.menuColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  presetPrompt,
                  style: theme.typography.caption?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ContentDialog(
      title: Text(l10n.modelConfig, style: theme.typography.title),
      content: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 700),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildModelSelector(
                'outline',
                '大纲模型 (Outline Model)',
                NovelPromptPresets.outline,
                novelState.outlineModel, 
                novelNotifier.setOutlineModel,
                novelNotifier.setOutlinePrompt,
              ),
              buildModelSelector(
                'decompose',
                '拆解模型 (Decomposition Model)', 
                NovelPromptPresets.decompose,
                novelState.decomposeModel, 
                novelNotifier.setDecomposeModel,
                novelNotifier.setDecomposePrompt,
              ),
              buildModelSelector(
                'writer',
                '写作模型 (Writer Model)', 
                NovelPromptPresets.writer,
                novelState.writerModel, 
                novelNotifier.setWriterModel,
                novelNotifier.setWriterPrompt,
              ),
              buildModelSelector(
                'reviewer',
                '审查模型 (Reviewer Model)', 
                NovelPromptPresets.reviewer,
                novelState.reviewerModel, 
                novelNotifier.setReviewerModel,
                novelNotifier.setReviewerPrompt,
              ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          child: Text(l10n.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  bool _isInitialized = false;
}
