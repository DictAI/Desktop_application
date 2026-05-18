import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';
import '../../workspace/data/dto/participant_dto.dart';
import '../../workspace/presentation/workspace_notifier.dart';
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

    // ── Проверка готовности воркспейса ─────────────────────────────────────
    String? blockReason;
    if (state.selectedWorkspaceId != null) {
      final detail =
          ref.watch(workspaceDetailProvider(state.selectedWorkspaceId!));
      if (detail.status == DetailStatus.loaded) {
        if (detail.participants.isEmpty) {
          blockReason = 'Add at least one participant to this workspace before recording.';
        } else {
          final missing = detail.participants
              .where((p) => detail.voiceProfileStatus[p.participantId] != true)
              .map((p) => p.name)
              .toList();
          if (missing.isNotEmpty) {
            blockReason = 'Voice profile missing for: ${missing.join(', ')}.\nGo to Workspaces to set them up.';
          }
        }
      }
    }

    final canRecord = blockReason == null && !state.isActive;

    return Row(
      children: [
        // ── Основной контент ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Кнопка записи + пауза ─────────────────────────────────
                  _RecordButton(
                    status: state.status,
                    onTap: state.isActive
                        ? () => notifier.toggleRecording()
                        : canRecord
                            ? () => notifier.toggleRecording()
                            : null,
                    onPause: state.isActive
                        ? () => notifier.togglePause()
                        : null,
                  ),
                  const SizedBox(height: 32),

                  // ── Статус ────────────────────────────────────────────────
                  _RecordStatusWidget(status: state.status),
                  const SizedBox(height: 32),

                  // ── Источник звука ────────────────────────────────────────
                  _AudioSourceToggle(
                    source: state.audioSource,
                    onChanged: notifier.setAudioSource,
                  ),
                  const SizedBox(height: 24),

                  // ── Выбор устройства (только для микрофона) ───────────────
                  if (state.audioSource == AudioSource.microphone ||
                      state.audioSource == AudioSource.systemAndMicrophone) ...[
                    _DeviceSelector(
                      devices: state.inputDevices,
                      selected: state.selectedDevice,
                      onSelect: notifier.selectDevice,
                      onRefresh: notifier.refreshDevices,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Выбор воркспейса ──────────────────────────────────────
                  _WorkspaceSelector(
                    selectedName: state.selectedWorkspaceName,
                    onSelect: (id, name) =>
                        notifier.selectWorkspace(id, name),
                    onClear: notifier.clearWorkspace,
                  ),

                  // ── Предупреждение о неполных профилях ────────────────────
                  if (blockReason != null && !state.isActive) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 360,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.errorSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                blockReason!,
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // ── Upload audio ──────────────────────────────────────────
                  _UploadAudioButton(
                    onTap: () => _showUploadModal(context),
                    isUploading: state.status == RecordStatus.uploading,
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
  final RecordStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onPause;

  const _RecordButton({
    required this.status,
    required this.onTap,
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

    final color = isRecording
        ? AppColors.error
        : isPaused
            ? AppColors.accent
            : isBlocked
                ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                : AppColors.surfaceElevated;

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
                              alpha: 0.4 * (1 - _pingController.value)),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceElevated),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
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

// ─────────────────────────────────────────────────────────────────────────────
// Статус под кнопкой
// ─────────────────────────────────────────────────────────────────────────────

class _RecordStatusWidget extends StatelessWidget {
  final RecordStatus status;
  const _RecordStatusWidget({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, sub) = switch (status) {
      RecordStatus.recording => ('Recording...', 'Tap stop to finish'),
      RecordStatus.paused    => ('Paused', 'Tap stop to finish & upload'),
      RecordStatus.uploading => ('Uploading...', ''),
      RecordStatus.done      => ('Upload complete', ''),
      RecordStatus.error     => ('', ''), // error shown in banner below
      _                      => ('Ready to Record', 'Tap the button to start'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Выбор воркспейса
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Переключатель источника звука
// ─────────────────────────────────────────────────────────────────────────────

class _AudioSourceToggle extends StatelessWidget {
  final AudioSource source;
  final void Function(AudioSource) onChanged;

  const _AudioSourceToggle({
    required this.source,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AUDIO SOURCE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceElevated),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _SourceOption(
                  label: 'Microphone',
                  icon: Icons.mic_rounded,
                  selected: source == AudioSource.microphone,
                  onTap: () => onChanged(AudioSource.microphone),
                ),
                _SourceOption(
                  label: 'System',
                  icon: Icons.speaker_rounded,
                  selected: source == AudioSource.systemAudio,
                  onTap: () => onChanged(AudioSource.systemAudio),
                ),
                _SourceOption(
                  label: 'Both',
                  icon: Icons.record_voice_over_rounded,
                  selected: source == AudioSource.systemAndMicrophone,
                  onTap: () => onChanged(AudioSource.systemAndMicrophone),
                ),
              ],
            ),
          ),
          if (source == AudioSource.systemAudio)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.accent),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Captures all audio playing on this Mac. '
                      'Requires "Screen & System Audio Recording" permission.',
                      style: TextStyle(
                          color: AppColors.accent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (source == AudioSource.systemAndMicrophone)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.accent),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Captures system audio and microphone simultaneously, '
                      'then mixes them into one file. '
                      'Requires "Screen & System Audio Recording" permission.',
                      style: TextStyle(
                          color: AppColors.accent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SourceOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  icon,
                  key: ValueKey(selected),
                  size: 14,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Выбор устройства записи
// ─────────────────────────────────────────────────────────────────────────────

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
                child: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (devices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceElevated),
              ),
              child: const Text(
                'No devices found — grant mic permission first',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
            )
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<InputDevice?>(
                value: selected,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary, size: 20),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15),
                hint: const Text(
                  'Default device',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 15),
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
                      child: Text(
                        d.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (_) => [
                  _deviceItem('Default device',
                      color: AppColors.textSecondary),
                  ...devices.map((d) => _deviceItem(d.label)),
                ],
                onChanged: onSelect,
              ),
            ),
          if (selected != null &&
              selected!.label.toLowerCase().contains('blackhole'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'BlackHole detected — system audio will be captured',
                    style: TextStyle(
                        color: AppColors.accent, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _deviceItem(String label,
      {Color color = AppColors.textPrimary}) {
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

// ─────────────────────────────────────────────────────────────────────────────

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
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _CreateWorkspaceDialog(
        onCreated: (id, name) => onSelect(id, name),
      ),
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
  ConsumerState<_WorkspaceDropdown> createState() =>
      _WorkspaceDropdownState();
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
                  : workspaces.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'No workspaces yet',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
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
                                    horizontal: 18, vertical: 12),
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
                                      const Icon(Icons.check_rounded,
                                          color: AppColors.accent, size: 16),
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
              'Uploaded successfully! Processing has started.',
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

// ─────────────────────────────────────────────────────────────────────────────
// Диалог создания воркспейса
// ─────────────────────────────────────────────────────────────────────────────

class _CreateWorkspaceDialog extends ConsumerStatefulWidget {
  final void Function(String id, String name) onCreated;
  const _CreateWorkspaceDialog({required this.onCreated});

  @override
  ConsumerState<_CreateWorkspaceDialog> createState() =>
      _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState
    extends ConsumerState<_CreateWorkspaceDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final ws = await ref
        .read(workspacesNotifierProvider.notifier)
        .create(_nameCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (ws != null) {
      widget.onCreated(ws.workspaceId, ws.name);
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
                  hintStyle:
                      const TextStyle(color: AppColors.textSecondary),
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
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
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
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        disabledBackgroundColor:
                            AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const Text(
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
