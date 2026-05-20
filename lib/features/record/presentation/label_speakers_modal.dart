import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../data/dto/anonymous_session_dto.dart';
import 'anonymous_record_notifier.dart';

class LabelSpeakersModal extends ConsumerStatefulWidget {
  const LabelSpeakersModal({super.key});

  @override
  ConsumerState<LabelSpeakersModal> createState() => _LabelSpeakersModalState();
}

class _LabelSpeakersModalState extends ConsumerState<LabelSpeakersModal> {
  final _workspaceNameCtrl = TextEditingController();
  final Map<String, TextEditingController> _nameCtrl = {};
  final Map<String, TextEditingController> _emailCtrl = {};
  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _playing = {};
  final Map<String, bool> _loadingAudio = {};

  @override
  void dispose() {
    _workspaceNameCtrl.dispose();
    for (final c in _nameCtrl.values) { c.dispose(); }
    for (final c in _emailCtrl.values) { c.dispose(); }
    for (final p in _players.values) { p.dispose(); }
    super.dispose();
  }

  void _initControllersFor(List<SpeakerDto> speakers) {
    for (final sp in speakers) {
      _nameCtrl.putIfAbsent(sp.speakerId, () => TextEditingController());
      _emailCtrl.putIfAbsent(sp.speakerId, () => TextEditingController());
      _players.putIfAbsent(sp.speakerId, () {
        final player = AudioPlayer();
        player.onPlayerStateChanged.listen((s) {
          if (mounted) {
            setState(() => _playing[sp.speakerId] = s == PlayerState.playing);
          }
        });
        return player;
      });
    }
  }

  bool get _allFilled {
    for (final ctrl in _nameCtrl.values) {
      if (ctrl.text.trim().isEmpty) return false;
    }
    for (final ctrl in _emailCtrl.values) {
      if (ctrl.text.trim().isEmpty) return false;
    }
    return _nameCtrl.isNotEmpty;
  }

  Future<void> _togglePlay(SpeakerDto speaker) async {
    final player = _players[speaker.speakerId]!;
    final isPlaying = _playing[speaker.speakerId] ?? false;

    if (isPlaying) {
      await player.pause();
      return;
    }

    setState(() => _loadingAudio[speaker.speakerId] = true);
    try {
      final api = ref.read(anonymousSessionApiProvider);
      final sessionId = ref.read(anonRecordNotifierProvider).sessionId!;
      final bytes = await api.getFragment(sessionId, speaker.speakerId);
      await player.play(BytesSource(Uint8List.fromList(bytes)));
    } catch (_) {
      // Silently fail — fragment unavailable
    } finally {
      if (mounted) setState(() => _loadingAudio[speaker.speakerId] = false);
    }
  }

  Future<void> _confirm() async {
    final session = ref.read(anonRecordNotifierProvider).session;
    if (session == null) return;

    final assignments = session.speakers.map((sp) {
      return SpeakerAssignment(
        label: sp.label,
        name: _nameCtrl[sp.speakerId]!.text.trim(),
        email: _emailCtrl[sp.speakerId]!.text.trim(),
      );
    }).toList();

    await ref.read(anonRecordNotifierProvider.notifier).confirm(
          workspaceName: _workspaceNameCtrl.text.trim().isEmpty
              ? null
              : _workspaceNameCtrl.text.trim(),
          assignments: assignments,
        );
  }

  @override
  Widget build(BuildContext context) {
    final anonState = ref.watch(anonRecordNotifierProvider);

    if (anonState.session != null) {
      _initControllersFor(anonState.session!.speakers);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceElevated),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, anonState),
              Flexible(child: _buildBody(anonState)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AnonState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceElevated),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Label Speakers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (state.status != AnonStatus.confirming)
            IconButton(
              onPressed: () {
                ref.read(anonRecordNotifierProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AnonState state) {
    return switch (state.status) {
      AnonStatus.recording => _buildRecording(),
      AnonStatus.uploading => _buildUploading(state.uploadProgress),
      AnonStatus.polling => _buildPolling(),
      AnonStatus.ready => _buildReady(state.session!),
      AnonStatus.confirming => _buildConfirming(),
      AnonStatus.done => _buildDone(),
      AnonStatus.error => _buildError(state.errorMessage ?? 'Unknown error'),
      _ => _buildPolling(),
    };
  }

  Widget _buildRecording() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: 0.15),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.5), width: 2),
            ),
            child: const Icon(Icons.mic_rounded,
                color: AppColors.error, size: 28),
          ),
          const SizedBox(height: 20),
          const Text(
            'Recording...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Stop when done',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref
                    .read(anonRecordNotifierProvider.notifier)
                    .stopAndUpload();
              },
              icon: const Icon(Icons.stop_rounded,
                  color: AppColors.textPrimary, size: 18),
              label: const Text(
                'Stop & Analyze',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploading(double progress) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Uploading... ${(progress * 100).toInt()}%',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPolling() {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Analyzing speakers...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'This may take a minute',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReady(AnonymousSessionDto session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...session.speakers.map((sp) => _buildSpeakerCard(sp)),
          const SizedBox(height: 20),
          _buildWorkspaceNameField(),
          const SizedBox(height: 20),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildSpeakerCard(SpeakerDto speaker) {
    final isPlaying = _playing[speaker.speakerId] ?? false;
    final isLoading = _loadingAudio[speaker.speakerId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: label + play button ──────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  speaker.label,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _togglePlay(speaker),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceHigh),
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.accent),
                        )
                      : Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Listen',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),

          // ── Preview text ─────────────────────────────────────────────────
          if (speaker.previewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"${speaker.previewText}"',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),

          // ── Name + Email fields ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: _nameCtrl[speaker.speakerId]!,
                  hint: 'Name',
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildField(
                  controller: _emailCtrl[speaker.speakerId]!,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1),
        ),
      ),
    );
  }

  Widget _buildWorkspaceNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WORKSPACE NAME (OPTIONAL)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _workspaceNameCtrl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Team Meeting',
            hintStyle:
                const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    final canConfirm = _allFilled;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: canConfirm ? _confirm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Confirm & Create Workspace',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirming() {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.accent),
          ),
          SizedBox(height: 20),
          Text(
            'Creating workspace...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.successSubtle,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workspace created',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Report is being generated. Check Results in a minute.',
                        style: TextStyle(
                            color: AppColors.success, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                ref.read(anonRecordNotifierProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4)),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                ref.read(anonRecordNotifierProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.surfaceElevated),
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
