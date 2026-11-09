import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';
import '../../workspace/presentation/workspace_notifier.dart';
import '../../workspace/presentation/workspaces_screen.dart';
import '../../workspace/data/dto/workspace_dto.dart';
import 'record_notifier.dart';
import 'upload_modal.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key, this.workspaceId, this.workspace});
  final String? workspaceId;
  final WorkspaceDto? workspace;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  bool _confirmingStop = false;

  @override
  void initState() {
    super.initState();
    _scheduleWorkspaceContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recordNotifierProvider.notifier).refreshDevices();
    });
  }

  @override
  void didUpdateWidget(covariant RecordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.workspace != widget.workspace) {
      _scheduleWorkspaceContext();
    }
  }

  void _scheduleWorkspaceContext() {
    final id = widget.workspaceId;
    final workspace = widget.workspace;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          id != widget.workspaceId ||
          workspace != widget.workspace) {
        return;
      }
      final notifier = ref.read(recordNotifierProvider.notifier);
      if (notifier.hasActiveOperation) {
        notifier.setWorkspaceContextError(
          'Сначала завершите активную запись или отправку. Выбранное рабочее пространство не изменено.',
        );
        return;
      }
      if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(id) ||
          workspace == null ||
          workspace.workspaceId != id) {
        notifier.setWorkspaceContextError(
          'Контекст рабочего пространства не подтверждён. Откройте его и нажмите «Новая запись».',
        );
        return;
      }
      notifier.selectWorkspace(id, workspace.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordNotifierProvider);
    final notifier = ref.read(recordNotifierProvider.notifier);
    final locked = state.controlsLocked;
    final canRecord =
        !locked && (state.anonymous || state.selectedWorkspaceId != null);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnorePointer(
              ignoring: locked,
              child: _AnonymousToggle(
                value: state.anonymous,
                onChanged: notifier.setAnonymous,
              ),
            ),
            const SizedBox(height: 28),

            _RecordButton(
              status: state.status,
              anonymous: state.anonymous,
              onTap: state.isActive
                  ? () => _handleStop(notifier)
                  : canRecord
                  ? notifier.startRecording
                  : null,
              onPause:
                  (state.isActive && notifier.supportsPause && !_confirmingStop)
                  ? () => notifier.togglePause()
                  : null,
            ),
            const SizedBox(height: 32),

            _RecordStatusWidget(status: state.status),
            const SizedBox(height: 32),

            IgnorePointer(
              ignoring: locked,
              child: _DeviceSelector(
                devices: state.inputDevices,
                selected: state.selectedDevice,
                onSelect: notifier.selectDevice,
                onRefresh: notifier.refreshDevices,
              ),
            ),
            const SizedBox(height: 16),

            IgnorePointer(
              ignoring: locked,
              child: _SystemAudioCheckbox(
                value: state.captureSystemAudio,
                onChanged: notifier.setCaptureSystemAudio,
              ),
            ),
            const SizedBox(height: 24),

            AnimatedOpacity(
              opacity: state.anonymous ? 0.3 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: state.anonymous || locked,
                child: _WorkspaceSelector(
                  selectedName: state.selectedWorkspaceName,
                  onSelect: notifier.selectWorkspace,
                  onClear: notifier.clearWorkspace,
                ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: 360,
              child: UploadLanguageControls(
                language: state.language,
                mixed: state.mixed,
                onLanguage: locked ? null : notifier.setLanguage,
                onMixed: locked ? null : notifier.setMixed,
              ),
            ),

            const SizedBox(height: 32),

            if (state.anonymous || state.selectedWorkspaceId != null)
              _UploadAudioButton(
                onTap: locked ? null : () => _showUploadModal(context),
                isUploading: state.status == RecordStatus.uploading,
              ),

            if (state.status == RecordStatus.uploading) ...[
              const SizedBox(height: 20),
              _UploadProgressBar(progress: state.uploadProgress),
            ],

            if (state.status == RecordStatus.accepted) ...[
              const SizedBox(height: 20),
              _UploadSuccess(onReset: notifier.reset),
            ],
            if (state.canRetryUpload)
              TextButton(
                onPressed: locked ? null : notifier.retryUpload,
                child: const Text('Повторить сохранённую отправку'),
              ),

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
    );
  }

  Future<void> _handleStop(RecordNotifier notifier) async {
    final identity = notifier.recordingIdentity;
    if (_confirmingStop || identity == null) return;
    setState(() => _confirmingStop = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Завершить запись?'),
          content: const Text('Готовый WAV будет отправлен на обработку.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Продолжить запись'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Завершить и отправить'),
            ),
          ],
        ),
      );
      if (mounted &&
          confirmed == true &&
          identical(identity, notifier.recordingIdentity)) {
        await notifier.finishRecording(confirmed: true);
      }
    } finally {
      if (mounted) setState(() => _confirmingStop = false);
    }
  }

  void _showUploadModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const UploadModal(),
    );
  }
}

// Тумблер анонимного режима

class _AnonymousToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AnonymousToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: value ? AppColors.accentSubtle : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : AppColors.surfaceElevated,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_off_rounded,
                size: 16,
                color: value ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Без рабочего пространства',
                      style: TextStyle(
                        color: value ? AppColors.accent : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Запись и результаты видны только вам',
                      style: TextStyle(
                        color: value
                            ? AppColors.accent.withValues(alpha: 0.7)
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: value ? AppColors.accent : AppColors.surfaceElevated,
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Кнопка записи

class _RecordButton extends StatefulWidget {
  final RecordStatus status;
  final bool anonymous;
  final VoidCallback? onTap;
  final VoidCallback? onPause;

  const _RecordButton({
    required this.status,
    required this.onTap,
    this.anonymous = false,
    this.onPause,
  });

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
    if (widget.status == RecordStatus.recording &&
        !_pingController.isAnimating) {
      _pingController.repeat();
    } else if (widget.status != RecordStatus.recording) {
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
    final isRecording = widget.status == RecordStatus.recording;
    final isPaused = widget.status == RecordStatus.paused;
    final isActive = isRecording || isPaused;
    final isBlocked = widget.onTap == null && !isActive;

    final idleColor = widget.anonymous
        ? AppColors.accent.withValues(alpha: 0.25)
        : AppColors.surfaceElevated;

    final color = isRecording
        ? AppColors.error
        : isPaused
        ? AppColors.accent
        : isBlocked
        ? AppColors.surfaceElevated.withValues(alpha: 0.5)
        : idleColor;

    return Column(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isRecording)
                  AnimatedBuilder(
                    animation: _pingController,
                    builder: (_, __) => Container(
                      width: 192 + _pingController.value * 40,
                      height: 192 + _pingController.value * 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.error.withValues(
                            alpha: 0.4 * (1 - _pingController.value),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
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
                    isActive ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 80,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Кнопка паузы — только когда идёт запись или на паузе
        if (isActive && widget.onPause != null) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onPause,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceElevated),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPaused ? 'Resume' : 'Pause',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Статус под кнопкой

class _RecordStatusWidget extends StatelessWidget {
  final RecordStatus status;
  const _RecordStatusWidget({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, sub) = switch (status) {
      RecordStatus.recording => ('Recording...', 'Tap stop to finish'),
      RecordStatus.paused => ('Paused', 'Tap stop to finish & upload'),
      RecordStatus.uploading => ('Uploading...', ''),
      RecordStatus.starting => ('Подготовка записи…', ''),
      RecordStatus.preparing => ('Подготовка WAV…', ''),
      RecordStatus.accepted => ('Отправка принята', 'Ожидание обработки'),
      RecordStatus.error => ('', ''), // error shown in banner below
      _ => ('Ready to Record', 'Tap the button to start'),
    };

    if (label.isEmpty) return const SizedBox.shrink();

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

// Выбор воркспейса

// Переключатель источника звука

class _SystemAudioCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SystemAudioCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.surfaceElevated,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: value ? AppColors.accent : AppColors.textSecondary,
                    width: 1.5,
                  ),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.speaker_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Also capture system audio',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Выбор устройства записи

class _DeviceSelector extends StatelessWidget {
  final List<InputDevice> devices;
  final InputDevice? selected;
  final void Function(InputDevice?) onSelect;
  final VoidCallback onRefresh;

  const _DeviceSelector({
    required this.devices,
    required this.selected,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'INPUT DEVICE',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRefresh,
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (devices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceElevated),
              ),
              child: const Text(
                'No devices found — grant mic permission first',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            )
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<InputDevice?>(
                value: selected,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                ),
                hint: const Text(
                  'Default device',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                items: [
                  const DropdownMenuItem<InputDevice?>(
                    value: null,
                    child: Text(
                      'Default device',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  ...devices.map(
                    (d) => DropdownMenuItem<InputDevice?>(
                      value: d,
                      child: Text(d.label, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                selectedItemBuilder: (_) => [
                  _deviceItem('Default device', color: AppColors.textSecondary),
                  ...devices.map((d) => _deviceItem(d.label)),
                ],
                onChanged: onSelect,
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: AppColors.accent,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'BlackHole detected — system audio will be captured',
                    style: TextStyle(color: AppColors.accent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceItem(String label, {Color color = AppColors.textPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 15),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _WorkspaceSelector extends ConsumerWidget {
  final String? selectedName;
  final void Function(String id, String name) onSelect;
  final VoidCallback onClear;

  const _WorkspaceSelector({
    required this.selectedName,
    required this.onSelect,
    required this.onClear,
  });

  void _showCreateWorkspaceDialog(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(workspacesNotifierProvider.notifier);
    showWorkspaceNameDialog(
      context,
      title: 'New Workspace',
      actionLabel: 'Create',
      onSubmit: (name) async {
        final workspace = await notifier.create(name);
        if (workspace == null) return false;
        onSelect(workspace.workspaceId, workspace.name);
        return true;
      },
      errorMessage: () => notifier.errorMessage,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              _IconSquareButton(
                icon: Icons.add_rounded,
                onTap: () => _showCreateWorkspaceDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDropdown extends ConsumerStatefulWidget {
  final String? selectedName;
  final void Function(String id, String name) onSelect;
  final VoidCallback onClear;

  const _WorkspaceDropdown({
    required this.selectedName,
    required this.onSelect,
    required this.onClear,
  });

  @override
  ConsumerState<_WorkspaceDropdown> createState() => _WorkspaceDropdownState();
}

class _WorkspaceDropdownState extends ConsumerState<_WorkspaceDropdown> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final workspacesState = ref.watch(workspacesNotifierProvider);
    final workspaces = workspacesState.workspaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 4),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceElevated),
              ),
              child: workspacesState.status == WorkspacesStatus.loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : workspacesState.status == WorkspacesStatus.error
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Text(
                            workspacesState.errorMessage ??
                                'Не удалось загрузить рабочие пространства.',
                          ),
                          TextButton(
                            onPressed: ref
                                .read(workspacesNotifierProvider.notifier)
                                .load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : workspaces.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'No workspaces yet',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Column(
                      children: workspaces.map((ws) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            widget.onSelect(ws.workspaceId, ws.name);
                            setState(() => _open = false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ws.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (widget.selectedName == ws.name)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: AppColors.accent,
                                    size: 16,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ],
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

// Кнопка загрузки файла

class _UploadAudioButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isUploading;

  const _UploadAudioButton({required this.onTap, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.upload_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
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

// Прогресс-бар загрузки

class _UploadProgressBar extends StatelessWidget {
  final double? progress;
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
          if (progress case final value?)
            Text(
              '${(value * 100).toInt()}%',
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

// Успешная загрузка

class _UploadSuccess extends StatelessWidget {
  final VoidCallback onReset;

  const _UploadSuccess({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Сервер принял WAV. Результат появится после обработки.',
              style: TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onReset,
            child: const Icon(
              Icons.close_rounded,
              color: AppColors.success,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// Баннер ошибки

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
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
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
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
