import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aurora/l10n/app_localizations.dart';
import 'settings_provider.dart';
import 'usage_stats_view.dart';
import 'preset_settings_page.dart';
import '../../../shared/utils/avatar_cropper.dart';
import 'model_config_dialog.dart';


class SettingsContent extends ConsumerStatefulWidget {
  const SettingsContent({super.key});
  @override
  ConsumerState<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<SettingsContent> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _llmNameController = TextEditingController();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _userNameController.dispose();
    _llmNameController.dispose();
    super.dispose();
  }

  void _updateControllers(ProviderConfig provider) {
    if (_apiKeyController.text != provider.apiKey) {
      _apiKeyController.text = provider.apiKey;
    }
    if (_baseUrlController.text != provider.baseUrl) {
      _baseUrlController.text = provider.baseUrl;
    }
    if (_nameController.text != provider.name) {
      _nameController.text = provider.name;
    }
    if (_colorController.text != (provider.color ?? '')) {
      _colorController.text = provider.color ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = ref.read(settingsProvider);
    if (_userNameController.text.isEmpty && settings.userName.isNotEmpty) {
      _userNameController.text = settings.userName;
    }
    if (_llmNameController.text.isEmpty && settings.llmName.isNotEmpty) {
      _llmNameController.text = settings.llmName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final viewingProvider = settingsState.viewingProvider;
    _updateControllers(viewingProvider);
    final settingsPageIndex = ref.watch(settingsPageIndexProvider);
    if (Platform.isWindows) {
      final theme = fluent.FluentTheme.of(context);
      final l10n = AppLocalizations.of(context)!;
      final settingsPages = [
        (icon: fluent.FluentIcons.cloud_download, label: l10n.modelProvider),
        (icon: fluent.FluentIcons.chat, label: l10n.chatSettings),
        (icon: fluent.FluentIcons.edit, label: l10n.promptPresets),
        (icon: fluent.FluentIcons.color, label: l10n.displaySettings),
        (icon: fluent.FluentIcons.database, label: l10n.dataSettings),
        (icon: fluent.FluentIcons.analytics_view, label: l10n.usageStats),
      ];
      return Container(
        color: Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    ...settingsPages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final page = entry.value;
                      final isSelected = settingsPageIndex == index;
                      return fluent.HoverButton(
                        onPressed: () => ref
                            .read(settingsPageIndexProvider.notifier)
                            .state = index,
                        builder: (context, states) {
                          return Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.accentColor.withOpacity(0.1)
                                  : states.isHovering
                                      ? theme.resources.subtleFillColorSecondary
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                fluent.Icon(page.icon,
                                    size: 16,
                                    color:
                                        isSelected ? theme.accentColor : null),
                                const SizedBox(width: 12),
                                Text(
                                  page.label,
                                  style: TextStyle(
                                    color:
                                        isSelected ? theme.accentColor : null,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: IndexedStack(
                    index: settingsPageIndex,
                    children: [
                      _buildProviderSettings(settingsState, viewingProvider),
                      _buildChatSettings(settingsState),
                      const PresetSettingsPage(),
                      _buildDisplaySettings(),
                      _buildDataSettings(),
                      const UsageStatsView(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('移动端设置',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('请使用顶部导航栏的设置按钮访问完整设置页面',
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStyledTextBox({
    required TextEditingController controller,
    String? placeholder,
    ValueChanged<String>? onChanged,
  }) {
    final theme = fluent.FluentTheme.of(context);
    return fluent.TextBox(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: WidgetStateProperty.all(BoxDecoration(
        color: theme.brightness.isDark
            ? const Color(0xFF3C3C3C)
            : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault ??
              Colors.grey.withOpacity(0.3),
        ),
      )),
      highlightColor: Colors.transparent,
      unfocusedColor: Colors.transparent,
      cursorColor: theme.accentColor,
    );
  }

  Widget _buildStyledPasswordBox({
    required TextEditingController controller,
    String? placeholder,
    ValueChanged<String>? onChanged,
  }) {
    final theme = fluent.FluentTheme.of(context);
    return fluent.PasswordBox(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      revealMode: fluent.PasswordRevealMode.peek,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: WidgetStateProperty.all(BoxDecoration(
        color: theme.brightness.isDark
            ? const Color(0xFF3C3C3C)
            : const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.controlStrokeColorDefault ??
              Colors.grey.withOpacity(0.3),
        ),
      )),
      highlightColor: Colors.transparent,
      unfocusedColor: Colors.transparent,
      cursorColor: theme.accentColor,
    );
  }

  Widget _buildProviderSettings(
      SettingsState settingsState, ProviderConfig viewingProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 140,
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(
                    color: fluent.FluentTheme.of(context)
                        .resources
                        .dividerStrokeColorDefault)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(l10n.providers,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Expanded(
                child: fluent.ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: settingsState.providers.length,
                  itemBuilder: (context, index) {
                    final provider = settingsState.providers[index];
                    final isSelected =
                        provider.id == settingsState.viewingProviderId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? fluent.FluentTheme.of(context)
                                .accentColor
                                .withOpacity(0.1)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: fluent.ListTile(
                        title: Text(
                          provider.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? fluent.FluentTheme.of(context).accentColor
                                : null,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(settingsProvider.notifier)
                              .viewProvider(provider.id);
                        },
                        trailing: fluent.IconButton(
                          icon: Icon(fluent.FluentIcons.delete,
                              size: 12,
                              color: fluent.FluentTheme.of(context)
                                  .resources
                                  .textFillColorSecondary),
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return fluent.ContentDialog(
                                    title: Text(l10n.deleteProvider),
                                    content: Text(l10n.deleteProviderConfirm),
                                    actions: [
                                      fluent.Button(
                                        child: Text(l10n.cancel),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      fluent.FilledButton(
                                        child: Text(l10n.delete),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          ref
                                              .read(settingsProvider.notifier)
                                              .deleteProvider(provider.id);
                                        },
                                      ),
                                    ],
                                  );
                                });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: fluent.Button(
                    onPressed: () =>
                        ref.read(settingsProvider.notifier).addProvider(),
                    child: fluent.Text(l10n.addProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
        const fluent.Divider(direction: Axis.vertical),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fluent.InfoLabel(
                      label: l10n.providerName,
                      child: _buildStyledTextBox(
                        controller: _nameController,
                        placeholder: 'My Provider',
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).updateProvider(
                              id: viewingProvider.id, name: value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    fluent.InfoLabel(
                      label: 'Color (Hex)',
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (viewingProvider.color != null &&
                                      viewingProvider.color!.isNotEmpty)
                                  ? Color(int.tryParse(viewingProvider.color!
                                          .replaceFirst('#', '0xFF')) ??
                                      0xFF000000)
                                  : Colors.transparent,
                              border: Border.all(color: fluent.Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStyledTextBox(
                              controller: _colorController,
                              placeholder: '#FF0000',
                              onChanged: (value) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateProvider(
                                        id: viewingProvider.id, color: value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    fluent.InfoLabel(
                      label: 'API Key',
                      child: _buildStyledPasswordBox(
                        controller: _apiKeyController,
                        placeholder: 'sk-xxxxxxxx',
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).updateProvider(
                              id: viewingProvider.id, apiKey: value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    fluent.InfoLabel(
                      label: 'API Base URL',
                      child: _buildStyledTextBox(
                        controller: _baseUrlController,
                        placeholder: 'https://api.openai.com/v1',
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).updateProvider(
                              id: viewingProvider.id, baseUrl: value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    fluent.InfoLabel(
                      label: l10n.enabledStatus,
                      child: Row(
                        children: [
                          fluent.ToggleSwitch(
                            checked: viewingProvider.isEnabled,
                            onChanged: (v) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .toggleProviderEnabled(viewingProvider.id);
                            },
                            content: fluent.Text(viewingProvider.isEnabled
                                ? l10n.enabled
                                : l10n.disabled),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        fluent.Text(l10n.availableModels,
                            overflow: TextOverflow.ellipsis,
                            style: fluent.FluentTheme.of(context)
                                .typography
                                .subtitle),
                        const SizedBox(width: 16),
                        fluent.Button(
                          style: fluent.ButtonStyle(
                            padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6)),
                            backgroundColor: WidgetStateProperty.all(
                                fluent.FluentTheme.of(context)
                                    .accentColor
                                    .withOpacity(0.1)),
                            shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide.none)),
                          ),
                          onPressed: settingsState.isLoadingModels
                              ? null
                              : () => ref
                                  .read(settingsProvider.notifier)
                                  .fetchModels(),
                          child: settingsState.isLoadingModels
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: fluent.ProgressRing())
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(fluent.FluentIcons.refresh,
                                        size: 14,
                                        color: fluent.FluentTheme.of(context)
                                            .accentColor),
                                    const SizedBox(width: 8),
                                    fluent.Text(
                                      l10n.refreshList,
                                      style: TextStyle(
                                        color: fluent.FluentTheme.of(context)
                                            .accentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                    if (settingsState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: fluent.Text(settingsState.error!,
                            style: TextStyle(color: fluent.Colors.red)),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Expanded(
                child: viewingProvider.models.isNotEmpty
                    ? fluent.ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: viewingProvider.models.length,
                        itemBuilder: (context, index) {
                          final model = viewingProvider.models[index];
                          final isSelected =
                              model == viewingProvider.selectedModel;
                          final theme = fluent.FluentTheme.of(context);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: fluent.HoverButton(
                              onPressed: () {},
                              builder: (context, states) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: states.isHovering
                                        ? theme.typography.body?.color
                                                ?.withOpacity(0.05) ??
                                            Colors.transparent
                                        : Colors.transparent,
                                  ),
                                  width: double.infinity,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Icon(fluent.FluentIcons.org,
                                          size: 16,
                                          color: theme.typography.body?.color
                                              ?.withOpacity(0.7)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(model,
                                              overflow: TextOverflow.ellipsis)),
                                      fluent.IconButton(
                                        icon: const fluent.Icon(
                                            fluent.FluentIcons.settings,
                                            size: 14),
                                        onPressed: () => _openModelSettings(
                                            viewingProvider, model),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      )
                    : Container(
                        margin: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: fluent.Colors.grey.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: fluent.Text(l10n.noModelsData),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatSettings(SettingsState settingsState) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fluent.Text(l10n.chatSettings,
              style: fluent.FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 24),
          fluent.InfoLabel(
            label: l10n.smartTopicGeneration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                fluent.ToggleSwitch(
                  checked: settingsState.enableSmartTopic,
                  onChanged: (v) {
                    ref
                        .read(settingsProvider.notifier)
                        .toggleSmartTopicEnabled(v);
                  },
                  content: fluent.Text(settingsState.enableSmartTopic
                      ? l10n.enabled
                      : l10n.disabled),
                ),
                if (settingsState.enableSmartTopic) ...[
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final items = <fluent.MenuFlyoutItemBase>[];
                    for (final provider in settingsState.providers) {
                      if (provider.isEnabled) {
                        for (final model in provider.models) {
                          final value = '${provider.id}@$model';
                          final isSelected =
                              settingsState.topicGenerationModel == value;
                          items.add(fluent.MenuFlyoutItem(
                            leading: isSelected
                                ? const Icon(fluent.FluentIcons.check_mark,
                                    size: 12)
                                : null,
                            text: Text('${provider.name} - $model'),
                            onPressed: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .setTopicGenerationModel(value);
                            },
                          ));
                        }
                      }
                    }

                    if (items.isEmpty) {
                      return fluent.Button(
                        onPressed: null,
                        child: Text(l10n.noModelsData),
                      );
                    }

                    return fluent.DropDownButton(
                      title: Text(() {
                        if (settingsState.topicGenerationModel == null) {
                          return l10n.selectTopicModel;
                        }
                        final parts =
                            settingsState.topicGenerationModel!.split('@');
                        if (parts.length == 2) {
                          final provider = settingsState.providers.firstWhere(
                              (p) => p.id == parts[0],
                              orElse: () => settingsState.providers.first);
                          return '${provider.name} - ${parts[1]}';
                        }
                        return settingsState.topicGenerationModel!;
                      }()),
                      items: items,
                    );
                  }),
                  if (settingsState.topicGenerationModel == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        l10n.noModelFallback,
                        style: TextStyle(
                            color: fluent.Colors.orange, fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const fluent.Divider(),
          const SizedBox(height: 24),
          fluent.InfoLabel(
            label: l10n.userName,
            child: _buildStyledTextBox(
              placeholder: 'User',
              controller: _userNameController,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setChatDisplaySettings(userName: value);
              },
            ),
          ),
          const SizedBox(height: 16),
          fluent.InfoLabel(
            label: l10n.userAvatar,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: fluent.Colors.grey.withOpacity(0.3)),
                  ),
                  child: settingsState.userAvatar != null &&
                          settingsState.userAvatar!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(settingsState.userAvatar!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                fluent.FluentIcons.contact,
                                size: 24),
                          ),
                        )
                      : const Icon(fluent.FluentIcons.contact, size: 24),
                ),
                const SizedBox(width: 12),
                fluent.Button(
                  child: Text(l10n.selectImage),
                  onPressed: () async {
                    final result = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                            label: 'Images',
                            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp']),
                      ],
                    );
                    if (result != null) {
                      final croppedPath =
                          await AvatarCropper.cropImage(context, result.path);
                      if (croppedPath != null) {
                        final appDir = await getApplicationDocumentsDirectory();
                        final avatarDir = Directory('${appDir.path}${Platform.pathSeparator}avatars');
                        if (!await avatarDir.exists()) {
                          await avatarDir.create(recursive: true);
                        }
                        final fileName = 'avatar_user_${DateTime.now().millisecondsSinceEpoch}.png';
                        final persistentPath = '${avatarDir.path}${Platform.pathSeparator}$fileName';
                        await File(croppedPath).copy(persistentPath);
                        ref
                            .read(settingsProvider.notifier)
                            .setChatDisplaySettings(userAvatar: persistentPath);
                      }
                    }
                  },
                ),
                if (settingsState.userAvatar != null) ...[
                  const SizedBox(width: 8),
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.delete),
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setChatDisplaySettings(userAvatar: '');
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          fluent.InfoLabel(
            label: l10n.aiName,
            child: _buildStyledTextBox(
              placeholder: 'Assistant',
              controller: _llmNameController,
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .setChatDisplaySettings(llmName: value);
              },
            ),
          ),
          const SizedBox(height: 16),
          fluent.InfoLabel(
            label: l10n.aiAvatar,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: fluent.Colors.grey.withOpacity(0.3)),
                  ),
                  child: settingsState.llmAvatar != null &&
                          settingsState.llmAvatar!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(settingsState.llmAvatar!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(fluent.FluentIcons.robot, size: 24),
                          ),
                        )
                      : const Icon(fluent.FluentIcons.robot, size: 24),
                ),
                const SizedBox(width: 12),
                fluent.Button(
                  child: const Text('选择图片'),
                  onPressed: () async {
                    final result = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                            label: 'Images',
                            extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp']),
                      ],
                    );
                    if (result != null) {
                      final croppedPath =
                          await AvatarCropper.cropImage(context, result.path);
                      if (croppedPath != null) {
                        final appDir = await getApplicationDocumentsDirectory();
                        final avatarDir = Directory('${appDir.path}${Platform.pathSeparator}avatars');
                        if (!await avatarDir.exists()) {
                          await avatarDir.create(recursive: true);
                        }
                        final fileName = 'avatar_llm_${DateTime.now().millisecondsSinceEpoch}.png';
                        final persistentPath = '${avatarDir.path}${Platform.pathSeparator}$fileName';
                        await File(croppedPath).copy(persistentPath);
                        ref
                            .read(settingsProvider.notifier)
                            .setChatDisplaySettings(llmAvatar: persistentPath);
                      }
                    }
                  },
                ),
                if (settingsState.llmAvatar != null) ...[
                  const SizedBox(width: 8),
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.delete),
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setChatDisplaySettings(llmAvatar: '');
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplaySettings() {
    final l10n = AppLocalizations.of(context)!;
    final settingsState = ref.watch(settingsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fluent.Text(l10n.displaySettings,
              style: fluent.FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 24),
          fluent.InfoLabel(
            label: l10n.language,
            child: fluent.ComboBox<String>(
              value: settingsState.language,
              items: [
                fluent.ComboBoxItem(
                  value: 'zh',
                  child: Text(l10n.languageChinese),
                ),
                fluent.ComboBoxItem(
                  value: 'en',
                  child: Text(l10n.languageEnglish),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).setLanguage(value);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: fluent.Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
                child: Text(l10n.themeAndUiComingSoon,
                    style: const TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSettings() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fluent.Text(l10n.dataSettings,
              style: fluent.FluentTheme.of(context).typography.subtitle),
          const SizedBox(height: 24),
          fluent.Button(
            onPressed: null,
            child: Text(l10n.exportData),
          ),
          const SizedBox(height: 8),
          fluent.Button(
            onPressed: null,
            child: Text(l10n.importData),
          ),
          const SizedBox(height: 8),
          fluent.Button(
            onPressed: null,
            child: Text(l10n.clearAllData),
          ),
        ],
      ),
    );
  }

  void _openModelSettings(ProviderConfig provider, String modelName) async {
    showDialog(
        context: context,
        builder: (context) {
          return ModelConfigDialog(
            provider: provider,
            modelName: modelName,
          );
        });
  }
}



