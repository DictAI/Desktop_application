import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';
import '../data/anonymous_session_api.dart';
import '../data/dto/anonymous_session_dto.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum AnonStatus {
  idle,
  recording,
  uploading,
  polling,
  ready,
  confirming,
  done,
  error,
}

class AnonState {
  final AnonStatus status;
  final String? sessionId;
  final AnonymousSessionDto? session;
  final String? errorMessage;
  final double uploadProgress;

  const AnonState({
    this.status = AnonStatus.idle,
    this.sessionId,
    this.session,
    this.errorMessage,
    this.uploadProgress = 0,
  });

  bool get isActive =>
      status == AnonStatus.recording;

  AnonState copyWith({
    AnonStatus? status,
    String? sessionId,
    AnonymousSessionDto? session,
    String? errorMessage,
    double? uploadProgress,
  }) =>
      AnonState(
        status: status ?? this.status,
        sessionId: sessionId ?? this.sessionId,
        session: session ?? this.session,
        errorMessage: errorMessage ?? this.errorMessage,
        uploadProgress: uploadProgress ?? this.uploadProgress,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AnonRecordNotifier extends StateNotifier<AnonState> {
  final AnonymousSessionApi _api;
  final AudioRecorder _recorder = AudioRecorder();

  Timer? _pollTimer;
  String? _recordingPath;

  AnonRecordNotifier(this._api) : super(const AnonState());

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> startRecording({InputDevice? device}) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(
        status: AnonStatus.error,
        errorMessage: 'Microphone permission denied.\n'
            'Please grant microphone access in your system settings.',
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final isLinux = !kIsWeb && Platform.isLinux;
    final ext = isLinux ? 'ogg' : 'm4a';
    _recordingPath =
        '${dir.path}/anon_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _recorder.start(
      RecordConfig(
        encoder: isLinux ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        device: device,
      ),
      path: _recordingPath!,
    );

    state = state.copyWith(status: AnonStatus.recording);
  }

  Future<void> stopAndUpload() async {
    final path = await _recorder.stop() ?? _recordingPath;
    _recordingPath = null;

    if (path == null) {
      state = state.copyWith(
        status: AnonStatus.error,
        errorMessage: 'Recording failed: no output file.',
      );
      return;
    }

    await _uploadFile(File(path));
  }

  Future<void> uploadPickedFile(File file) => _uploadFile(file);

  Future<void> _uploadFile(File file) async {
    state = state.copyWith(
      status: AnonStatus.uploading,
      uploadProgress: 0,
      errorMessage: null,
    );

    try {
      final result = await _api.uploadAnonymous(
        audioFile: file,
        onProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(uploadProgress: sent / total);
          }
        },
      );

      state = state.copyWith(
        status: AnonStatus.polling,
        sessionId: result.sessionId,
        uploadProgress: 1,
      );

      _startPolling(result.sessionId);
    } on AppException catch (e) {
      state = state.copyWith(status: AnonStatus.error, errorMessage: e.message);
    }
  }

  // ── Polling ───────────────────────────────────────────────────────────────

  void _startPolling(String sessionId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final session = await _api.getSession(sessionId);
        if (session.isReady) {
          _pollTimer?.cancel();
          state = state.copyWith(status: AnonStatus.ready, session: session);
        } else if (session.isExpired) {
          _pollTimer?.cancel();
          state = state.copyWith(
            status: AnonStatus.error,
            errorMessage: 'Session expired before processing completed.',
          );
        }
      } on AppException catch (e) {
        _pollTimer?.cancel();
        state = state.copyWith(status: AnonStatus.error, errorMessage: e.message);
      }
    });
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  Future<void> confirm({
    required String? workspaceName,
    required List<SpeakerAssignment> assignments,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    state = state.copyWith(status: AnonStatus.confirming, errorMessage: null);

    try {
      await _api.confirm(
        sessionId: sessionId,
        workspaceName: workspaceName,
        speakers: assignments,
      );
      state = state.copyWith(status: AnonStatus.done);
    } on AppException catch (e) {
      state = state.copyWith(status: AnonStatus.error, errorMessage: e.message);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void reset() {
    _pollTimer?.cancel();
    state = const AnonState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final anonRecordNotifierProvider =
    StateNotifierProvider<AnonRecordNotifier, AnonState>((ref) {
  return AnonRecordNotifier(ref.read(anonymousSessionApiProvider));
});
