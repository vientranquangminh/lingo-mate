import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';

/// Bottom tab bar styled for the current platform.
class AppPlatformNavBar extends StatelessWidget {
  const AppPlatformNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoTabBar(
        items: items,
        currentIndex: currentIndex,
        onTap: onSelected,
      );
    }
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: item.icon,
            selectedIcon: item.activeIcon,
            label: item.label ?? '',
            tooltip: item.tooltip,
          ),
      ],
    );
  }
}
