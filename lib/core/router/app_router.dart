import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shell/main_shell.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/record/presentation/record_screen.dart';
import '../../features/workspace/presentation/workspaces_screen.dart';
import '../../features/workspace/presentation/workspace_detail_screen.dart';
import '../../features/results/presentation/results_screen.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import 'auth_listenable.dart';
import '../../features/workspace/data/dto/workspace_dto.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/record',
    refreshListenable: AuthListenable(ref),
    redirect: (context, state) async {
      final hasToken = await ref
          .read(authNotifierProvider.notifier)
          .hasValidSession();
      final onLogin = state.matchedLocation == '/login';

      if (!hasToken && !onLogin) return '/login';
      if (hasToken && onLogin) return '/record';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/record',
            pageBuilder: (_, state) => NoTransitionPage(
              child: RecordScreen(
                workspaceId: state.uri.queryParameters['workspaceId'],
                workspace: state.extra is WorkspaceDto
                    ? state.extra as WorkspaceDto
                    : null,
              ),
            ),
          ),
          GoRoute(
            path: '/workspaces',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: WorkspacesScreen()),
            routes: [
              GoRoute(
                path: ':workspaceId',
                pageBuilder: (_, state) => NoTransitionPage(
                  child: WorkspaceDetailScreen(
                    workspaceId: state.pathParameters['workspaceId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/results',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ResultsScreen()),
          ),
        ],
      ),
    ],
  );
});
