import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/palettes.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // (outlined, filled, label) — outlined when idle, filled when active.
  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.format_list_bulleted_rounded, Icons.view_list_rounded, 'Activity'),
    (Icons.track_changes_outlined, Icons.track_changes_rounded, 'Goals'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Feelings'),
    (Icons.people_outline_rounded, Icons.people_alt_rounded, 'Us'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: p.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    activeIcon: _items[i].$2,
                    label: _items[i].$3,
                    selected: shell.currentIndex == i,
                    onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final color = selected ? p.primaryDeep : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.1 : 1,
              duration: Motion.fast,
              curve: Motion.curve,
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(selected ? activeIcon : icon, key: ValueKey(selected), color: color, size: 24),
              ),
            ),
            const SizedBox(height: 3),
            ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
