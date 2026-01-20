import 'package:fluent_ui/fluent_ui.dart';
import 'package:aurora/l10n/app_localizations.dart';
import 'novel/novel_writing_page.dart';

class StudioContent extends StatefulWidget {
  const StudioContent({super.key});

  @override
  State<StudioContent> createState() => _StudioContentState();
}

class _StudioContentState extends State<StudioContent> {
  // 0: Dashboard, 1: Novel Writing
  int _viewIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_viewIndex == 1) {
      return NovelWritingPage(
        onBack: () {
          setState(() {
            _viewIndex = 0;
          });
        },
      );
    }

    final theme = FluentTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Dashboard View
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FluentIcons.toolbox,
              size: 64,
              color: theme.accentColor,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.studio,
              style: theme.typography.title,
            ),
            const SizedBox(height: 10),
            Text(
              '在这里配置和编排你的智能助手', 
              style: theme.typography.body,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureCard(
                  context,
                  icon: FluentIcons.edit_mail,
                  title: l10n.novelWriting,
                  description: '配置写作、审查、大纲模型\n细分、拆解与分配工作',
                  onTap: () {
                    setState(() {
                      _viewIndex = 1;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String description,
      required VoidCallback onTap}) {
    final theme = FluentTheme.of(context);
    return Card(
      padding: EdgeInsets.zero,
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          return Container(
            width: 250,
            height: 150,
            color: states.isHovering ? theme.accentColor.withOpacity(0.05) : Colors.transparent,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: theme.accentColor),
                const SizedBox(height: 16),
                Text(title, style: theme.typography.subtitle),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.typography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
