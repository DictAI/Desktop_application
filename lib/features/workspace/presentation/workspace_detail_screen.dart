import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';
import '../data/dto/participant_dto.dart';
import '../../../features/voice_profile/data/dto/voice_profile_dto.dart';
import 'workspace_notifier.dart';

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
        DetailStatus.loaded => _DetailContent(
            state: state,
            notifier: notifier,
          ),
      },
    );
  }
}

// Основной контент

class _DetailContent extends StatelessWidget {
  final WorkspaceDetailState state;
  final WorkspaceDetailNotifier notifier;

  const _DetailContent({
    required this.state,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.folder_rounded,
                  color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ws.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: notifier.load,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary),
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

        _VoiceLibraryCard(profiles: state.voiceProfiles),
        const SizedBox(height: 24),

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
              onPressed: () => _showAddParticipantDialog(
                context,
                voiceProfiles: state.voiceProfiles,
                onAdd: ({required name, required email, voiceProfileId}) =>
                    notifier.addParticipant(
                  name: name,
                  email: email,
                  voiceProfileId: voiceProfileId,
                ),
              ),
              icon: const Icon(Icons.person_add_rounded,
                  size: 16, color: AppColors.accent),
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
        const SizedBox(height: 16),

        Expanded(
          child: state.participants.isEmpty
              ? const _EmptyParticipants()
              : _ParticipantList(
                  participants: state.participants,
                  voiceProfileStatus: state.voiceProfileStatus,
                  onDelete: (id) => notifier.deleteParticipant(id),
                  onVoiceProfile: (participant) => _showVoiceProfileDialog(
                    context,
                    participantId: participant.participantId,
                    participantName: participant.name,
                    voiceProfiles: state.voiceProfiles,
                    onAssign: (voiceProfileId) => notifier.assignVoiceProfile(
                      participantId: participant.participantId,
                      voiceProfileId: voiceProfileId,
                    ),
                    onUpload: (path) => notifier.uploadVoiceProfile(
                      participantId: participant.participantId,
                      audioPath: path,
                    ),
                  ),
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceLibraryCard extends StatefulWidget {
  final List<VoiceProfileDto> profiles;

  const _VoiceLibraryCard({required this.profiles});

  @override
  State<_VoiceLibraryCard> createState() => _VoiceLibraryCardState();
}

class _VoiceLibraryCardState extends State<_VoiceLibraryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profiles;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceElevated),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voice Library',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profiles.isEmpty
                              ? 'Saved voice profiles will appear here after recording a participant sample.'
                              : profiles
                                  .take(3)
                                  .map((p) => p.displayName)
                                  .join(' • '),
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
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${profiles.length}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _VoiceLibraryProfileList(profiles: profiles),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceLibraryProfileList extends StatelessWidget {
  final List<VoiceProfileDto> profiles;

  const _VoiceLibraryProfileList({required this.profiles});

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No saved profiles yet. Record a participant sample to add the first one.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: profiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final createdAt =
              profile.createdAt?.toLocal().toString().split('.').first;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: AppColors.accent,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Created $createdAt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VoiceProfilePicker extends StatelessWidget {
  final List<VoiceProfileDto> profiles;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String hint;

  const _VoiceProfilePicker({
    required this.profiles,
    required this.value,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value ?? '',
      isExpanded: true,
      dropdownColor: AppColors.surface,
      iconEnabledColor: AppColors.textSecondary,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(
            hint,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ...profiles.map(
          (profile) => DropdownMenuItem(
            value: profile.voiceProfileId,
            child: Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (next) =>
          onChanged(next == null || next.isEmpty ? null : next),
    );
  }
}

// Диалог добавления участника

void _showVoiceProfileDialog(
  BuildContext context, {
  required String participantId,
  required String participantName,
  required List<VoiceProfileDto> voiceProfiles,
  required Future<bool> Function(String voiceProfileId) onAssign,
  required Future<bool> Function(String audioPath) onUpload,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _VoiceProfileDialog(
      participantId: participantId,
      participantName: participantName,
      profiles: voiceProfiles,
      onAssign: onAssign,
      onUpload: onUpload,
    ),
  );
}

// Диалог записи голосового профиля

class _VoiceProfileDialog extends StatefulWidget {
  final String participantId;
  final String participantName;
  final List<VoiceProfileDto> profiles;
  final Future<bool> Function(String voiceProfileId) onAssign;
  final Future<bool> Function(String audioPath) onUpload;

  const _VoiceProfileDialog({
    required this.participantId,
    required this.participantName,
    required this.profiles,
    required this.onAssign,
    required this.onUpload,
  });

  @override
  State<_VoiceProfileDialog> createState() => _VoiceProfileDialogState();
}

enum _VoiceDialogStep { idle, recording, uploading, done, error }

class _VoiceProfileDialogState extends State<_VoiceProfileDialog>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  _VoiceDialogStep _step = _VoiceDialogStep.idle;
  String? _recordedPath;
  String? _errorMsg;
  String? _selectedVoiceProfileId;
  bool _assigning = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.profiles.isNotEmpty) {
      _selectedVoiceProfileId = widget.profiles.first.voiceProfileId;
    }
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      setState(() {
        _step = _VoiceDialogStep.error;
        _errorMsg = 'Microphone permission denied.';
      });
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_profile_${widget.participantId}_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
          encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    setState(() {
      _step = _VoiceDialogStep.recording;
      _recordedPath = path;
    });
    _pulseCtrl.repeat();
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() => _step = _VoiceDialogStep.idle);
  }

  Future<void> _upload() async {
    if (_recordedPath == null) return;
    setState(() => _step = _VoiceDialogStep.uploading);
    final ok = await widget.onUpload(_recordedPath!);
    if (!mounted) return;
    try {
      await File(_recordedPath!).delete();
    } catch (_) {}
    setState(() {
      _step = ok ? _VoiceDialogStep.done : _VoiceDialogStep.error;
      if (!ok) _errorMsg = 'Upload failed. Try again.';
    });
  }

  Future<void> _assignSelected() async {
    final selected = _selectedVoiceProfileId;
    if (selected == null) return;
    setState(() => _assigning = true);
    final ok = await widget.onAssign(selected);
    if (!mounted) return;
    setState(() {
      _assigning = false;
      _step = ok ? _VoiceDialogStep.done : _VoiceDialogStep.error;
      if (!ok) _errorMsg = 'Could not assign this voice profile.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voice Profile',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _step == _VoiceDialogStep.uploading
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _VoiceDialogStep.done => _buildDone(),
      _VoiceDialogStep.error => _buildError(),
      _ => _buildRecorder(),
    };
  }

  Widget _buildDone() {
    return Column(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Voice profile saved!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Done',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text(
          _errorMsg ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _step = _VoiceDialogStep.idle;
              _errorMsg = null;
              _recordedPath = null;
            }),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.surfaceElevated),
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryAssignment() {
    if (widget.profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Assign an existing voice to ${widget.participantName}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _VoiceProfilePicker(
          profiles: widget.profiles,
          value: _selectedVoiceProfileId,
          hint: 'Choose voice profile',
          onChanged: (value) => setState(() => _selectedVoiceProfileId = value),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _assigning || _selectedVoiceProfileId == null
                ? null
                : _assignSelected,
            icon: _assigning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(Icons.link_rounded, size: 16),
            label: const Text('Use Selected Voice'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.surfaceElevated),
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: Divider(color: AppColors.surfaceElevated)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'or record a new sample',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: AppColors.surfaceElevated)),
          ],
        ),
      ],
    );
  }

  Widget _buildRecorder() {
    final isRecording = _step == _VoiceDialogStep.recording;
    final hasRecording =
        _recordedPath != null && _step == _VoiceDialogStep.idle;
    final isUploading = _step == _VoiceDialogStep.uploading;

    return Column(
      children: [
        _buildLibraryAssignment(),
        if (widget.profiles.isNotEmpty) const SizedBox(height: 24),
        const Text(
          'Record a short sample of the participant speaking '
          '(10–30 seconds). Speak clearly.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),

        // Pulse + mic button
        GestureDetector(
          onTap: isUploading
              ? null
              : (isRecording ? _stopRecording : _startRecording),
          child: SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isRecording)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 100 + _pulseCtrl.value * 20,
                      height: 100 + _pulseCtrl.value * 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.error
                              .withValues(alpha: 0.5 * (1 - _pulseCtrl.value)),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRecording
                        ? AppColors.error
                        : hasRecording
                            ? AppColors.success
                            : AppColors.surfaceElevated,
                  ),
                  child: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 36,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            isRecording
                ? 'Recording… tap to stop'
                : hasRecording
                    ? 'Recording ready'
                    : 'Tap to start recording',
            key: ValueKey(_step),
            style: TextStyle(
              color: isRecording
                  ? AppColors.error
                  : hasRecording
                      ? AppColors.success
                      : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Кнопки действий
        if (!isRecording) ...[
          Row(
            children: [
              if (hasRecording)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUploading ? null : () => _startRecording(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Re-record'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surfaceElevated),
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              if (hasRecording) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: hasRecording && !isUploading ? _upload : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Text(
                          'Save Profile',
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
      ],
    );
  }
}

void _showAddParticipantDialog(
  BuildContext context, {
  required List<VoiceProfileDto> voiceProfiles,
  required Future<bool> Function({
    required String name,
    required String email,
    String? voiceProfileId,
  }) onAdd,
}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _AddParticipantDialog(
      voiceProfiles: voiceProfiles,
      onAdd: onAdd,
    ),
  );
}

class _AddParticipantDialog extends StatefulWidget {
  final List<VoiceProfileDto> voiceProfiles;
  final Future<bool> Function({
    required String name,
    required String email,
    String? voiceProfileId,
  }) onAdd;

  const _AddParticipantDialog({
    required this.voiceProfiles,
    required this.onAdd,
  });

  @override
  State<_AddParticipantDialog> createState() => _AddParticipantDialogState();
}

class _AddParticipantDialogState extends State<_AddParticipantDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedVoiceProfileId;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final ok = await widget.onAdd(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      voiceProfileId: _selectedVoiceProfileId,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.of(context).pop();
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
                    'Add Participant',
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
              _ParticipantField(
                controller: _nameCtrl,
                hint: 'Full name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              _ParticipantField(
                controller: _emailCtrl,
                hint: 'Email address',
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _submit(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              if (widget.voiceProfiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                _VoiceProfilePicker(
                  profiles: widget.voiceProfiles,
                  value: _selectedVoiceProfileId,
                  hint: 'No voice profile yet',
                  onChanged: (value) =>
                      setState(() => _selectedVoiceProfileId = value),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: AppColors.surfaceElevated),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        disabledBackgroundColor: AppColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                              'Add',
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

class _ParticipantField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;

  const _ParticipantField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
      ),
    );
  }
}

// Список участников

class _ParticipantList extends StatelessWidget {
  final List<ParticipantDto> participants;
  final Map<String, bool> voiceProfileStatus;
  final Future<bool> Function(String participantId) onDelete;
  final void Function(ParticipantDto participant) onVoiceProfile;

  const _ParticipantList({
    required this.participants,
    required this.voiceProfileStatus,
    required this.onDelete,
    required this.onVoiceProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ParticipantTile(
        participant: participants[i],
        hasVoiceProfile: voiceProfileStatus[participants[i].participantId],
        onDelete: () => onDelete(participants[i].participantId),
        onVoiceProfile: () => onVoiceProfile(participants[i]),
      ),
    );
  }
}

class _ParticipantTile extends StatefulWidget {
  final ParticipantDto participant;
  final bool? hasVoiceProfile;
  final Future<bool> Function() onDelete;
  final VoidCallback onVoiceProfile;

  const _ParticipantTile({
    required this.participant,
    required this.hasVoiceProfile,
    required this.onDelete,
    required this.onVoiceProfile,
  });

  @override
  State<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<_ParticipantTile> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceElevated),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_remove_rounded,
                  color: AppColors.error, size: 36),
              const SizedBox(height: 16),
              Text(
                'Remove ${widget.participant.name}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will remove them from the workspace.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side:
                            const BorderSide(color: AppColors.surfaceElevated),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Remove',
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
    if (ok == true && mounted) {
      setState(() => _deleting = true);
      await widget.onDelete();
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.participant;
    final initials = participant.name.isNotEmpty
        ? participant.name
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return AnimatedOpacity(
      opacity: _deleting ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    participant.email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_deleting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.error),
              )
            else ...[
              // Кнопка голосового профиля
              GestureDetector(
                onTap: widget.onVoiceProfile,
                child: Tooltip(
                  message: widget.hasVoiceProfile == true
                      ? 'Change voice profile'
                      : 'Add voice profile',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.hasVoiceProfile == true
                          ? AppColors.accentSubtle
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: widget.hasVoiceProfile == null
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.textSecondary),
                          )
                        : Icon(
                            widget.hasVoiceProfile == true
                                ? Icons.record_voice_over_rounded
                                : Icons.voice_over_off_rounded,
                            color: widget.hasVoiceProfile == true
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            size: 16,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Кнопка удаления
              GestureDetector(
                onTap: _confirmDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.errorSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_remove_rounded,
                      color: AppColors.error, size: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Вспомогательные виджеты

class _EmptyParticipants extends StatelessWidget {
  const _EmptyParticipants();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.people_outline_rounded,
                color: AppColors.textSecondary, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No participants yet',
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
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 16),
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
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
