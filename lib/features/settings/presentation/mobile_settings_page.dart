import 'dart:io';
import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'settings_provider.dart';
import 'package:aurora/l10n/app_localizations.dart';

class MobileSettingsPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const MobileSettingsPage({super.key, this.onBack});
  @override
  ConsumerState<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends ConsumerState<MobileSettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _userNameController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final activeProvider = settingsState.activeProvider;
    final fluentTheme = fluent.FluentTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: fluentTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: fluentTheme.scaffoldBackgroundColor,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SectionHeader(
                    title: l10n.modelProvider, icon: Icons.cloud_outlined),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(l10n.currentProvider),
                  subtitle: Text(activeProvider?.name ?? l10n.notConfigured),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showProviderPicker(context, settingsState),
                ),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Color'),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (activeProvider?.color != null &&
                          activeProvider!.color!.isNotEmpty)
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(int.tryParse(activeProvider.color!
                                    .replaceFirst('#', '0xFF')) ??
                                0xFF000000),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      Text(activeProvider?.color ?? l10n.notConfigured),
                    ],
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showColorEditor(context, activeProvider),
                ),
                ListTile(
                  leading: const Icon(Icons.key),
                  title: const Text('API Key'),
                  subtitle: Text(activeProvider?.apiKey.isNotEmpty == true
                      ? '••••••••'
                      : l10n.notConfigured),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showApiKeyEditor(context, activeProvider),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('API Base URL'),
                  subtitle: Text(
                      activeProvider?.baseUrl ?? 'https://api.openai.com/v1'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _showBaseUrlEditor(context, activeProvider),
                ),
                ListTile(
                  leading: const Icon(Icons.power_settings_new),
                  title: Text(l10n.enabledStatus),
                  subtitle: Text(activeProvider?.isEnabled == true
                      ? l10n.enabled
                      : l10n.disabled),
                  trailing: Switch(
                    value: activeProvider?.isEnabled == true,
                    onChanged: (v) {
                      if (activeProvider != null) {
                        ref
                            .read(settingsProvider.notifier)
                            .toggleProviderEnabled(activeProvider.id);
                      }
                    },
                  ),
                  onTap: () {
                    if (activeProvider != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .toggleProviderEnabled(activeProvider.id);
                    }
                  },
                ),
                _SectionHeader(
                  title: l10n.availableModels,
                  icon: Icons.format_list_bulleted,
                  trailing: SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: settingsState.isLoadingModels
                          ? null
                          : () {
                              ref.read(settingsProvider.notifier).fetchModels();
                            },
                      child: settingsState.isLoadingModels
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.fetchModelList),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (activeProvider != null && activeProvider.models.isNotEmpty)
            SliverList.builder(
              itemCount: activeProvider.models.length,
              itemBuilder: (context, index) {
                final model = activeProvider.models[index];
                return ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(model),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            activeProvider.isModelEnabled(model)
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: activeProvider.isModelEnabled(model)
                                ? Colors.green
                                : Colors.red,
                          ),
                          onPressed: () => ref
                              .read(settingsProvider.notifier)
                              .toggleModelDisabled(activeProvider.id, model),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => _showModelConfigDialog(
                              context, activeProvider, model),
                        ),
                      ],
                    ),
                  );
                },
            )
          else if (activeProvider != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.noModelsFetch,
                    style: const TextStyle(color: Colors.grey)),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  void _showProviderPicker(BuildContext context, SettingsState paramState) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(context)!;
        return Consumer(
          builder: (scopedContext, ref, _) {
            final state = ref.watch(settingsProvider);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.selectProvider,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ...state.providers.map((p) => ListTile(
                        leading: Icon(
                          p.id == state.activeProviderId
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: p.id == state.activeProviderId
                              ? Theme.of(scopedContext).primaryColor
                              : null,
                        ),
                        title: Text(p.name),
                        subtitle: Text(p.selectedModel ?? l10n.noModelSelected),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () {
                                Navigator.pop(ctx);
                                showDialog(
                                    context: scopedContext,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(l10n.deleteProvider),
                                        content:
                                            Text(l10n.deleteProviderConfirm),
                                        actions: [
                                          TextButton(
                                            child: Text(l10n.cancel),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                          TextButton(
                                            child: Text(l10n.delete),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              ref
                                                  .read(
                                                      settingsProvider.notifier)
                                                  .deleteProvider(p.id);
                                            },
                                          ),
                                        ],
                                      );
                                    });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showProviderRenameDialog(scopedContext, p);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!p.isEnabled) {}
                          ref
                              .read(settingsProvider.notifier)
                              .selectProvider(p.id);
                          Navigator.pop(ctx);
                        },
                      )),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(l10n.addProvider),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(settingsProvider.notifier).addProvider();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showModelConfigDialog(
      BuildContext context, ProviderConfig provider, String modelName) {
    final currentSettings = provider.modelSettings[modelName] ?? {};
    showDialog(
      context: context,
      builder: (ctx) => _ModelConfigDialog(
        modelName: modelName,
        initialSettings: currentSettings,
        onSave: (newSettings) {
          final updatedModelSettings =
              Map<String, Map<String, dynamic>>.from(provider.modelSettings);
          updatedModelSettings[modelName] = newSettings;
          ref.read(settingsProvider.notifier).updateProvider(
                id: provider.id,
                modelSettings: updatedModelSettings,
              );
        },
      ),
    );
  }

  void _showProviderRenameDialog(
      BuildContext context, ProviderConfig provider) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: provider.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202020)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.renameProvider),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.enterProviderName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(settingsProvider.notifier).updateProvider(
                      id: provider.id,
                      name: controller.text.trim(),
                    );
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showApiKeyEditor(BuildContext context, ProviderConfig? provider) {
    if (provider == null) return;
    final l10n = AppLocalizations.of(context)!;
    _apiKeyController.text = provider.apiKey;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202020)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.editApiKey),
        content: TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'sk-xxxxxxxx',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).updateProvider(
                    id: provider.id,
                    apiKey: _apiKeyController.text,
                  );
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showBaseUrlEditor(BuildContext context, ProviderConfig? provider) {
    if (provider == null) return;
    final l10n = AppLocalizations.of(context)!;
    _baseUrlController.text = provider.baseUrl;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202020)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.editBaseUrl),
        content: TextField(
          controller: _baseUrlController,
          decoration: const InputDecoration(
            hintText: 'https://api.openai.com/v1',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).updateProvider(
                    id: provider.id,
                    baseUrl: _baseUrlController.text,
                  );
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showColorEditor(BuildContext context, ProviderConfig? provider) {
    if (provider == null) return;
    final l10n = AppLocalizations.of(context)!;
    _colorController.text = provider.color ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202020)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Edit Color'),
        content: TextField(
          controller: _colorController,
          decoration: const InputDecoration(
            hintText: '#FF0000',
            labelText: 'Hex Color',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // Force rebuild if needed
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).updateProvider(
                    id: provider.id,
                    color: _colorController.text,
                  );
              Navigator.pop(ctx);
            },
            child: Text(l10n.save),
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202020)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('编辑$title'),
        content: TextField(
          controller: controller,
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

  Future<void> _pickAvatar({required bool isUser}) async {
    final result = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
            label: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp']),
      ],
    );
    if (result != null) {
      if (isUser) {
        ref
            .read(settingsProvider.notifier)
            .setChatDisplaySettings(userAvatar: result.path);
      } else {
        ref
            .read(settingsProvider.notifier)
            .setChatDisplaySettings(llmAvatar: result.path);
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ModelConfigDialog extends StatefulWidget {
  final String modelName;
  final Map<String, dynamic> initialSettings;
  final Function(Map<String, dynamic>) onSave;
  const _ModelConfigDialog({
    super.key,
    required this.modelName,
    required this.initialSettings,
    required this.onSave,
  });
  @override
  State<_ModelConfigDialog> createState() => _ModelConfigDialogState();
}

class _ModelConfigDialogState extends State<_ModelConfigDialog> {
  late Map<String, dynamic> _modelSettings;
  
  // Thinking config temporary state
  bool _thinkingEnabled = false;
  String _thinkingBudget = '';
  String _thinkingMode = 'auto';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _modelSettings = Map<String, dynamic>.from(widget.initialSettings);

    final thinkingConfig = _modelSettings['_aurora_thinking_config'];
    // Check for new structure first
    if (thinkingConfig != null && thinkingConfig is Map) {
      _thinkingEnabled = thinkingConfig['enabled'] == true;
      _thinkingBudget = thinkingConfig['budget']?.toString() ?? '';
      _thinkingMode = thinkingConfig['mode']?.toString() ?? 'auto';
    } else {
      // Fallback/Migration for old structure if present
      // Old keys: _aurora_thinking_enabled, _aurora_thinking_value, _aurora_thinking_mode
      if (_modelSettings.containsKey('_aurora_thinking_enabled')) {
        _thinkingEnabled = _modelSettings['_aurora_thinking_enabled'] == true;
        _thinkingBudget = _modelSettings['_aurora_thinking_value']?.toString() ?? '';
        _thinkingMode = _modelSettings['_aurora_thinking_mode']?.toString() ?? 'auto';
        
        // Clean up old keys immediately from local copy so they don't persist
        _modelSettings.remove('_aurora_thinking_enabled');
        _modelSettings.remove('_aurora_thinking_value');
        _modelSettings.remove('_aurora_thinking_mode');
      } else {
        _thinkingEnabled = false;
        _thinkingBudget = '';
        _thinkingMode = 'auto';
      }
    }
  }

  void _saveSettings({
    bool? thinkingEnabled,
    String? thinkingBudget,
    String? thinkingMode,
    Map<String, dynamic>? customParams,
  }) {
    // Update local state
    if (thinkingEnabled != null) _thinkingEnabled = thinkingEnabled;
    if (thinkingBudget != null) _thinkingBudget = thinkingBudget;
    if (thinkingMode != null) _thinkingMode = thinkingMode;

    // Construct new settings map
    final newSettings = Map<String, dynamic>.from(_modelSettings);
    
    // Handle Thinking Config
    if (_thinkingEnabled) {
      newSettings['_aurora_thinking_config'] = {
        'enabled': true,
        'budget': _thinkingBudget,
        'mode': _thinkingMode,
      };
    } else {
      newSettings.remove('_aurora_thinking_config');
    }

    // Handle Custom Params
    if (customParams != null) {
      // Remove all non-internal keys (those not starting with _aurora_)
      newSettings.removeWhere((key, _) => !key.startsWith('_aurora_'));
      // Add new custom params
      newSettings.addAll(customParams);
    }

    setState(() {
      _modelSettings = newSettings;
    });

    widget.onSave(newSettings);
  }



  Future<void> _showEditDialog([String? key, dynamic value]) async {
     await showDialog(
      context: context,
      builder: (ctx) => _ParameterConfigDialog(
        initialKey: key,
        initialValue: value,
        onSave: (newKey, newValue) {
          final currentParams = Map<String, dynamic>.fromEntries(
            _modelSettings.entries.where((e) => !e.key.startsWith('_aurora_'))
          );
          
          if (key != null && key != newKey) {
            currentParams.remove(key);
          }
          currentParams[newKey] = newValue;
          _saveSettings(customParams: currentParams);
        },
      ),
    );
  }

  void _removeParam(String key) {
    final currentParams = Map<String, dynamic>.fromEntries(
      _modelSettings.entries.where((e) => !e.key.startsWith('_aurora_'))
    );
    currentParams.remove(key);
    _saveSettings(customParams: currentParams);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract custom params for display (exclude _aurora_ keys)
    final customParams = Map<String, dynamic>.fromEntries(
      _modelSettings.entries.where((e) => !e.key.startsWith('_aurora_'))
    );

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF202020) : Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.modelName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(l10n.modelConfig,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thinking Configuration Card
              _buildSectionCard(
                context,
                title: l10n.thinkingConfig,
                icon: Icons.lightbulb_outline,
                headerAction: Switch(
                  value: _thinkingEnabled,
                  onChanged: (v) => _saveSettings(thinkingEnabled: v),
                ),
                child: _thinkingEnabled ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: TextEditingController(text: _thinkingBudget)
                        ..selection = TextSelection.collapsed(offset: _thinkingBudget.length),
                      decoration: InputDecoration(
                        labelText: l10n.thinkingBudget,
                        hintText: l10n.thinkingBudgetHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _saveSettings(thinkingBudget: v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _thinkingMode,
                      decoration: InputDecoration(
                        labelText: l10n.transmissionMode,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        DropdownMenuItem(value: 'auto', child: Text(l10n.modeAuto)),
                        DropdownMenuItem(value: 'extra_body', child: Text(l10n.modeExtraBody)),
                        DropdownMenuItem(value: 'reasoning_effort', child: Text(l10n.modeReasoningEffort)),
                      ],
                      onChanged: (v) {
                        if (v != null) _saveSettings(thinkingMode: v);
                      },
                    ),
                  ],
                ) : null,
              ),

              const SizedBox(height: 16),

              // Custom Parameters Card
              _buildSectionCard(
                context,
                title: l10n.configureModelParams, // Or l10n.customParameters if available
                subtitle: l10n.paramsHigherPriority,
                icon: Icons.settings_outlined,
                headerAction: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showEditDialog(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (customParams.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.tune, size: 32, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              l10n.noCustomParams,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              child: Text(l10n.addCustomParam),
                               onPressed: () => _showEditDialog(),
                            )
                          ],
                        ),
                      )
                    else
                      ...customParams.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildParamItem(e.key, e.value, theme),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? headerAction,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: theme.primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(
                        fontSize: 11, 
                        color: theme.textTheme.bodySmall?.color
                      )),
                  ],
                ),
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildParamItem(String key, dynamic value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key, 
              style: TextStyle(
                fontFamily: 'monospace', 
                fontSize: 12, 
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSecondaryContainer
              )
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatValue(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textTheme.bodySmall?.color, fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          InkWell(
            onTap: () => _showEditDialog(key, value),
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.edit, size: 16),
            ),
          ),
          InkWell(
            onTap: () => _removeParam(key),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(Icons.delete_outline, size: 16, color: Colors.red.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value is String) return '"$value"';
    return jsonEncode(value);
  }
}



class _ParameterConfigDialog extends StatefulWidget {
  final String? initialKey;
  final dynamic initialValue;
  final Function(String key, dynamic value) onSave;
  const _ParameterConfigDialog({
    super.key,
    this.initialKey,
    this.initialValue,
    required this.onSave,
  });
  @override
  State<_ParameterConfigDialog> createState() => _ParameterConfigDialogState();
}

class _ParameterConfigDialogState extends State<_ParameterConfigDialog> {
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  String _type = 'string';
  bool _isInit = true;
  @override
  void initState() {
    super.initState();
    if (widget.initialKey != null) {
      _keyController.text = widget.initialKey!;
      final val = widget.initialValue;
      if (val is bool) {
        _type = 'boolean';
        _valueController.text = val.toString();
      } else if (val is num) {
        _type = 'number';
        _valueController.text = val.toString();
      } else if (val is Map || val is List) {
        _type = 'json';
        try {
          _valueController.text =
              const JsonEncoder.withIndent('  ').convert(val);
        } catch (_) {
          _valueController.text = jsonEncode(val);
        }
      } else {
        _type = 'string';
        _valueController.text = val.toString();
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.initialKey != null;
    final l10n = AppLocalizations.of(context)!;
    final typeMap = {
      'string': l10n.typeText,
      'number': l10n.typeNumber,
      'boolean': l10n.typeBoolean,
      'json': l10n.typeJson,
    };
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF202020) : Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(isEditing ? l10n.editParam : l10n.addCustomParam),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: l10n.paramKey,
              hintText: 'e.g. image_config',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            decoration: InputDecoration(
              labelText: l10n.paramType,
              border: const OutlineInputBorder(),
            ),
            items: typeMap.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueController,
            maxLines: _type == 'json' ? 5 : 1,
            minLines: _type == 'json' ? 3 : 1,
            decoration: InputDecoration(
              labelText: l10n.paramValue,
              hintText: 'Value',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final key = _keyController.text.trim();
            final valueStr = _valueController.text.trim();
            if (key.isEmpty) return;
            dynamic value;
            try {
              switch (_type) {
                case 'number':
                  value = num.parse(valueStr);
                  break;
                case 'boolean':
                  value = valueStr.toLowerCase() == 'true';
                  break;
                case 'json':
                  value = jsonDecode(valueStr);
                  break;
                default:
                  value = valueStr;
              }
              widget.onSave(key, value);
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${l10n.formatError}: $e')),
              );
            }
          },
          child: Text(isEditing ? l10n.save : l10n.add),
        ),
      ],
    );
  }
}
