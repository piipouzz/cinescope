import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CatalogueShell extends StatelessWidget {
  const CatalogueShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: theme.colorScheme.card,
        indicatorColor: theme.colorScheme.secondary,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.film), label: 'Films'),
          NavigationDestination(
            icon: Icon(LucideIcons.mapPin),
            label: 'Cinémas',
          ),
        ],
      ),
    );
  }
}
