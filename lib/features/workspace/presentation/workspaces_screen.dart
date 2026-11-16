import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/dto/workspace_dto.dart';
import 'workspace_notifier.dart';

/// Workspace operations use the existing W01–W05 contracts.
class WorkspacesScreen extends ConsumerWidget {
  const WorkspacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspacesNotifierProvider);
    final notifier = ref.read(workspacesNotifierProvider.notifier);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final padding = compact ? 16.0 : 32.0;
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              onPressed: state.isMutating ? null : notifier.load,
              tooltip: 'Refresh workspaces',
              icon: const Icon(Icons.refresh_rounded),
            ),
            ElevatedButton.icon(
              onPressed: state.isMutating
                  ? null
                  : () => showWorkspaceNameDialog(
                      context,
                      title: 'New Workspace',
                      actionLabel: 'Create',
                      onSubmit: (name) async =>
                          await notifier.create(name) != null,
                      errorMessage: () => notifier.errorMessage,
                    ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Workspace'),
            ),
          ],
        );
        const title = Text(
          'Workspaces',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        );
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (compact) ...[
                      title,
                      const SizedBox(height: 12),
                      actions,
                    ] else
                      Row(
                        children: [
                          const Expanded(child: title),
                          actions,
                        ],
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage your meeting workspaces',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Dismiss error',
                            onPressed: notifier.clearError,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ],
                    if (state.isMutating) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
            if (state.status == WorkspacesStatus.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.workspaces.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: state.status == WorkspacesStatus.error
                        ? ElevatedButton.icon(
                            onPressed: notifier.load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          )
                        : const Text('No workspaces yet'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                sliver: compact
                    ? SliverList.builder(
                        itemCount: state.workspaces.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WorkspaceCard(
                            workspace: state.workspaces[index],
                            notifier: notifier,
                            disabled: state.isMutating,
                          ),
                        ),
                      )
                    : SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 320,
                              mainAxisExtent: 190,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: state.workspaces.length,
                        itemBuilder: (context, index) => _WorkspaceCard(
                          workspace: state.workspaces[index],
                          notifier: notifier,
                          disabled: state.isMutating,
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.workspace,
    required this.notifier,
    required this.disabled,
  });
  final WorkspaceDto workspace;
  final WorkspacesNotifier notifier;
  final bool disabled;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(
        '/workspaces/${Uri.encodeComponent(workspace.workspaceId)}',
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_rounded, color: AppColors.accent),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Workspace actions',
                  enabled: !disabled,
                  onSelected: (value) async {
                    if (value == 'open') {
                      context.go(
                        '/workspaces/${Uri.encodeComponent(workspace.workspaceId)}',
                      );
                    } else if (value == 'rename') {
                      await showWorkspaceNameDialog(
                        context,
                        title: 'Rename Workspace',
                        actionLabel: 'Save',
                        initialName: workspace.name,
                        onSubmit: (name) async =>
                            await notifier.rename(
                              workspace.workspaceId,
                              name,
                            ) !=
                            null,
                        errorMessage: () => notifier.errorMessage,
                      );
                    } else if (value == 'delete') {
                      await showWorkspaceDeleteDialog(
                        context,
                        workspace,
                        onDelete: () => notifier.delete(workspace.workspaceId),
                        errorMessage: () => notifier.errorMessage,
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              workspace.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${workspace.workspaceId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> showWorkspaceNameDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
  required Future<bool> Function(String) onSubmit,
  required String? Function() errorMessage,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WorkspaceActionDialog(
    title: title,
    actionLabel: actionLabel,
    initialName: initialName,
    onSubmit: onSubmit,
    errorMessage: errorMessage,
  ),
);

Future<bool?> showWorkspaceDeleteDialog(
  BuildContext context,
  WorkspaceDto workspace, {
  required Future<bool> Function() onDelete,
  required String? Function() errorMessage,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WorkspaceActionDialog(
    title: 'Delete ${workspace.name}?',
    actionLabel: 'Delete',
    explanation:
        'Workspace and its contacts will be removed. This action does not promise deletion of recordings or results.',
    onSubmit: (_) => onDelete(),
    errorMessage: errorMessage,
  ),
);

class _WorkspaceActionDialog extends ConsumerStatefulWidget {
  const _WorkspaceActionDialog({
    required this.title,
    required this.actionLabel,
    required this.onSubmit,
    required this.errorMessage,
    this.initialName,
    this.explanation,
  });
  final String title, actionLabel;
  final String? initialName, explanation;
  final Future<bool> Function(String) onSubmit;
  final String? Function() errorMessage;
  @override
  ConsumerState<_WorkspaceActionDialog> createState() =>
      _WorkspaceActionDialogState();
}

class _WorkspaceActionDialogState
    extends ConsumerState<_WorkspaceActionDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onSubmit(_name.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error =
          widget.errorMessage() ?? 'Операция не выполнена. Попробуйте ещё раз.';
    });
  }

  void _dismissSession() {
    _name.clear();
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    Future.microtask(() {
      if (mounted && navigator.mounted && route?.isActive == true) {
        navigator.removeRoute(route!, false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (_, __) => _dismissSession());
    ref.listen(sessionNotifierProvider, (_, __) => _dismissSession());
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(widget.title),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.initialName != null)
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    enabled: !_busy,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Workspace name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Введите название рабочего пространства.'
                        : null,
                  ),
                if (widget.explanation != null) Text(widget.explanation!),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: Text(widget.actionLabel),
          ),
        ],
      ),
    );
  }
}
