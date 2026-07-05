// ============================================================================
// main_shell.dart
//
// The root StatefulShellRoute scaffold that hosts the three primary tabs:
//   branch 0 → Home   (root destination)
//   branch 1 → Games
//   branch 2 → Profile
//
// Back-navigation rules (industry standard)
// -----------------------------------------
//   • Pressing back on a non-home tab (Games / Profile) switches back to the
//     Home tab instead of closing the app.
//   • Pressing back on the Home tab (the true root destination) shows the
//     App Exit confirmation dialog.
//   • Inner stack routes inside a branch (e.g. /games/pre/...) pop normally
//     via the per-branch Navigator — this PopScope only fires once that
//     branch's stack is already at its root.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_dialogs.dart';

// Routes that are considered "gameplay" — bottom nav should be hidden.
const _gameplayRoutePatterns = <String>[
  '/games/play/',
  '/games/pre/',
];

bool _isGameplayRoute(String location) {
  for (final p in _gameplayRoutePatterns) {
    if (location.contains(p)) return true;
  }
  return false;
}

class MainShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _homeBranchIndex = 0;

  Future<void> _handleRootBack() async {
    // Non-home tabs: back returns the user to Home instead of exiting the app.
    if (widget.shell.currentIndex != _homeBranchIndex) {
      HapticFeedback.selectionClick();
      widget.shell.goBranch(_homeBranchIndex);
      return;
    }

    // Home tab: this is the true root destination → ask before closing.
    if (!mounted) return;
    final shouldExit = await AppDialogs.showAppExit(context);
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isGameplay = _isGameplayRoute(location);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleRootBack();
      },
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar:
            isGameplay ? null : _BottomNav(shell: widget.shell),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _BottomNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final branch = shell.currentIndex;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                selected: branch == 0,
                onTap: () {
                  HapticFeedback.lightImpact();
                  shell.goBranch(0, initialLocation: branch == 0);
                },
              ),
              _NavItem(
                icon: Icons.grid_view_outlined,
                activeIcon: Icons.grid_view_rounded,
                label: 'Games',
                selected: branch == 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  shell.goBranch(1, initialLocation: branch == 1);
                },
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                selected: branch == 2,
                onTap: () {
                  HapticFeedback.lightImpact();
                  shell.goBranch(2, initialLocation: branch == 2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
