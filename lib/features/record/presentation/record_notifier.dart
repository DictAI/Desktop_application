import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';
import '../data/audio_ingest_api.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum RecordStatus { idle, recording, uploading, done, error }

class RecordState {
  final RecordStatus status;
  final String? selectedWorkspaceId;
  final String? selectedWorkspaceName;
  final String? uploadedAudioId;
  final String? errorMessage;
  final double uploadProgress; // 0.0 – 1.0

  const RecordState({
    this.status = RecordStatus.idle,
    this.selectedWorkspaceId,
    this.selectedWorkspaceName,
    this.uploadedAudioId,
    this.errorMessage,
    this.uploadProgress = 0,
  });

  RecordState copyWith({
    RecordStatus? status,
    String? selectedWorkspaceId,
    String? selectedWorkspaceName,
    String? uploadedAudioId,
    String? errorMessage,
    double? uploadProgress,
  }) =>
      RecordState(
        status: status ?? this.status,
        selectedWorkspaceId:
            selectedWorkspaceId ?? this.selectedWorkspaceId,
        selectedWorkspaceName:
            selectedWorkspaceName ?? this.selectedWorkspaceName,
        uploadedAudioId: uploadedAudioId ?? this.uploadedAudioId,
        errorMessage: errorMessage ?? this.errorMessage,
        uploadProgress: uploadProgress ?? this.uploadProgress,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class RecordNotifier extends StateNotifier<RecordState> {
  final AudioIngestApi _api;

  RecordNotifier(this._api) : super(const RecordState());

  void selectWorkspace(String id, String name) {
    state = state.copyWith(
      selectedWorkspaceId: id,
      selectedWorkspaceName: name,
    );
  }

  void clearWorkspace() {
    state = state.copyWith(
      selectedWorkspaceId: null,
      selectedWorkspaceName: null,
    );
  }

  void toggleRecording() {
    if (state.status == RecordStatus.recording) {
      // TODO: остановить реальную запись (будет подключён плагин)
      state = state.copyWith(status: RecordStatus.idle);
    } else {
      state = state.copyWith(status: RecordStatus.recording);
    }
  }

  Future<void> uploadFile(File file) async {
    state = state.copyWith(
      status: RecordStatus.uploading,
      uploadProgress: 0,
      errorMessage: null,
    );
    try {
      final audioId = await _api.uploadAudio(
        workspaceId: state.selectedWorkspaceId ?? '',
        audioFile: file,
        onProgress: (sent, total) {
          if (total > 0) {
            state =
                state.copyWith(uploadProgress: sent / total);
          }
        },
      );
      state = state.copyWith(
        status: RecordStatus.done,
        uploadedAudioId: audioId,
        uploadProgress: 1,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: e.message,
      );
    }
  }

  void reset() => state = RecordState(
        selectedWorkspaceId: state.selectedWorkspaceId,
        selectedWorkspaceName: state.selectedWorkspaceName,
      );
}

final recordNotifierProvider =
    StateNotifierProvider<RecordNotifier, RecordState>((ref) {
  return RecordNotifier(ref.read(audioIngestApiProvider));
});
