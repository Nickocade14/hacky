import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_widgets.dart';
import 'app_tab.dart';

/// The bottom tab bar of every signed-in screen. The Hacky tab shows the
/// knit mascot instead of an icon.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.current, required this.onChanged});

  final AppTab current;
  final ValueChanged<AppTab> onChanged;

  /// Tests find a tab with `find.byKey(AppTabBar.keyOf(tab))`.
  static Key keyOf(AppTab tab) => Key('tab-${tab.name}');

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (index) => onChanged(AppTab.values[index]),
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              key: keyOf(tab),
              icon: tab == AppTab.hacky
                  ? const KnitHacky(height: 28)
                  : Icon(tab.icon),
              selectedIcon: tab == AppTab.hacky
                  ? const KnitHacky(height: 28)
                  : Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
