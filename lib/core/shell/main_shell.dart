import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/record/presentation/record_exit_guard.dart';
import '../../features/record/presentation/record_notifier.dart';

/// На iOS и узких окнах разделы доступны через нижнюю панель.
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _items = [
    _NavItem(icon: Icons.mic_rounded, label: 'Record', path: '/record'),
    _NavItem(
      icon: Icons.folder_open_rounded,
      label: 'Workspaces',
      path: '/workspaces',
    ),
    _NavItem(
      icon: Icons.description_rounded,
      label: 'Results',
      path: '/results',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);

    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final location = router.routerDelegate.currentConfiguration.uri.path;
        return LayoutBuilder(
          builder: (context, constraints) {
            final mobile =
                Theme.of(context).platform == TargetPlatform.iOS ||
                constraints.maxWidth < 600;
            if (mobile) {
              final index = _items.indexWhere((item) => item.matches(location));
              final selectedIndex = index < 0 ? 0 : index;
              return Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  leading: index >= 0 && location != _items[index].path
                      ? BackButton(onPressed: () => context.pop())
                      : null,
                  title: const Text('Dict AI'),
                  backgroundColor: AppColors.background,
                  actions: [_LogoutButton(ref: ref, compact: true)],
                ),
                body: SafeArea(top: false, bottom: false, child: child),
                bottomNavigationBar: NavigationBar(
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.surfaceElevated,
                  selectedIndex: selectedIndex,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (index) {
                    // Повторное нажатие сохраняет detail route и workspace query.
                    if (index != selectedIndex) context.go(_items[index].path);
                  },
                  destinations: [
                    for (final item in _items)
                      NavigationDestination(
                        icon: Icon(item.icon, color: AppColors.textPrimary),
                        label: item.label,
                        tooltip: item.label,
                      ),
                  ],
                ),
              );
            }
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _Sidebar(items: _items, currentPath: location, ref: ref),
                    const SizedBox(width: 16),
                    Expanded(child: child),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final String currentPath;
  final WidgetRef ref;

  const _Sidebar({
    required this.items,
    required this.currentPath,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Dict AI',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: items.map((item) {
                final isActive = item.matches(currentPath);
                return _NavButton(item: item, isActive: isActive);
              }).toList(),
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            child: _LogoutButton(ref: ref),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;

  const _NavButton({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go(item.path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isActive ? AppColors.textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isActive
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.background
                        : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final WidgetRef ref;
  final bool compact;

  const _LogoutButton({required this.ref, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Future<void> logout() async {
      final recording = ref.exists(recordNotifierProvider)
          ? ref.read(recordNotifierProvider.notifier)
          : null;
      final revision = recording?.recordingRevision;
      if (Theme.of(context).platform == TargetPlatform.iOS &&
          !await ref.read(recordExitGuardProvider).canLeave(context)) {
        return;
      }
      if (!context.mounted) return;
      if (recording != null &&
          (!recording.mounted || revision != recording.recordingRevision)) {
        return;
      }
      await ref.read(authNotifierProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    if (compact) {
      return IconButton(
        tooltip: 'Log out',
        onPressed: logout,
        icon: const Icon(Icons.logout_rounded),
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: logout,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});

  bool matches(String location) =>
      location == path || location.startsWith('$path/');
}
