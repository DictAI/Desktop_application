import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../shell/main_shell.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/record/presentation/record_screen.dart';
import '../../features/workspace/presentation/workspaces_screen.dart';
import '../../features/workspace/presentation/workspace_detail_screen.dart';
import '../../features/results/presentation/results_screen.dart';
import '../../shared/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/record',
    redirect: (context, state) async {
      final storage = ref.read(secureStorageProvider);
      final hasToken = await storage.hasToken();
      final onLogin = state.matchedLocation == '/login';

      if (!hasToken && !onLogin) return '/login';
      if (hasToken && onLogin) return '/record';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/record',
            builder: (_, __) => const RecordScreen(),
          ),
          GoRoute(
            path: '/workspaces',
            builder: (_, __) => const WorkspacesScreen(),
            routes: [
              GoRoute(
                path: ':workspaceId',
                builder: (_, state) => WorkspaceDetailScreen(
                  workspaceId: state.pathParameters['workspaceId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/results',
            builder: (_, __) => const ResultsScreen(),
          ),
        ],
      ),
    ],
  );
});
