class _CopyButton extends StatefulWidget {
  final String text;
  final Color color;

  const _CopyButton({required this.text, required this.color});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _hasCopied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (mounted) {
          setState(() {
            _hasCopied = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _hasCopied = false;
              });
            }
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          _hasCopied ? Icons.check : Icons.copy,
          size: 16,
          color: _hasCopied ? Colors.green : widget.color,
        ),
      ),
    );
  }
}
