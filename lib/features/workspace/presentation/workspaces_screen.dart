import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../data/dto/workspace_dto.dart';
import 'workspace_notifier.dart';

/// React-аналог: WorkspacesPage.tsx
/// Список воркспейсов текущего пользователя.
/// GET /workspaces/ — STUB (см. MISSING_ENDPOINTS.md п.1).
/// При получении StubException показывается информационный баннер,
/// а не crash.
class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspacesNotifierProvider);
    final notifier = ref.read(workspacesNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Workspaces',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _CreateWorkspaceButton(
                isLoading:
                    state.status == WorkspacesStatus.creating,
                onPressed: () => _showCreateDialog(context, notifier),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your meeting workspaces',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          if (state.errorMessage != null)
            _InfoBanner(
              message: state.errorMessage!,
              isStub: state.isStubError,
              onDismiss: notifier.clearError,
            ),

          Expanded(
            child: switch (state.status) {
              WorkspacesStatus.loading => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                  ),
                ),
              WorkspacesStatus.loaded when state.workspaces.isEmpty =>
                const _EmptyState(),
              WorkspacesStatus.error when state.isStubError =>
                _StubPlaceholder(onRetry: notifier.load),
              WorkspacesStatus.error => _ErrorState(
                  message: state.errorMessage ?? '',
                  onRetry: notifier.load,
                ),
              _ => _WorkspaceGrid(
                  workspaces: state.workspaces,
                  onDelete: (id) => notifier.delete(id),
                ),
            },
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(
      BuildContext context, WorkspacesNotifier notifier) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _CreateWorkspaceDialog(notifier: notifier),
    );
  }
}

// Grid рабочих пространств

class _WorkspaceGrid extends StatelessWidget {
  final List<WorkspaceDto> workspaces;
  final Future<bool> Function(String id) onDelete;

  const _WorkspaceGrid({
    required this.workspaces,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 160,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: workspaces.length,
      itemBuilder: (_, i) => _WorkspaceCard(
        workspace: workspaces[i],
        onDelete: onDelete,
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final WorkspaceDto workspace;
  final Future<bool> Function(String id) onDelete;

  const _WorkspaceCard({
    required this.workspace,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.go('/workspaces/${workspace.workspaceId}'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Иконка + меню
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      color: AppColors.accent, size: 20),
                ),
                const Spacer(),
                _WorkspaceMenu(
                  workspaceId: workspace.workspaceId,
                  onDelete: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Название
            Text(
              workspace.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${workspace.workspaceId.substring(0, 8)}...',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMenu extends StatelessWidget {
  final String workspaceId;
  final Future<bool> Function(String id) onDelete;

  const _WorkspaceMenu({
    required this.workspaceId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded,
          color: AppColors.textSecondary, size: 18),
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'open',
          child: Text('Open',
              style: TextStyle(color: AppColors.textPrimary)),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete',
              style: TextStyle(color: AppColors.error)),
        ),
      ],
      onSelected: (value) async {
        if (value == 'open') {
          // ignore: use_build_context_synchronously
          context.go('/workspaces/$workspaceId');
        } else if (value == 'delete') {
          final ok = await onDelete(workspaceId);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Delete is not yet available'),
                backgroundColor: AppColors.surfaceElevated,
              ),
            );
          }
        }
      },
    );
  }
}

// Диалог создания воркспейса

class _CreateWorkspaceDialog extends StatefulWidget {
  final WorkspacesNotifier notifier;

  const _CreateWorkspaceDialog({required this.notifier});

  @override
  State<_CreateWorkspaceDialog> createState() =>
      _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState
    extends State<_CreateWorkspaceDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ws = await widget.notifier.create(_nameCtrl.text.trim());
    if (!mounted) return;
    if (ws != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Workspace',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                onFieldSubmitted: (_) => _submit(),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Workspace name',
                  hintStyle: const TextStyle(
                      color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a workspace name';
                  }
                  if (v.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.surfaceElevated),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Вспомогательные виджеты

class _CreateWorkspaceButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CreateWorkspaceButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textPrimary),
            )
          : const Icon(Icons.add_rounded, size: 18),
      label: const Text('New Workspace'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: AppColors.textSecondary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No workspaces yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first workspace to get started',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StubPlaceholder extends StatelessWidget {
  final VoidCallback onRetry;

  const _StubPlaceholder({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.accentSubtle,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_rounded,
                color: AppColors.accent, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Backend endpoint not implemented',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'GET /workspaces/ is missing from the backend.\n'
              'See MISSING_ENDPOINTS.md for details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent),
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final bool isStub;
  final VoidCallback onDismiss;

  const _InfoBanner({
    required this.message,
    required this.isStub,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isStub ? AppColors.accent : AppColors.error;
    final bg = isStub ? AppColors.accentSubtle : AppColors.errorSubtle;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isStub
                ? Icons.construction_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, color: color, size: 16),
          ),
        ],
      ),
    );
  }
}
