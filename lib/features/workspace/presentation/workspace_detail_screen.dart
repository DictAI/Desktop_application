import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../data/dto/participant_dto.dart';
import 'workspace_notifier.dart';
import 'workspaces_screen.dart';
import '../../record/presentation/record_notifier.dart';
import '../../record/presentation/anonymous_record_notifier.dart';

/// React-аналог: WorkspaceDetailPage.tsx
/// Детальная страница воркспейса: информация + список участников +
/// форма добавления участника.
class WorkspaceDetailScreen extends ConsumerWidget {
  final String workspaceId;

  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceDetailProvider(workspaceId));
    final notifier = ref.read(workspaceDetailProvider(workspaceId).notifier);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: switch (state.status) {
        DetailStatus.loading => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        DetailStatus.error => _ErrorView(
          message: state.errorMessage ?? 'Unknown error',
          onRetry: notifier.load,
        ),
        DetailStatus.loaded => _DetailContent(state: state, notifier: notifier),
      },
    );
  }
}

// Основной контент

class _DetailContent extends ConsumerWidget {
  final WorkspaceDetailState state;
  final WorkspaceDetailNotifier notifier;

  const _DetailContent({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = state.workspace!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ws.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: state.isUpdatingWorkspace
                  ? null
                  : () => showWorkspaceNameDialog(
                      context,
                      title: 'Rename Workspace',
                      actionLabel: 'Save',
                      initialName: ws.name,
                      onSubmit: notifier.updateWorkspace,
                      errorMessage: () => notifier.errorMessage,
                    ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Rename'),
            ),
            ElevatedButton.icon(
              onPressed: state.isUpdatingWorkspace
                  ? null
                  : () {
                      final recording = ref.exists(recordNotifierProvider)
                          ? ref.read(recordNotifierProvider.notifier)
                          : null;
                      final anonymous = ref.exists(anonRecordNotifierProvider)
                          ? ref.read(anonRecordNotifierProvider)
                          : null;
                      if (recording?.hasActiveOperation == true ||
                          anonymous?.isActive == true ||
                          anonymous?.status == AnonStatus.uploading ||
                          anonymous?.status == AnonStatus.confirming) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Сначала завершите активную запись или отправку. Выбранное рабочее пространство не изменено.',
                            ),
                          ),
                        );
                        return;
                      }
                      context.go(
                        Uri(
                          path: '/record',
                          queryParameters: {'workspaceId': ws.workspaceId},
                        ).toString(),
                        extra: ws,
                      );
                    },
              icon: const Icon(Icons.mic_rounded),
              label: const Text('Новая запись'),
            ),
            IconButton(
              onPressed: state.isUpdatingWorkspace ? null : notifier.load,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 8),

        _MetaRow(
          label: 'Created',
          value: ws.createdAt.toLocal().toString().split('.').first,
        ),
        const SizedBox(height: 32),

        if (state.errorMessage != null)
          _ErrorBanner(
            message: state.errorMessage!,
            onDismiss: notifier.clearError,
          ),

        Row(
          children: [
            const Text(
              'Participants',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${state.participants.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: state.isContactBusy || state.needsContactReconciliation
                  ? null
                  : () => _showContactDialog(context, notifier.workspaceId),
              icon: const Icon(
                Icons.person_add_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Это контакты workspace, а не учётные записи или приглашения. '
          'Изменение контактов не переименовывает Speaker в транскрипте.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Email результатов: для workspace backend использует владельца и контакты, '
          'для записи без workspace — только владельца. Доставка зависит от серверных настроек. '
          'Изменение контакта не пересылает готовое письмо.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (state.needsContactReconciliation) ...[
          const SizedBox(height: 8),
          Text(
            notifier.pendingContactDescription ??
                'Последнее изменение контакта',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: state.isContactBusy
                    ? null
                    : notifier.reconcileContactMutation,
                child: const Text('Проверить состояние'),
              ),
              if (state.canRetryContactMutation)
                TextButton(
                  onPressed: state.isContactBusy
                      ? null
                      : notifier.retryContactMutation,
                  child: const Text('Повторить те же изменения'),
                ),
            ],
          ),
        ],
        if (state.isContactBusy) const LinearProgressIndicator(),
        const SizedBox(height: 16),

        Expanded(
          child: state.participants.isEmpty
              ? const _EmptyParticipants()
              : _ParticipantList(
                  participants: state.participants,
                  workspaceId: notifier.workspaceId,
                  disabled:
                      state.isContactBusy || state.needsContactReconciliation,
                ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

void _showContactDialog(
  BuildContext context,
  String workspaceId, {
  ParticipantDto? contact,
  bool remove = false,
}) {
  showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ContactDialog(
      workspaceId: workspaceId,
      contact: contact,
      remove: remove,
    ),
  );
}

class _ContactDialog extends ConsumerStatefulWidget {
  const _ContactDialog({
    required this.workspaceId,
    this.contact,
    this.remove = false,
  });
  final String workspaceId;
  final ParticipantDto? contact;
  final bool remove;
  @override
  ConsumerState<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends ConsumerState<_ContactDialog> {
  late final _name = TextEditingController(text: widget.contact?.name ?? '');
  late final _email = TextEditingController(text: widget.contact?.email ?? '');
  final _form = GlobalKey<FormState>();
  bool _working = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit({bool check = false, bool retry = false}) async {
    if (_working ||
        (!check && !retry && !(_form.currentState?.validate() ?? false))) {
      return;
    }
    final notifier = ref.read(
      workspaceDetailProvider(widget.workspaceId).notifier,
    );
    setState(() {
      _working = true;
      _error = null;
    });
    final bool ok;
    if (check) {
      ok = await notifier.reconcileContactMutation();
    } else if (retry) {
      ok = await notifier.retryContactMutation();
    } else if (widget.remove) {
      ok = await notifier.deleteParticipant(widget.contact!.participantId);
    } else if (widget.contact != null) {
      ok = await notifier.updateParticipant(
        participantId: widget.contact!.participantId,
        name: _name.text,
        email: _email.text,
      );
    } else {
      ok = await notifier.addParticipant(name: _name.text, email: _email.text);
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _working = false;
      _error = notifier.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceDetailProvider(widget.workspaceId));
    final busy = _working || state.isContactBusy;
    final contactAvailable =
        widget.contact == null ||
        state.participants.any(
          (contact) => contact.participantId == widget.contact!.participantId,
        );
    final editable =
        !busy && contactAvailable && !state.needsContactReconciliation;
    final action = widget.remove
        ? 'Remove'
        : widget.contact == null
        ? 'Add'
        : 'Save';
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          widget.remove
              ? 'Remove ${widget.contact!.name}?'
              : widget.contact == null
              ? 'Add Participant'
              : 'Edit contact',
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.remove)
                  const Text(
                    'This removes the workspace contact. It does not rename speakers or change an existing transcript.',
                  )
                else ...[
                  TextFormField(
                    controller: _name,
                    enabled: editable,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Full name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Name required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    enabled: editable,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                    ),
                    onFieldSubmitted: (_) {
                      if (editable) _submit();
                    },
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Email required'
                        : !RegExp(
                            r'^[^\s@<>]+@[^\s@<>]+$',
                          ).hasMatch(value.trim())
                        ? 'Invalid email'
                        : null,
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (busy)
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
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          if (state.needsContactReconciliation) ...[
            TextButton(
              onPressed: busy ? null : () => _submit(check: true),
              child: const Text('Проверить состояние'),
            ),
            if (state.canRetryContactMutation)
              ElevatedButton(
                onPressed: busy ? null : () => _submit(retry: true),
                child: const Text('Повторить те же изменения'),
              ),
          ] else if (contactAvailable)
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: Text(action),
            ),
        ],
      ),
    );
  }
}

class _ParticipantList extends StatelessWidget {
  const _ParticipantList({
    required this.participants,
    required this.workspaceId,
    required this.disabled,
  });
  final List<ParticipantDto> participants;
  final String workspaceId;
  final bool disabled;
  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: participants.length,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, index) {
      final contact = participants[index];
      return Card(
        key: ValueKey(contact.participantId),
        color: AppColors.surface,
        child: ListTile(
          title: Text(contact.name),
          subtitle: Text(contact.email),
          leading: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.accent,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit contact',
                onPressed: disabled
                    ? null
                    : () => _showContactDialog(
                        context,
                        workspaceId,
                        contact: contact,
                      ),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Remove contact',
                onPressed: disabled
                    ? null
                    : () => _showContactDialog(
                        context,
                        workspaceId,
                        contact: contact,
                        remove: true,
                      ),
                icon: const Icon(
                  Icons.person_remove_rounded,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _EmptyParticipants extends StatelessWidget {
  const _EmptyParticipants();
  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'No participants yet',
      style: TextStyle(color: AppColors.textSecondary),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
