import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'record_notifier.dart';
import 'upload_modal.dart';
import 'chat_panel.dart';

/// React-аналог: RecordPage.tsx
/// Изменения при переносе:
///  - useState(isRecording) → RecordNotifier.toggleRecording()
///  - useState(selectedWorkspace) → RecordNotifier.selectWorkspace()
///  - UploadModal как Dialog через showDialog()
///  - ChatPanel — отдельный виджет справа
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordNotifierProvider);
    final notifier = ref.read(recordNotifierProvider.notifier);
    final isRecording = state.status == RecordStatus.recording;

    return Row(
      children: [
        // ── Основной контент ───────────────────────────────────────────────
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Кнопка записи ─────────────────────────────────────────
                  _RecordButton(
                    isRecording: isRecording,
                    onTap: notifier.toggleRecording,
                  ),
                  const SizedBox(height: 32),

                  // ── Статус ────────────────────────────────────────────────
                  _RecordStatus(status: state.status),
                  const SizedBox(height: 48),

                  // ── Выбор воркспейса ──────────────────────────────────────
                  _WorkspaceSelector(
                    selectedName: state.selectedWorkspaceName,
                    onSelect: (id, name) =>
                        notifier.selectWorkspace(id, name),
                    onClear: notifier.clearWorkspace,
                  ),
                  const SizedBox(height: 32),

                  // ── Upload audio ──────────────────────────────────────────
                  _UploadAudioButton(
                    onTap: () => _showUploadModal(context),
                    isUploading:
                        state.status == RecordStatus.uploading,
                  ),

                  // ── Прогресс загрузки ─────────────────────────────────────
                  if (state.status == RecordStatus.uploading) ...[
                    const SizedBox(height: 20),
                    _UploadProgressBar(progress: state.uploadProgress),
                  ],

                  // ── Успех ─────────────────────────────────────────────────
                  if (state.status == RecordStatus.done) ...[
                    const SizedBox(height: 20),
                    _UploadSuccess(
                      audioId: state.uploadedAudioId!,
                      onReset: notifier.reset,
                    ),
                  ],

                  // ── Ошибка ────────────────────────────────────────────────
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _ErrorBanner(
                      message: state.errorMessage!,
                      onDismiss: notifier.reset,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Chat Panel ─────────────────────────────────────────────────────
        Container(
          width: 360,
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const ChatPanel(),
        ),
      ],
    );
  }

  void _showUploadModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const UploadModal(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка записи
// ─────────────────────────────────────────────────────────────────────────────

class _RecordButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const _RecordButton({required this.isRecording, required this.onTap});

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pingController;

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didUpdateWidget(_RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !_pingController.isAnimating) {
      _pingController.repeat();
    } else if (!widget.isRecording) {
      _pingController.stop();
      _pingController.reset();
    }
  }

  @override
  void dispose() {
    _pingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isRecording ? AppColors.error : AppColors.surfaceElevated;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ping-кольцо (только при записи)
          if (widget.isRecording)
            AnimatedBuilder(
              animation: _pingController,
              builder: (_, __) => Container(
                width: 192 + _pingController.value * 40,
                height: 192 + _pingController.value * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.error
                        .withValues(alpha: 0.4 * (1 - _pingController.value)),
                    width: 2,
                  ),
                ),
              ),
            ),
          // Основная кнопка
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              widget.isRecording
                  ? Icons.stop_rounded
                  : Icons.mic_rounded,
              size: 80,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Статус под кнопкой
// ─────────────────────────────────────────────────────────────────────────────

class _RecordStatus extends StatelessWidget {
  final RecordStatus status;
  const _RecordStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, sub) = switch (status) {
      RecordStatus.recording => ('Recording...', ''),
      RecordStatus.uploading => ('Uploading...', ''),
      RecordStatus.done      => ('Upload complete', ''),
      RecordStatus.error     => ('Something went wrong', ''),
      _                      => ('Ready to Record', 'Tap the button to start'),
    };

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Выбор воркспейса
// ─────────────────────────────────────────────────────────────────────────────

class _WorkspaceSelector extends StatelessWidget {
  final String? selectedName;
  final void Function(String id, String name) onSelect;
  final VoidCallback onClear;

  const _WorkspaceSelector({
    required this.selectedName,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHOOSE YOUR WORKSPACE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WorkspaceDropdown(
                  selectedName: selectedName,
                  onSelect: onSelect,
                  onClear: onClear,
                ),
              ),
              const SizedBox(width: 10),
              // Кнопка "создать новый воркспейс"
              _IconSquareButton(
                icon: Icons.add_rounded,
                onTap: () {
                  // TODO: показать диалог создания воркспейса
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDropdown extends StatefulWidget {
  final String? selectedName;
  final void Function(String id, String name) onSelect;
  final VoidCallback onClear;

  const _WorkspaceDropdown({
    required this.selectedName,
    required this.onSelect,
    required this.onClear,
  });

  @override
  State<_WorkspaceDropdown> createState() => _WorkspaceDropdownState();
}

class _WorkspaceDropdownState extends State<_WorkspaceDropdown> {
  bool _open = false;

  // TODO(backend): заменить на реальные данные из WorkspacesNotifier
  // после реализации GET /workspaces/ (см. MISSING_ENDPOINTS.md п.1)
  // ignore: unused_field
  static const _stubWorkspaces = [
    ('stub-1', 'Personal'),
    ('stub-2', 'Work'),
    ('stub-3', 'Projects'),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _open = !_open);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.selectedName ?? 'Not selected',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconSquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Кнопка загрузки файла
// ─────────────────────────────────────────────────────────────────────────────

class _UploadAudioButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isUploading;

  const _UploadAudioButton(
      {required this.onTap, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_rounded,
                color: AppColors.textPrimary, size: 18),
            const SizedBox(width: 8),
            Text(
              isUploading ? 'Uploading...' : 'Upload Audio',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Прогресс-бар загрузки
// ─────────────────────────────────────────────────────────────────────────────

class _UploadProgressBar extends StatelessWidget {
  final double progress;
  const _UploadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Успешная загрузка
// ─────────────────────────────────────────────────────────────────────────────

class _UploadSuccess extends StatelessWidget {
  final String audioId;
  final VoidCallback onReset;

  const _UploadSuccess({required this.audioId, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Uploaded successfully · ID: $audioId',
              style: const TextStyle(
                  color: AppColors.success, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onReset,
            child: const Icon(Icons.close_rounded,
                color: AppColors.success, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Баннер ошибки
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }
}
