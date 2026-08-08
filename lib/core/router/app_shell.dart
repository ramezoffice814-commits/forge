import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/forge_bottom_navigation_bar.dart';
import '../../shared/widgets/forge_scaffold.dart';

/// The persistent app shell: hosts the active tab's [navigationShell] plus
/// the floating [ForgeBottomNavigationBar]. Pure wiring — no feature
/// business logic lives here, only navigation plumbing.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    ForgeNavItem(icon: Icons.home_outlined, label: 'Home'),
    ForgeNavItem(icon: Icons.emoji_events_outlined, label: 'Rank'),
    ForgeNavItem(icon: Icons.bar_chart_outlined, label: 'Progress'),
    ForgeNavItem(icon: Icons.military_tech_outlined, label: 'Awards'),
    ForgeNavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ForgeScaffold(
      body: navigationShell,
      bottomNavigationBar: ForgeBottomNavigationBar(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-active tab resets that branch to its
          // initial location instead of leaving it wherever it was.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
