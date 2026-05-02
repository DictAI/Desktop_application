import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workspace_api.dart';
import '../data/dto/workspace_dto.dart';
import '../data/dto/participant_dto.dart';
import '../../../core/error/app_exception.dart';
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
    state = state.copyWith(status: WorkspacesStatus.loading, errorMessage: null);
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
  final String? errorMessage;
  final bool isAddingParticipant;

  const WorkspaceDetailState({
    this.status = DetailStatus.loading,
    this.workspace,
    this.participants = const [],
    this.errorMessage,
    this.isAddingParticipant = false,
  });

  WorkspaceDetailState copyWith({
    DetailStatus? status,
    WorkspaceDto? workspace,
    List<ParticipantDto>? participants,
    String? errorMessage,
    bool? isAddingParticipant,
  }) =>
      WorkspaceDetailState(
        status: status ?? this.status,
        workspace: workspace ?? this.workspace,
        participants: participants ?? this.participants,
        errorMessage: errorMessage,
        isAddingParticipant: isAddingParticipant ?? this.isAddingParticipant,
      );
}

class WorkspaceDetailNotifier extends StateNotifier<WorkspaceDetailState> {
  final WorkspaceApi _api;
  final String workspaceId;

  WorkspaceDetailNotifier(this._api, this.workspaceId)
      : super(const WorkspaceDetailState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: DetailStatus.loading, errorMessage: null);
    try {
      final ws = await _api.getWorkspace(workspaceId);
      final participants = await _api.getParticipants(workspaceId);
      state = state.copyWith(
        status: DetailStatus.loaded,
        workspace: ws,
        participants: participants,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        status: DetailStatus.error,
        errorMessage: e.message,
      );
    }
  }

  Future<bool> addParticipant({
    required String name,
    required String email,
  }) async {
    state = state.copyWith(isAddingParticipant: true, errorMessage: null);
    try {
      final p = await _api.addParticipant(
        workspaceId: workspaceId,
        name: name,
        email: email,
      );
      state = state.copyWith(
        isAddingParticipant: false,
        participants: [...state.participants, p],
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
      state = state.copyWith(
        participants: state.participants
            .where((p) => p.participantId != participantId)
            .toList(),
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

  void clearError() => state = state.copyWith(errorMessage: null);
}

// Family provider — one notifier per workspaceId
final workspaceDetailProvider = StateNotifierProvider.family<
    WorkspaceDetailNotifier, WorkspaceDetailState, String>(
  (ref, workspaceId) =>
      WorkspaceDetailNotifier(ref.read(workspaceApiProvider), workspaceId),
);
