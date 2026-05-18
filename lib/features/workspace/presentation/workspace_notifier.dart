import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workspace_api.dart';
import '../data/dto/workspace_dto.dart';
import '../data/dto/participant_dto.dart';
import '../../../core/error/app_exception.dart';
import '../../../features/voice_profile/data/dto/voice_profile_dto.dart';
import '../../../features/voice_profile/data/voice_profile_api.dart';
import '../../../shared/providers/providers.dart';

// ─── Workspaces list ──────────────────────────────────────────────────────────

enum WorkspacesStatus { idle, loading, loaded, creating, error }

class WorkspacesState {
  final WorkspacesStatus status;
  final List<WorkspaceDto> workspaces;
  final String? errorMessage;
  final bool isStubError;

  const WorkspacesState({
    this.status = WorkspacesStatus.idle,
    this.workspaces = const [],
    this.errorMessage,
    this.isStubError = false,
  });

  WorkspacesState copyWith({
    WorkspacesStatus? status,
    List<WorkspaceDto>? workspaces,
    String? errorMessage,
    bool? isStubError,
  }) =>
      WorkspacesState(
        status: status ?? this.status,
        workspaces: workspaces ?? this.workspaces,
        errorMessage: errorMessage,
        isStubError: isStubError ?? this.isStubError,
      );
}

class WorkspacesNotifier extends StateNotifier<WorkspacesState> {
  final WorkspaceApi _api;

  WorkspacesNotifier(this._api) : super(const WorkspacesState()) {
    load();
  }

  Future<void> load() async {
    state =
        state.copyWith(status: WorkspacesStatus.loading, errorMessage: null);
    try {
      final list = await _api.getWorkspaces();
      state = state.copyWith(status: WorkspacesStatus.loaded, workspaces: list);
    } on AppException catch (e) {
      state = state.copyWith(
        status: WorkspacesStatus.error,
        errorMessage: e.message,
        isStubError: false,
      );
    }
  }

  Future<WorkspaceDto?> create(String name) async {
    state = state.copyWith(status: WorkspacesStatus.creating);
    try {
      final ws = await _api.createWorkspace(name);
      state = state.copyWith(
        status: WorkspacesStatus.loaded,
        workspaces: [...state.workspaces, ws],
      );
      return ws;
    } on AppException catch (e) {
      state = state.copyWith(
        status: WorkspacesStatus.error,
        errorMessage: e.message,
      );
      return null;
    }
  }

  Future<bool> delete(String workspaceId) async {
    try {
      await _api.deleteWorkspace(workspaceId);
      state = state.copyWith(
        workspaces: state.workspaces
            .where((w) => w.workspaceId != workspaceId)
            .toList(),
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        status: WorkspacesStatus.error,
        errorMessage: e.message,
        isStubError: false,
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(
        status: state.workspaces.isEmpty
            ? WorkspacesStatus.idle
            : WorkspacesStatus.loaded,
        errorMessage: null,
        isStubError: false,
      );
}

final workspacesNotifierProvider =
    StateNotifierProvider<WorkspacesNotifier, WorkspacesState>((ref) {
  return WorkspacesNotifier(ref.read(workspaceApiProvider));
});

// ─── Single workspace detail ──────────────────────────────────────────────────

enum DetailStatus { loading, loaded, error }

class WorkspaceDetailState {
  final DetailStatus status;
  final WorkspaceDto? workspace;
  final List<ParticipantDto> participants;
  final List<VoiceProfileDto> voiceProfiles;
  final Map<String, bool> voiceProfileStatus;
  final String? errorMessage;
  final bool isAddingParticipant;

  const WorkspaceDetailState({
    this.status = DetailStatus.loading,
    this.workspace,
    this.participants = const [],
    this.voiceProfiles = const [],
    this.voiceProfileStatus = const {},
    this.errorMessage,
    this.isAddingParticipant = false,
  });

  WorkspaceDetailState copyWith({
    DetailStatus? status,
    WorkspaceDto? workspace,
    List<ParticipantDto>? participants,
    List<VoiceProfileDto>? voiceProfiles,
    Map<String, bool>? voiceProfileStatus,
    String? errorMessage,
    bool? isAddingParticipant,
  }) =>
      WorkspaceDetailState(
        status: status ?? this.status,
        workspace: workspace ?? this.workspace,
        participants: participants ?? this.participants,
        voiceProfiles: voiceProfiles ?? this.voiceProfiles,
        voiceProfileStatus: voiceProfileStatus ?? this.voiceProfileStatus,
        errorMessage: errorMessage,
        isAddingParticipant: isAddingParticipant ?? this.isAddingParticipant,
      );
}

class WorkspaceDetailNotifier extends StateNotifier<WorkspaceDetailState> {
  final WorkspaceApi _api;
  final VoiceProfileApi _voiceApi;
  final String workspaceId;

  WorkspaceDetailNotifier(this._api, this._voiceApi, this.workspaceId)
      : super(const WorkspaceDetailState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: DetailStatus.loading, errorMessage: null);
    try {
      final ws = await _api.getWorkspace(workspaceId);
      final participants = await _api.getParticipants(workspaceId);
      final voiceProfiles = await _voiceApi.getVoiceProfiles();
      state = state.copyWith(
        status: DetailStatus.loaded,
        workspace: ws,
        participants: participants,
        voiceProfiles: voiceProfiles,
        voiceProfileStatus: _statusesFromParticipants(participants),
      );
    } on AppException catch (e) {
      state = state.copyWith(
        status: DetailStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<bool> uploadVoiceProfile({
    required String participantId,
    required String audioPath,
  }) async {
    try {
      final participant = _findParticipant(participantId);
      final response = await _voiceApi.createVoiceProfile(
        workspaceId: workspaceId,
        participantId: participantId,
        audioPath: audioPath,
        displayName: participant?.name,
      );
      final voiceProfileId = response['voice_profile_id'] as String?;
      final participants = state.participants
          .map((p) => p.participantId == participantId && voiceProfileId != null
              ? p.copyWith(voiceProfileId: voiceProfileId)
              : p)
          .toList();
      final voiceProfiles = await _voiceApi.getVoiceProfiles();
      state = state.copyWith(
        participants: participants,
        voiceProfiles: voiceProfiles,
        voiceProfileStatus: {
          ...state.voiceProfileStatus,
          participantId: true,
        },
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> addParticipant({
    required String name,
    required String email,
    String? voiceProfileId,
  }) async {
    state = state.copyWith(isAddingParticipant: true, errorMessage: null);
    try {
      var participant = await _api.addParticipant(
        workspaceId: workspaceId,
        name: name,
        email: email,
      );
      if (voiceProfileId != null) {
        await _voiceApi.assignVoiceProfile(
          workspaceId: workspaceId,
          participantId: participant.participantId,
          voiceProfileId: voiceProfileId,
        );
        participant = participant.copyWith(voiceProfileId: voiceProfileId);
      }
      state = state.copyWith(
        isAddingParticipant: false,
        participants: [...state.participants, participant],
        voiceProfileStatus: {
          ...state.voiceProfileStatus,
          participant.participantId: participant.voiceProfileId != null,
        },
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isAddingParticipant: false,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<bool> assignVoiceProfile({
    required String participantId,
    required String voiceProfileId,
  }) async {
    try {
      await _voiceApi.assignVoiceProfile(
        workspaceId: workspaceId,
        participantId: participantId,
        voiceProfileId: voiceProfileId,
      );
      state = state.copyWith(
        participants: state.participants
            .map((p) => p.participantId == participantId
                ? p.copyWith(voiceProfileId: voiceProfileId)
                : p)
            .toList(),
        voiceProfileStatus: {
          ...state.voiceProfileStatus,
          participantId: true,
        },
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> updateParticipant({
    required String participantId,
    required String name,
    required String email,
  }) async {
    try {
      final updated = await _api.updateParticipant(
        workspaceId: workspaceId,
        participantId: participantId,
        name: name,
        email: email,
      );
      state = state.copyWith(
        participants: state.participants
            .map((p) => p.participantId == participantId ? updated : p)
            .toList(),
        voiceProfileStatus: {
          ...state.voiceProfileStatus,
          participantId: updated.voiceProfileId != null,
        },
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> deleteParticipant(String participantId) async {
    try {
      await _api.deleteParticipant(
        workspaceId: workspaceId,
        participantId: participantId,
      );
      final nextStatus = Map<String, bool>.from(state.voiceProfileStatus)
        ..remove(participantId);
      state = state.copyWith(
        participants: state.participants
            .where((p) => p.participantId != participantId)
            .toList(),
        voiceProfileStatus: nextStatus,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  Future<bool> updateWorkspace(String name) async {
    try {
      final updated = await _api.updateWorkspace(workspaceId, name);
      state = state.copyWith(workspace: updated);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }

  ParticipantDto? _findParticipant(String participantId) {
    for (final participant in state.participants) {
      if (participant.participantId == participantId) return participant;
    }
    return null;
  }

  Map<String, bool> _statusesFromParticipants(
      List<ParticipantDto> participants) {
    return {
      for (final participant in participants)
        participant.participantId: participant.voiceProfileId != null,
    };
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final workspaceDetailProvider = StateNotifierProvider.family<
    WorkspaceDetailNotifier, WorkspaceDetailState, String>(
  (ref, workspaceId) => WorkspaceDetailNotifier(
    ref.read(workspaceApiProvider),
    ref.read(voiceProfileApiProvider),
    workspaceId,
  ),
);
