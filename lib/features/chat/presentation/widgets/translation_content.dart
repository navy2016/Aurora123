import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../chat_provider.dart';
import '../../domain/message.dart';

class TranslationContent extends ConsumerStatefulWidget {
  const TranslationContent({super.key});
  @override
  ConsumerState<TranslationContent> createState() => _TranslationContentState();
}

class _TranslationContentState extends ConsumerState<TranslationContent> {
  final TextEditingController _sourceController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _sourceLang = '自动检测';
  String _targetLang = '简体中文';
  bool _showComparison = true;
  bool _hasRestored = false;
  double _leftRatio = 0.5;
  final List<String> _sourceLanguages = [
    '自动检测',
    '英语',
    '日语',
    '韩语',
    '简体中文',
    '繁体中文',
    '俄语',
    '法语',
    '德语'
  ];
  final List<String> _targetLanguages = [
    '简体中文',
    '英语',
    '日语',
    '韩语',
    '繁体中文',
    '俄语',
    '法语',
    '德语'
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestore();
    });
  }

  void _tryRestore() {
    if (_hasRestored) return;
    final chatState = ref.read(translationProvider);
    if (chatState.messages.isNotEmpty) {
      final lastUserMsg = chatState.messages.lastWhere((m) => m.isUser,
          orElse: () => Message(
              content: '', isUser: true, id: '', timestamp: DateTime.now()));
      if (lastUserMsg.content.isNotEmpty) {
        _sourceController.text = lastUserMsg.content;
      }
      _hasRestored = true;
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _translate() {
    if (_sourceController.text.trim().isEmpty) return;
    final notifier = ref.read(translationProvider.notifier);
    notifier.clearContext().then((_) {
      final sb = StringBuffer();
      sb.writeln(
          '你是一位精通多国语言的专业翻译专家。请将以下${_sourceLang == '自动检测' ? '' : _sourceLang}文本翻译成$_targetLang。');
      sb.writeln('要求：');
      sb.writeln('1. 翻译准确、地道，符合目标语言的表达习惯。');
      sb.writeln('2. 严格保留原文的换行格式和段落结构，不要合并段落。');
      sb.writeln('3. 只输出翻译后的内容，不要包含任何解释、前言或后缀。');
      sb.writeln('');
      sb.writeln('原文内容：');
      sb.writeln(_sourceController.text);
      notifier.sendMessage(_sourceController.text, apiContent: sb.toString());
    });
  }

  Widget _buildSourceInput(fluent.FluentThemeData theme, bool isWindows) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              fluent.Text('原文',
                  style:
                      TextStyle(color: theme.resources.textFillColorSecondary)),
              if (_sourceController.text.isNotEmpty)
                fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.clear),
                  onPressed: () => _sourceController.clear(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: fluent.TextBox(
              controller: _sourceController,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              placeholder: '在此输入要翻译的文本...',
              decoration: null,
              highlightColor: Colors.transparent,
              unfocusedColor: Colors.transparent,
              style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontFamily: isWindows ? 'Microsoft YaHei' : null,
                  color: theme.typography.body?.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetOutput(fluent.FluentThemeData theme, bool isWindows,
      ChatState chatState, Message? aiMessage) {
    return Container(
      padding: const EdgeInsets.all(0),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                fluent.Text(_showComparison ? '双语对照' : '译文',
                    style: TextStyle(
                        color: theme.resources.textFillColorSecondary)),
                fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.copy),
                  onPressed: () {
                    final text = aiMessage?.content;
                    if (text != null && text.isNotEmpty) {
                      final item = DataWriterItem();
                      item.add(Formats.plainText(text));
                      SystemClipboard.instance?.write([item]);
                    }
                  },
                ),
              ],
            ),
          ),
          Container(
              height: 1, color: theme.resources.dividerStrokeColorDefault),
          Expanded(
            child: Builder(
              builder: (context) {
                if (aiMessage == null && !chatState.isLoading) {
                  return const Center(
                      child: Text('翻译结果将显示在这里',
                          style: TextStyle(color: Colors.grey)));
                }
                String sourceText = _sourceController.text;
                if (sourceText.isEmpty && chatState.messages.isNotEmpty) {
                  final lastUserMsg = chatState.messages.lastWhere(
                      (m) => m.isUser,
                      orElse: () => Message(
                          content: '',
                          isUser: true,
                          id: '',
                          timestamp: DateTime.now()));
                  sourceText = lastUserMsg.content;
                }
                final sourceLines = sourceText.split('\n');
                final targetText = aiMessage?.content ?? '';
                final targetLines = targetText.split('\n');
                if (chatState.isLoading && targetText.isEmpty) {
                  return const Center(
                      child: Text('正在翻译...',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey)));
                }
                final int itemCount = _showComparison
                    ? (sourceLines.length > targetLines.length
                        ? sourceLines.length
                        : targetLines.length)
                    : targetLines.length;
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  separatorBuilder: (c, i) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final tgt =
                        index < targetLines.length ? targetLines[index] : '';
                    if (!_showComparison) {
                      return SelectableText(
                        tgt,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            fontFamily: isWindows ? 'Microsoft YaHei' : null),
                      );
                    }
                    final src =
                        index < sourceLines.length ? sourceLines[index] : '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (src.isNotEmpty)
                          SelectableText(
                            src,
                            style: TextStyle(
                                color: theme.resources.textFillColorSecondary,
                                fontSize: 14,
                                height: 1.4,
                                fontFamily:
                                    isWindows ? 'Microsoft YaHei' : null),
                          ),
                        if (src.isNotEmpty && tgt.isNotEmpty)
                          const SizedBox(height: 4),
                        if (tgt.isNotEmpty)
                          SelectableText(
                            tgt,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                fontFamily:
                                    isWindows ? 'Microsoft YaHei' : null),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ChatState>(translationProvider, (prev, next) {
      if (!_hasRestored && next.messages.isNotEmpty) {
        final lastUserMsg = next.messages.lastWhere((m) => m.isUser,
            orElse: () => Message(
                content: '', isUser: true, id: '', timestamp: DateTime.now()));
        if (lastUserMsg.content.isNotEmpty) {
          _sourceController.text = lastUserMsg.content;
          _hasRestored = true;
        }
      }
    });
    final chatState = ref.watch(translationProvider);
    final isWindows = !kIsWeb && Platform.isWindows;
    final theme = fluent.FluentTheme.of(context);
    final aiMessage =
        chatState.messages.isNotEmpty && !chatState.messages.last.isUser
            ? chatState.messages.last
            : null;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault)),
            color: theme.navigationPaneTheme.backgroundColor,
          ),
          child: Row(
            children: [
              fluent.Text('文本翻译',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 24),
              fluent.ComboBox<String>(
                value: _sourceLang,
                items: _sourceLanguages
                    .map((e) => fluent.ComboBoxItem(child: Text(e), value: e))
                    .toList(),
                onChanged: (v) => setState(() => _sourceLang = v!),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(fluent.FluentIcons.forward, size: 12),
              ),
              fluent.ComboBox<String>(
                value: _targetLang,
                items: _targetLanguages
                    .map((e) => fluent.ComboBoxItem(child: Text(e), value: e))
                    .toList(),
                onChanged: (v) => setState(() => _targetLang = v!),
              ),
              const SizedBox(width: 24),
              fluent.Checkbox(
                checked: _showComparison,
                onChanged: (v) => setState(() => _showComparison = v ?? true),
                content: const Text('双语对照'),
              ),
              const Spacer(),
              if (chatState.isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: fluent.ProgressRing(strokeWidth: 2),
                ),
              fluent.FilledButton(
                onPressed: chatState.isLoading ? null : _translate,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fluent.FluentIcons.translate, size: 14),
                    SizedBox(width: 6),
                    Text('翻译'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    Expanded(child: _buildSourceInput(theme, isWindows)),
                    Container(
                        height: 1,
                        color: theme.resources.dividerStrokeColorDefault),
                    Expanded(
                        child: _buildTargetOutput(
                            theme, isWindows, chatState, aiMessage)),
                  ],
                );
              }
              final width = constraints.maxWidth;
              final leftWidth = width * _leftRatio;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth < 100 ? 100 : leftWidth,
                    child: _buildSourceInput(theme, isWindows),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _leftRatio += details.delta.dx / width;
                          if (_leftRatio < 0.2) _leftRatio = 0.2;
                          if (_leftRatio > 0.8) _leftRatio = 0.8;
                        });
                      },
                      child: Container(
                        width: 16,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                              width: 1,
                              color: theme.resources.dividerStrokeColorDefault),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildTargetOutput(
                        theme, isWindows, chatState, aiMessage),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
