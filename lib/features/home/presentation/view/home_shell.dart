import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_nav_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';

/// The four tabs of doc 08 §4: Translate, Phrases, History, Me.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    BottomNavigationBarItem item(AppIcons icon, String label) =>
        BottomNavigationBarItem(
          icon: AppIcon(icon, color: scheme.onSurfaceVariant),
          activeIcon: AppIcon(icon, color: scheme.primary),
          label: label,
        );
    return AppPlatformScaffold(
      body: shell,
      bottomNavigationBar: AppPlatformNavBar(
        currentIndex: shell.currentIndex,
        onSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          item(AppIcons.navTranslate, l10n.navTranslate),
          item(AppIcons.navPhrases, l10n.navPhrases),
          item(AppIcons.navHistory, l10n.navHistory),
          item(AppIcons.navMe, l10n.navMe),
        ],
      ),
    );
  }
}
