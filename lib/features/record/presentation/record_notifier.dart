import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/audio_capture.dart';
import '../data/dto/upload_accepted_dto.dart';
import '../data/dto/upload_options.dart';
import '../data/linux_audio_capture.dart';
import '../data/macos_audio_capture.dart';
import '../data/microphone_capture.dart';

enum RecordStatus {
  idle,
  starting,
  recording,
  paused,
  preparing,
  uploading,
  accepted,
  error,
}

class RecordState {
  const RecordState({
    this.status = RecordStatus.idle,
    this.captureSystemAudio = false,
    this.selectedWorkspaceId,
    this.selectedWorkspaceName,
    this.errorMessage,
    this.uploadProgress,
    this.inputDevices = const [],
    this.selectedDevice,
    this.language = UploadLanguage.auto,
    this.mixed = false,
    this.accepted,
    this.canRetryUpload = false,
  });

  final RecordStatus status;
  final bool captureSystemAudio;
  final String? selectedWorkspaceId, selectedWorkspaceName, errorMessage;
  final double? uploadProgress;
  final List<InputDevice> inputDevices;
  final InputDevice? selectedDevice;
  final UploadLanguage language;
  final bool mixed;
  final UploadAcceptedDto? accepted;
  final bool canRetryUpload;

  bool get isActive =>
      status == RecordStatus.recording || status == RecordStatus.paused;
  bool get controlsLocked =>
      isActive ||
      switch (status) {
        RecordStatus.starting ||
        RecordStatus.preparing ||
        RecordStatus.uploading => true,
        _ => false,
      };

  RecordState copyWith({
    RecordStatus? status,
    bool? captureSystemAudio,
    String? selectedWorkspaceId,
    String? selectedWorkspaceName,
    String? errorMessage,
    double? uploadProgress,
    List<InputDevice>? inputDevices,
    InputDevice? selectedDevice,
    UploadLanguage? language,
    bool? mixed,
    UploadAcceptedDto? accepted,
    bool? canRetryUpload,
    bool clearDevice = false,
    bool clearWorkspace = false,
    bool clearError = false,
    bool clearUpload = false,
  }) => RecordState(
    status: status ?? this.status,
    captureSystemAudio: captureSystemAudio ?? this.captureSystemAudio,
    selectedWorkspaceId: clearWorkspace
        ? null
        : selectedWorkspaceId ?? this.selectedWorkspaceId,
    selectedWorkspaceName: clearWorkspace
        ? null
        : selectedWorkspaceName ?? this.selectedWorkspaceName,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    uploadProgress: clearUpload ? null : uploadProgress ?? this.uploadProgress,
    inputDevices: inputDevices ?? this.inputDevices,
    selectedDevice: clearDevice ? null : selectedDevice ?? this.selectedDevice,
    language: language ?? this.language,
    mixed: mixed ?? this.mixed,
    accepted: clearUpload ? null : accepted ?? this.accepted,
    canRetryUpload:
        canRetryUpload ?? (clearUpload ? false : this.canRetryUpload),
  );
}

typedef RecordCaptureFactory = AudioCapture Function(bool captureSystemAudio);

final recordCaptureFactoryProvider = Provider<RecordCaptureFactory>(
  (ref) => (system) {
    if (Platform.isLinux) return LinuxAudioCapture(captureSystemAudio: system);
    if (Platform.isMacOS) {
      return system ? MacosAudioCapture() : MicrophoneCapture();
    }
    throw const ValidationException('Запись доступна в macOS и Linux.');
  },
);

class RecordNotifier extends StateNotifier<RecordState> {
  RecordNotifier({
    required RecordCaptureFactory captureFactory,
    required Future<BatchSession> Function() session,
  }) : _captureFactory = captureFactory,
       _openSession = session,
       super(const RecordState());

  final RecordCaptureFactory _captureFactory;
  final Future<BatchSession> Function() _openSession;
  final _random = Random.secure();
  AudioCapture? _capture;
  Future<void>? _releasing;
  UploadOptions? _recordingOptions;
  BatchSession? _session;
  String? _pendingUploadId;
  int _generation = 0;
  Future<void>? _pauseTransition;
  bool _refreshingDevices = false;

  bool get hasActiveOperation => state.controlsLocked;
  bool get supportsPause => _capture?.supportsPause ?? false;
  Object? get recordingIdentity => _recordingOptions;

  bool _current(int generation) => mounted && _generation == generation;

  bool _currentSession(int generation, BatchSession session) {
    if (!_current(generation)) return false;
    if (!session.isCurrent) throw const UnauthorizedException();
    return true;
  }

  Future<void> refreshDevices() async {
    if (_refreshingDevices || hasActiveOperation) return;
    _refreshingDevices = true;
    final generation = _generation;
    AudioCapture? probe;
    try {
      probe = _captureFactory(false);
      final devices = await probe.listInputDevices();
      if (!_current(generation) || hasActiveOperation) return;
      final selected = state.selectedDevice;
      final sameDevice = devices
          .where((device) => device.id == selected?.id)
          .firstOrNull;
      state = state.copyWith(
        inputDevices: devices,
        selectedDevice: sameDevice,
        clearDevice: sameDevice == null,
      );
    } on AppException catch (error) {
      if (_current(generation) && !hasActiveOperation) {
        setWorkspaceContextError(error.message);
      }
    } finally {
      try {
        await probe?.dispose();
      } on AppException catch (error) {
        if (_current(generation) && !hasActiveOperation) {
          setWorkspaceContextError(error.message);
        }
      } finally {
        _refreshingDevices = false;
      }
    }
  }

  void selectDevice(InputDevice? device) {
    if (hasActiveOperation) return;
    state = state.copyWith(selectedDevice: device, clearDevice: device == null);
  }

  void setCaptureSystemAudio(bool value) {
    if (hasActiveOperation) return;
    state = state.copyWith(captureSystemAudio: value);
  }

  void setLanguage(UploadLanguage language) {
    if (hasActiveOperation) return;
    state = state.copyWith(
      language: language,
      mixed: language == UploadLanguage.auto && state.mixed,
    );
  }

  void setMixed(bool mixed) {
    if (hasActiveOperation) return;
    state = state.copyWith(
      mixed: mixed,
      language: mixed ? UploadLanguage.auto : null,
    );
  }

  bool selectWorkspace(String id, String name) {
    if (hasActiveOperation) return false;
    state = state.copyWith(
      selectedWorkspaceId: id,
      selectedWorkspaceName: name,
      clearError: true,
    );
    return true;
  }

  void renameWorkspace(String id, String name) {
    if (state.selectedWorkspaceId == id) {
      state = state.copyWith(selectedWorkspaceName: name);
    }
  }

  void workspaceDeleted(String id) {
    if (state.selectedWorkspaceId != id) return;
    if (hasActiveOperation) {
      setWorkspaceContextError(
        'Рабочее пространство удалено. Активная операция сохранена.',
      );
    } else {
      clearWorkspace();
    }
  }

  void setWorkspaceContextError(String message) =>
      state = state.copyWith(errorMessage: message);

  void clearWorkspace() {
    if (hasActiveOperation) return;
    state = state.copyWith(clearWorkspace: true, clearError: true);
  }

  /// The legacy anonymous start keeps the common selectors locked until .24.
  Future<void> runStartOperation(Future<void> Function() start) async {
    if (hasActiveOperation) return;
    final generation = ++_generation;
    final previous = state.status;
    state = state.copyWith(status: RecordStatus.starting);
    try {
      await start();
    } finally {
      if (_current(generation)) state = state.copyWith(status: previous);
    }
  }

  UploadOptions _options(
    UploadSource source, {
    UploadLanguage? language,
    bool? mixed,
  }) => UploadOptions(
    anonymous: false,
    workspaceId: state.selectedWorkspaceId,
    idempotencyKey: List.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
    source: source,
    language: language ?? state.language,
    mixed: mixed ?? state.mixed,
  );

  Future<void> startRecording() async {
    if (hasActiveOperation) return;
    final generation = ++_generation;
    _pendingUploadId = null;
    final device = state.selectedDevice;
    final system = state.captureSystemAudio;
    state = state.copyWith(
      status: RecordStatus.starting,
      clearError: true,
      clearUpload: true,
    );
    try {
      final options = _options(
        RecordingUploadSource(
          microphoneDeviceId: device?.id,
          captureSystemAudio: system,
        ),
      );
      final session = await _openSession();
      if (!_currentSession(generation, session)) return;
      _session = session;
      await _releaseCapture();
      if (!_currentSession(generation, session)) return;
      final capture = _captureFactory(system);
      _capture = capture;
      await capture.start(device: device);
      if (!_currentSession(generation, session)) return;
      _recordingOptions = options;
      state = state.copyWith(status: RecordStatus.recording);
    } on AppException catch (error) {
      if (!_current(generation)) return;
      await _cleanupCapture();
      _fail(generation, error);
    }
  }

  Future<void> togglePause() {
    final capture = _capture;
    if (_pauseTransition != null ||
        !state.isActive ||
        capture == null ||
        !capture.supportsPause) {
      return Future.value();
    }
    return _pauseTransition = _togglePause(capture);
  }

  Future<void> _togglePause(AudioCapture capture) async {
    final generation = _generation;
    try {
      final resuming = state.status == RecordStatus.paused;
      if (resuming) {
        await capture.resume();
      } else {
        await capture.pause();
      }
      if (_current(generation)) {
        state = state.copyWith(
          status: resuming ? RecordStatus.recording : RecordStatus.paused,
        );
      }
    } on AppException catch (error) {
      if (!_current(generation)) return;
      await _cleanupCapture();
      _fail(generation, error);
    } finally {
      if (_current(generation)) _pauseTransition = null;
    }
  }

  Future<void> finishRecording({required bool confirmed}) async {
    final capture = _capture;
    final options = _recordingOptions;
    final session = _session;
    if (!confirmed ||
        !state.isActive ||
        capture == null ||
        options == null ||
        session == null) {
      return;
    }
    final generation = _generation;
    final pause = _pauseTransition;
    if (pause != null) {
      await pause;
      if (!_current(generation) ||
          !identical(_recordingOptions, options) ||
          !state.isActive) {
        return;
      }
    }
    _recordingOptions = null;
    state = state.copyWith(status: RecordStatus.preparing, clearError: true);
    try {
      if (!_currentSession(generation, session)) return;
      final file = await capture.finish(confirmed: true);
      if (!_current(generation)) return;
      await _releaseCapture();
      if (!_currentSession(generation, session)) return;
      if (file == null) {
        throw const ValidationException('Не удалось завершить запись WAV.');
      }
      await _prepareAndSend(file, options, session, generation, appOwned: true);
    } on AppException catch (error) {
      if (!_current(generation)) return;
      await _cleanupCapture();
      _fail(generation, error);
    }
  }

  Future<void> uploadFile(
    File file, {
    UploadLanguage? language,
    bool? mixed,
  }) async {
    if (hasActiveOperation) return;
    final generation = ++_generation;
    _pendingUploadId = null;
    state = state.copyWith(
      status: RecordStatus.preparing,
      clearError: true,
      clearUpload: true,
    );
    try {
      final options = _options(
        const ImportedWavUploadSource(),
        language: language,
        mixed: mixed,
      );
      final session = await _openSession();
      if (!_currentSession(generation, session)) return;
      _session = session;
      await _prepareAndSend(
        file,
        options,
        session,
        generation,
        appOwned: false,
      );
    } on AppException catch (error) {
      _fail(generation, error);
    }
  }

  Future<void> _prepareAndSend(
    File file,
    UploadOptions options,
    BatchSession session,
    int generation, {
    required bool appOwned,
  }) async {
    // prepare validates the exact copied WAV and commits the receipt before POST.
    final pending = await session.uploads.prepare(
      source: file,
      options: options,
    );
    if (appOwned) {
      try {
        await file.delete();
      } on FileSystemException {
        // The durable copy remains authoritative. No user-owned file is removed.
      }
    }
    if (!_currentSession(generation, session)) return;
    _pendingUploadId = pending.localId;
    await _send(session, pending.localId, generation);
  }

  Future<void> _send(BatchSession session, String id, int generation) async {
    state = state.copyWith(
      status: RecordStatus.uploading,
      clearError: true,
      clearUpload: true,
    );
    final entry = await session.submit(
      id,
      onSendProgress: (sent, total) {
        if (_current(generation) && session.isCurrent && total > 0) {
          state = state.copyWith(
            uploadProgress: (sent / total).clamp(0.0, 1.0),
          );
        }
      },
    );
    if (!_currentSession(generation, session)) return;
    _pendingUploadId = null;
    state = state.copyWith(
      status: RecordStatus.accepted,
      accepted: entry.accepted,
    );
  }

  Future<void> retryUpload() async {
    final session = _session;
    final id = _pendingUploadId;
    if (hasActiveOperation ||
        !state.canRetryUpload ||
        id == null ||
        session == null ||
        !session.isCurrent) {
      return;
    }
    final generation = ++_generation;
    try {
      await _send(session, id, generation);
    } on AppException catch (error) {
      _fail(generation, error);
    }
  }

  void _fail(int generation, AppException error) {
    if (!_current(generation)) return;
    _recordingOptions = null;
    state = state.copyWith(
      status: RecordStatus.error,
      errorMessage: error.message,
      canRetryUpload:
          _pendingUploadId != null &&
          error is ApiFailure &&
          error.actions.contains(ApiRecoveryAction.replaySameUpload),
    );
  }

  void reset() {
    if (hasActiveOperation) {
      state = state.copyWith(clearError: true);
      return;
    }
    _pendingUploadId = null;
    state = state.copyWith(
      status: RecordStatus.idle,
      clearError: true,
      clearUpload: true,
    );
  }

  Future<void> _releaseCapture() {
    final capture = _capture;
    if (capture == null) return Future.value();
    return _releasing ??= Future<void>.sync(capture.dispose)
        .then((_) {
          if (identical(_capture, capture)) _capture = null;
        })
        .whenComplete(() => _releasing = null);
  }

  Future<void> _cleanupCapture() async {
    try {
      await _releaseCapture();
    } on AppException {
      // Keep a failed handle for another explicit cleanup attempt before Start.
    }
  }

  void _invalidateSession() {
    _generation++;
    _session = null;
    _pendingUploadId = null;
    _recordingOptions = null;
    _pauseTransition = null;
    state = RecordState(inputDevices: state.inputDevices);
    unawaited(_cleanupCapture());
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_cleanupCapture());
    super.dispose();
  }
}

final recordNotifierProvider =
    StateNotifierProvider<RecordNotifier, RecordState>((ref) {
      final notifier = RecordNotifier(
        captureFactory: ref.read(recordCaptureFactoryProvider),
        session: () => ref.read(batchSessionProvider.future),
      );
      ref.listen(
        authNotifierProvider,
        (_, __) => notifier._invalidateSession(),
      );
      ref.listen(
        sessionNotifierProvider,
        (_, __) => notifier._invalidateSession(),
      );
      return notifier;
    });
