import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/workspace_api.dart';
import '../data/dto/workspace_dto.dart';
import '../data/dto/participant_dto.dart';
import '../../record/presentation/record_notifier.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';

enum WorkspacesStatus { idle, loading, loaded, creating, error }

class WorkspacesState {
  final WorkspacesStatus status;
  final List<WorkspaceDto> workspaces;
  final String? errorMessage;
  final bool isMutating;
  const WorkspacesState({
    this.status = WorkspacesStatus.idle,
    this.workspaces = const [],
    this.errorMessage,
    this.isMutating = false,
  });
  WorkspacesState copyWith({
    WorkspacesStatus? status,
    List<WorkspaceDto>? workspaces,
    String? errorMessage,
    bool? isMutating,
  }) => WorkspacesState(
    status: status ?? this.status,
    workspaces: workspaces ?? this.workspaces,
    errorMessage: errorMessage,
    isMutating: isMutating ?? this.isMutating,
  );
}

class WorkspacesNotifier extends StateNotifier<WorkspacesState> {
  final WorkspaceApi _api;
  final void Function(WorkspaceDto)? onUpdated;
  final void Function(String)? onDeleted;
  int _epoch = 0;
  bool _loading = false;
  // Only changes committed after the latest list request started are overlaid.
  final _updatedDuringLoad = <String, WorkspaceDto>{};
  final _removedDuringLoad = <String>{};
  String? get errorMessage => mounted ? state.errorMessage : null;
  WorkspacesNotifier(this._api, {this.onUpdated, this.onDeleted})
    : super(const WorkspacesState()) {
    load();
  }

  Future<void> load() async {
    if (state.isMutating) return;
    final epoch = ++_epoch;
    _loading = true;
    _updatedDuringLoad.clear();
    _removedDuringLoad.clear();
    state = state.copyWith(status: WorkspacesStatus.loading);
    try {
      final list = await _api.getWorkspaces();
      if (!mounted || epoch != _epoch) return;
      state = state.copyWith(
        status: WorkspacesStatus.loaded,
        workspaces: List.unmodifiable([
          ..._updatedDuringLoad.values.where(
            (ws) =>
                !list.any((item) => item.workspaceId == ws.workspaceId) &&
                !_removedDuringLoad.contains(ws.workspaceId),
          ),
          ...list
              .where((ws) => !_removedDuringLoad.contains(ws.workspaceId))
              .map((ws) => _updatedDuringLoad[ws.workspaceId] ?? ws),
        ]),
      );
    } on AppException catch (e) {
      if (!mounted || epoch != _epoch) return;
      state = state.copyWith(
        status: WorkspacesStatus.error,
        errorMessage: e.message,
      );
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        _updatedDuringLoad.clear();
        _removedDuringLoad.clear();
      }
    }
  }

  Future<WorkspaceDto?> create(String name) => _save(name);
  Future<WorkspaceDto?> rename(String id, String name) => _save(name, id: id);

  Future<WorkspaceDto?> _save(String name, {String? id}) async {
    if (state.isMutating) return null;
    if (name.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Введите название рабочего пространства.',
      );
      return null;
    }
    state = state.copyWith(isMutating: true);
    try {
      final ws = id == null
          ? await _api.createWorkspace(name.trim())
          : await _api.updateWorkspace(id, name.trim());
      if (!mounted) return null;
      acceptWorkspace(ws);
      onUpdated?.call(ws);
      return ws;
    } on AppException catch (e) {
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          status: _loading ? WorkspacesStatus.loading : WorkspacesStatus.loaded,
          errorMessage: e.message,
        );
      }
      return null;
    }
  }

  void acceptWorkspace(WorkspaceDto ws) {
    if (!mounted) return;
    if (_loading) {
      _updatedDuringLoad[ws.workspaceId] = ws;
      _removedDuringLoad.remove(ws.workspaceId);
    }
    final exists = state.workspaces.any((w) => w.workspaceId == ws.workspaceId);
    state = state.copyWith(
      status: _loading ? WorkspacesStatus.loading : WorkspacesStatus.loaded,
      isMutating: false,
      workspaces: List.unmodifiable(
        exists
            ? state.workspaces.map(
                (w) => w.workspaceId == ws.workspaceId ? ws : w,
              )
            : [ws, ...state.workspaces],
      ),
    );
  }

  Future<bool> delete(String workspaceId) async {
    if (state.isMutating) return false;
    state = state.copyWith(isMutating: true);
    try {
      await _api.deleteWorkspace(workspaceId);
      if (!mounted) return false;
      removeWorkspace(workspaceId);
      onDeleted?.call(workspaceId);
      return true;
    } on AppException catch (e) {
      if (mounted) {
        state = state.copyWith(
          isMutating: false,
          status: _loading ? WorkspacesStatus.loading : WorkspacesStatus.loaded,
          errorMessage: e.message,
        );
      }
      return false;
    }
  }

  void removeWorkspace(String id) {
    if (!mounted) return;
    if (_loading) {
      _updatedDuringLoad.remove(id);
      _removedDuringLoad.add(id);
    }
    state = state.copyWith(
      status: _loading ? WorkspacesStatus.loading : WorkspacesStatus.loaded,
      isMutating: false,
      workspaces: List.unmodifiable(
        state.workspaces.where((w) => w.workspaceId != id),
      ),
    );
  }

  void clearError() => state = state.copyWith();
}

final StateNotifierProvider<WorkspacesNotifier, WorkspacesState>
workspacesNotifierProvider =
    StateNotifierProvider<WorkspacesNotifier, WorkspacesState>((ref) {
      return WorkspacesNotifier(
        ref.read(workspaceApiProvider),
        onUpdated: (ws) {
          if (ref.exists(workspaceDetailProvider(ws.workspaceId))) {
            ref
                .read(workspaceDetailProvider(ws.workspaceId).notifier)
                .acceptWorkspace(ws);
          }
          if (ref.exists(recordNotifierProvider)) {
            ref
                .read(recordNotifierProvider.notifier)
                .renameWorkspace(ws.workspaceId, ws.name);
          }
        },
        onDeleted: (id) {
          if (ref.exists(workspaceDetailProvider(id))) {
            ref.invalidate(workspaceDetailProvider(id));
          }
          if (ref.exists(recordNotifierProvider)) {
            ref.read(recordNotifierProvider.notifier).workspaceDeleted(id);
          }
        },
      );
    });

// ─── Single workspace detail ──────────────────────────────────────────────────

enum DetailStatus { loading, loaded, error }

class WorkspaceDetailState {
  final DetailStatus status;
  final WorkspaceDto? workspace;
  final List<ParticipantDto> participants;
  final String? errorMessage;
  final bool isAddingParticipant;
  final bool isUpdatingWorkspace;
  final bool isContactBusy;
  final bool needsContactReconciliation;
  final bool canRetryContactMutation;

  const WorkspaceDetailState({
    this.status = DetailStatus.loading,
    this.workspace,
    this.participants = const [],
    this.errorMessage,
    this.isAddingParticipant = false,
    this.isUpdatingWorkspace = false,
    this.isContactBusy = false,
    this.needsContactReconciliation = false,
    this.canRetryContactMutation = false,
  });

  WorkspaceDetailState copyWith({
    DetailStatus? status,
    WorkspaceDto? workspace,
    List<ParticipantDto>? participants,
    String? errorMessage,
    bool? isAddingParticipant,
    bool? isUpdatingWorkspace,
    bool? isContactBusy,
    bool? needsContactReconciliation,
    bool? canRetryContactMutation,
  }) => WorkspaceDetailState(
    status: status ?? this.status,
    workspace: workspace ?? this.workspace,
    participants: participants ?? this.participants,
    errorMessage: errorMessage,
    isAddingParticipant: isAddingParticipant ?? this.isAddingParticipant,
    isUpdatingWorkspace: isUpdatingWorkspace ?? this.isUpdatingWorkspace,
    isContactBusy: isContactBusy ?? this.isContactBusy,
    needsContactReconciliation:
        needsContactReconciliation ?? this.needsContactReconciliation,
    canRetryContactMutation:
        canRetryContactMutation ?? this.canRetryContactMutation,
  );
}

class WorkspaceDetailNotifier extends StateNotifier<WorkspaceDetailState> {
  final WorkspaceApi _api;
  final String workspaceId;
  final void Function(WorkspaceDto)? onUpdated;
  int _loadEpoch = 0;
  bool _loading = false;
  WorkspaceDto? _workspaceDuringLoad;
  _ContactMutation? _pendingContactMutation;
  String? get pendingContactDescription {
    final pending = _pendingContactMutation;
    if (pending == null) return null;
    final action = switch (pending.action) {
      _ContactAction.add => 'Добавить контакт',
      _ContactAction.edit => 'Изменить контакт',
      _ContactAction.remove => 'Удалить контакт',
    };
    return '$action ${pending.name} ${pending.email}'.trim();
  }

  String? get errorMessage => mounted ? state.errorMessage : null;

  WorkspaceDetailNotifier(this._api, this.workspaceId, {this.onUpdated})
    : super(const WorkspaceDetailState()) {
    load();
  }

  Future<void> load() async {
    if (state.isUpdatingWorkspace || state.isContactBusy) return;
    final epoch = ++_loadEpoch;
    _loading = true;
    _workspaceDuringLoad = null;
    state = state.copyWith(status: DetailStatus.loading, errorMessage: null);
    try {
      final ws = await _api.getWorkspace(workspaceId);
      final participants = await _api.getParticipants(workspaceId);
      if (!mounted || epoch != _loadEpoch) return;
      state = state.copyWith(
        status: DetailStatus.loaded,
        workspace: _workspaceDuringLoad ?? ws,
        participants: participants,
      );
    } on AppException catch (e) {
      if (!mounted || epoch != _loadEpoch) return;
      state = state.copyWith(
        status: DetailStatus.error,
        errorMessage: e.message,
      );
    } finally {
      if (epoch == _loadEpoch) {
        _loading = false;
        _workspaceDuringLoad = null;
      }
    }
  }

  Future<bool> addParticipant({required String name, required String email}) =>
      _changeContact(
        _ContactMutation(
          _ContactAction.add,
          name: name.trim(),
          email: email.trim(),
        ),
      );

  Future<bool> updateParticipant({
    required String participantId,
    required String name,
    required String email,
  }) => _changeContact(
    _ContactMutation(
      _ContactAction.edit,
      id: participantId,
      name: name.trim(),
      email: email.trim(),
    ),
  );

  Future<bool> deleteParticipant(String participantId) {
    final existing = state.participants
        .where((p) => p.participantId == participantId)
        .firstOrNull;
    return _changeContact(
      _ContactMutation(
        _ContactAction.remove,
        id: participantId,
        name: existing?.name ?? '',
        email: existing?.email ?? '',
      ),
    );
  }

  bool _contactAvailable() => mounted && !_loading && !state.isContactBusy;

  Future<bool> _changeContact(
    _ContactMutation mutation, {
    bool retry = false,
  }) async {
    if (!_contactAvailable()) return false;
    if (!retry && _pendingContactMutation != null) {
      state = state.copyWith(
        errorMessage:
            'Сначала проверьте результат предыдущего изменения контакта.',
      );
      return false;
    }
    if (mutation.action != _ContactAction.remove) {
      if (mutation.name.isEmpty ||
          !RegExp(r'^[^\s@<>]+@[^\s@<>]+$').hasMatch(mutation.email)) {
        state = state.copyWith(
          errorMessage: 'Введите имя и корректный email контакта.',
        );
        return false;
      }
      if (state.participants.any(
        (p) => p.email == mutation.email && p.participantId != mutation.id,
      )) {
        state = state.copyWith(
          errorMessage:
              'Контакт с таким email уже есть в рабочем пространстве.',
        );
        return false;
      }
    }
    state = state.copyWith(
      isContactBusy: true,
      isAddingParticipant: mutation.action == _ContactAction.add,
      canRetryContactMutation: false,
    );
    try {
      switch (mutation.action) {
        case _ContactAction.add:
          final contact = await _api.addParticipant(
            workspaceId: workspaceId,
            name: mutation.name,
            email: mutation.email,
          );
          if (!mounted) return false;
          _acceptContact(contact);
        case _ContactAction.edit:
          final contact = await _api.updateParticipant(
            workspaceId: workspaceId,
            participantId: mutation.id!,
            name: mutation.name,
            email: mutation.email,
          );
          if (!mounted) return false;
          _acceptContact(contact);
        case _ContactAction.remove:
          await _api.deleteParticipant(
            workspaceId: workspaceId,
            participantId: mutation.id!,
          );
          if (!mounted) return false;
          state = state.copyWith(
            participants: List.unmodifiable(
              state.participants.where((p) => p.participantId != mutation.id),
            ),
          );
      }
      _pendingContactMutation = null;
      state = state.copyWith(
        isContactBusy: false,
        isAddingParticipant: false,
        needsContactReconciliation: false,
        canRetryContactMutation: false,
      );
      return true;
    } on AppException catch (error) {
      if (!mounted) return false;
      final conflict =
          error is ApiFailure && error.kind == ApiFailureKind.conflict;
      final uncertain = retry || _uncertainContactOutcome(error);
      if (uncertain) _pendingContactMutation = mutation;
      state = state.copyWith(
        isContactBusy: false,
        isAddingParticipant: false,
        needsContactReconciliation: uncertain,
        canRetryContactMutation: false,
        errorMessage: uncertain
            ? '${error.message} Результат изменения неизвестен. Сначала проверьте состояние контактов.'
            : conflict
            ? 'Контакт с таким email уже есть в рабочем пространстве.'
            : error.message,
      );
      return false;
    }
  }

  void _acceptContact(ParticipantDto contact) {
    final exists = state.participants.any(
      (p) => p.participantId == contact.participantId,
    );
    state = state.copyWith(
      participants: List.unmodifiable(
        exists
            ? state.participants.map(
                (p) => p.participantId == contact.participantId ? contact : p,
              )
            : [...state.participants, contact],
      ),
    );
  }

  static bool _uncertainContactOutcome(AppException error) =>
      error is! ApiFailure
      ? error is! ValidationException && error is! UnauthorizedException
      : !{
          ApiFailureKind.badRequest,
          ApiFailureKind.unauthorized,
          ApiFailureKind.forbidden,
          ApiFailureKind.notFound,
          ApiFailureKind.conflict,
          ApiFailureKind.rateLimited,
          ApiFailureKind.transportSecurity,
          ApiFailureKind.requestPolicy,
        }.contains(error.kind);

  /// W06 confirms the durable state before the user can repeat an uncertain write.
  Future<bool> reconcileContactMutation() async {
    final pending = _pendingContactMutation;
    if (pending == null || !_contactAvailable()) return false;
    state = state.copyWith(isContactBusy: true, canRetryContactMutation: false);
    try {
      final contacts = await _api.getParticipants(workspaceId);
      if (!mounted || pending != _pendingContactMutation) return false;
      final confirmed = switch (pending.action) {
        _ContactAction.add => contacts.any(
          (p) => p.email == pending.email && p.name == pending.name,
        ),
        _ContactAction.edit => contacts.any(
          (p) =>
              p.participantId == pending.id &&
              p.email == pending.email &&
              p.name == pending.name,
        ),
        _ContactAction.remove => !contacts.any(
          (p) => p.participantId == pending.id,
        ),
      };
      final conflictingContact =
          !confirmed &&
          pending.action != _ContactAction.remove &&
          contacts.any(
            (p) => p.email == pending.email && p.participantId != pending.id,
          );
      final missingTarget =
          pending.action == _ContactAction.edit &&
          !contacts.any((p) => p.participantId == pending.id);
      final unresolved = !confirmed && !conflictingContact && !missingTarget;
      if (!unresolved) _pendingContactMutation = null;
      state = state.copyWith(
        participants: List.unmodifiable(contacts),
        isContactBusy: false,
        isAddingParticipant: false,
        needsContactReconciliation: unresolved,
        canRetryContactMutation: unresolved,
        errorMessage: confirmed
            ? null
            : missingTarget
            ? 'Этот контакт уже удалён. Список контактов обновлён.'
            : conflictingContact
            ? 'Контакт с этим email уже существует. Проверьте список контактов перед редактированием.'
            : 'Последний список контактов получен, но изменение не подтверждено. Можно проверить снова или явно повторить те же изменения.',
      );
      return confirmed;
    } on AppException catch (error) {
      if (mounted) {
        state = state.copyWith(
          isContactBusy: false,
          canRetryContactMutation: false,
          errorMessage:
              '${error.message} Повтор изменения недоступен до проверки состояния.',
        );
      }
      return false;
    }
  }

  Future<bool> retryContactMutation() async {
    final pending = _pendingContactMutation;
    if (pending == null || !state.canRetryContactMutation) return false;
    return _changeContact(pending, retry: true);
  }

  void acceptWorkspace(WorkspaceDto ws) {
    if (!mounted || ws.workspaceId != workspaceId) return;
    if (_loading) _workspaceDuringLoad = ws;
    state = state.copyWith(workspace: ws, isUpdatingWorkspace: false);
  }

  Future<bool> updateWorkspace(String name) async {
    if (state.isUpdatingWorkspace) return false;
    if (name.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Введите название рабочего пространства.',
      );
      return false;
    }
    state = state.copyWith(isUpdatingWorkspace: true);
    try {
      final updated = await _api.updateWorkspace(workspaceId, name.trim());
      if (!mounted) return false;
      acceptWorkspace(updated);
      onUpdated?.call(updated);
      return true;
    } on AppException catch (e) {
      if (mounted) {
        state = state.copyWith(
          isUpdatingWorkspace: false,
          errorMessage: e.message,
        );
      }
      return false;
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final StateNotifierProviderFamily<
  WorkspaceDetailNotifier,
  WorkspaceDetailState,
  String
>
workspaceDetailProvider =
    StateNotifierProvider.family<
      WorkspaceDetailNotifier,
      WorkspaceDetailState,
      String
    >(
      (ref, workspaceId) => WorkspaceDetailNotifier(
        ref.read(workspaceApiProvider),
        workspaceId,
        onUpdated: (ws) {
          if (ref.exists(workspacesNotifierProvider)) {
            ref.read(workspacesNotifierProvider.notifier).acceptWorkspace(ws);
          }
          if (ref.exists(recordNotifierProvider)) {
            ref
                .read(recordNotifierProvider.notifier)
                .renameWorkspace(ws.workspaceId, ws.name);
          }
        },
      ),
    );

enum _ContactAction { add, edit, remove }

class _ContactMutation {
  const _ContactMutation(
    this.action, {
    this.id,
    this.name = '',
    this.email = '',
  });
  final _ContactAction action;
  final String? id;
  final String name, email;
}
