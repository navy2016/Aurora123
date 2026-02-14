part of 'settings_content.dart';

class _ApiKeyItem extends StatefulWidget {
  final String apiKey;
  final ValueChanged<String> onUpdate;

  const _ApiKeyItem({
    super.key,
    required this.apiKey,
    required this.onUpdate,
  });

  @override
  State<_ApiKeyItem> createState() => _ApiKeyItemState();
}

class _ApiKeyItemState extends State<_ApiKeyItem> {
  late TextEditingController _controller;
  bool _isVisible = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.apiKey);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Optional: Trigger update on blur if we want to be safe,
        // but onChanged should handle it.
      }
    });
  }

  @override
  void didUpdateWidget(_ApiKeyItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiKey != _controller.text) {
      _controller.text = widget.apiKey;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return fluent.TextBox(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: !_isVisible,
      onChanged: widget.onUpdate,
      placeholder: l10n.apiKeyPlaceholder,
      suffix: fluent.IconButton(
        icon: fluent.Icon(
          _isVisible ? AuroraIcons.visibilityOff : AuroraIcons.visibility,
          size: 14,
        ),
        onPressed: () {
          setState(() {
            _isVisible = !_isVisible;
          });
        },
      ),
      decoration: WidgetStateProperty.all(BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.transparent),
      )),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        letterSpacing: _isVisible ? 0 : 2,
      ),
      highlightColor: Colors.transparent,
      unfocusedColor: Colors.transparent,
    );
  }
}
