import 'dart:ui';

import 'package:kalsada/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scaffold hosting the Home / Plan / Map / Nearby food tab bar around the
/// shell branches.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.82),
              border: Border(top: BorderSide(color: colors.sep, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _TabItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: navigationShell.currentIndex == 0,
                      onTap: () => navigationShell.goBranch(0),
                    ),
                    _TabItem(
                      icon: Icons.auto_awesome,
                      activeIcon: Icons.auto_awesome,
                      label: 'Plan',
                      selected: navigationShell.currentIndex == 1,
                      emphasized: true,
                      onTap: () => navigationShell.goBranch(1),
                    ),
                    _TabItem(
                      icon: Icons.place_outlined,
                      activeIcon: Icons.place_rounded,
                      label: 'Map',
                      selected: navigationShell.currentIndex == 2,
                      onTap: () => navigationShell.goBranch(2),
                    ),
                    _TabItem(
                      icon: Icons.restaurant_outlined,
                      activeIcon: Icons.restaurant_rounded,
                      label: 'Food',
                      selected: navigationShell.currentIndex == 3,
                      onTap: () => navigationShell.goBranch(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    final color = selected ? colors.accent : colors.sub;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              if (emphasized)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? [colors.accent, colors.secondary]
                          : [
                              colors.accent.withValues(alpha: 0.16),
                              colors.secondary.withValues(alpha: 0.16),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(KalsadaRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 18,
                    color: selected ? Colors.white : colors.accent,
                  ),
                )
              else
                Icon(selected ? activeIcon : icon, size: 23, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: kalsadaMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
