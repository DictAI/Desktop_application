import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';
import '../data/audio_ingest_api.dart';
import '../data/system_audio_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum RecordStatus { idle, recording, paused, uploading, done, error }

class RecordState {
  final RecordStatus status;
  final bool captureSystemAudio;
  final String? selectedWorkspaceId;
  final String? selectedWorkspaceName;
  final String? uploadedAudioId;
  final String? errorMessage;
  final double uploadProgress;
  final List<InputDevice> inputDevices;
  final InputDevice? selectedDevice;

  const RecordState({
    this.status = RecordStatus.idle,
    this.captureSystemAudio = false,
    this.selectedWorkspaceId,
    this.selectedWorkspaceName,
    this.uploadedAudioId,
    this.errorMessage,
    this.uploadProgress = 0,
    this.inputDevices = const [],
    this.selectedDevice,
  });

  bool get isRecording => status == RecordStatus.recording;
  bool get isPaused => status == RecordStatus.paused;
  bool get isActive =>
      status == RecordStatus.recording || status == RecordStatus.paused;

  RecordState copyWith({
    RecordStatus? status,
    bool? captureSystemAudio,
    String? selectedWorkspaceId,
    String? selectedWorkspaceName,
    String? uploadedAudioId,
    String? errorMessage,
    double? uploadProgress,
    List<InputDevice>? inputDevices,
    InputDevice? selectedDevice,
    bool clearDevice = false,
  }) =>
      RecordState(
        status: status ?? this.status,
        captureSystemAudio: captureSystemAudio ?? this.captureSystemAudio,
        selectedWorkspaceId: selectedWorkspaceId ?? this.selectedWorkspaceId,
        selectedWorkspaceName:
            selectedWorkspaceName ?? this.selectedWorkspaceName,
        uploadedAudioId: uploadedAudioId ?? this.uploadedAudioId,
        errorMessage: errorMessage ?? this.errorMessage,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        inputDevices: inputDevices ?? this.inputDevices,
        selectedDevice:
            clearDevice ? null : (selectedDevice ?? this.selectedDevice),
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class RecordNotifier extends StateNotifier<RecordState> {
  final AudioIngestApi _api;
  final AudioRecorder _recorder = AudioRecorder();
  final SystemAudioService _sysAudio = SystemAudioService();

  String? _sysAudioPath;
  String? _micAudioPath;

  RecordNotifier(this._api) : super(const RecordState()) {
    _loadDevices();
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  Future<void> _loadDevices() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;
    final devices = await _recorder.listInputDevices();
    state = state.copyWith(inputDevices: devices);
  }

  Future<void> refreshDevices() => _loadDevices();

  void selectDevice(InputDevice? device) => state =
      state.copyWith(selectedDevice: device, clearDevice: device == null);

  // ── Source / Workspace ────────────────────────────────────────────────────

  void setCaptureSystemAudio(bool value) =>
      state = state.copyWith(captureSystemAudio: value);

  void selectWorkspace(String id, String name) => state =
      state.copyWith(selectedWorkspaceId: id, selectedWorkspaceName: name);

  void clearWorkspace() => state = RecordState(
        inputDevices: state.inputDevices,
        selectedDevice: state.selectedDevice,
        captureSystemAudio: state.captureSystemAudio,
      );

  // ── Record controls ───────────────────────────────────────────────────────

  Future<void> toggleRecording() async {
    if (state.status == RecordStatus.recording) {
      await _stopAndUpload();
    } else if (state.status == RecordStatus.paused) {
      await _stopAndUpload();
    } else {
      await _startRecording();
    }
  }

  Future<void> togglePause() async {
    if (state.status == RecordStatus.recording) {
      await _recorder.pause();
      state = state.copyWith(status: RecordStatus.paused);
    } else if (state.status == RecordStatus.paused) {
      await _recorder.resume();
      state = state.copyWith(status: RecordStatus.recording);
    }
  }

  Future<void> _startRecording() async {
    if (state.selectedWorkspaceId == null ||
        state.selectedWorkspaceId!.isEmpty) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'Please select a workspace before recording.\n'
            'Choose one from the dropdown below or create a new one with "+".',
      );
      return;
    }

    if (state.captureSystemAudio && !Platform.isLinux) {
      await _startMicAndSystem();
    } else {
      await _startMicrophone();
    }
  }

  Future<void> _startMicrophone() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: Platform.isLinux
            ? 'Microphone permission denied. Check your system audio settings.'
            : 'Microphone permission denied.\n'
                'Go to System Settings → Privacy & Security → Microphone and enable the app.',
      );
      return;
    }

    if (state.inputDevices.isEmpty) {
      final devices = await _recorder.listInputDevices();
      state = state.copyWith(inputDevices: devices);
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        device: state.selectedDevice,
      ),
      path: path,
    );

    state = state.copyWith(status: RecordStatus.recording);
  }

  Future<void> _startMicAndSystem() async {
    final micGranted = await _recorder.hasPermission();
    if (!micGranted) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'Microphone permission denied.\n'
            'Go to System Settings → Privacy & Security → Microphone and enable the app.',
      );
      return;
    }

    final systemGranted = await _sysAudio.requestPermission();
    if (!systemGranted) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'Screen & System Audio Recording permission denied.\n'
            'Go to System Settings → Privacy & Security → Screen & System Audio Recording.',
      );
      return;
    }

    if (state.inputDevices.isEmpty) {
      final devices = await _recorder.listInputDevices();
      state = state.copyWith(inputDevices: devices);
    }

    final dir = await getTemporaryDirectory();
    final micPath =
        '${dir.path}/microphone_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      _sysAudioPath = await _sysAudio.startRecording(mode: 'system');
      _micAudioPath = micPath;
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          device: state.selectedDevice,
        ),
        path: micPath,
      );
      state = state.copyWith(status: RecordStatus.recording);
    } on Exception catch (e) {
      try { await _sysAudio.stopRecording(); } catch (_) {}
      _sysAudioPath = null;
      _micAudioPath = null;
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'Failed to start combined audio capture: $e',
      );
    }
  }

  Future<void> _stopAndUpload() async {
    String? path;

    if (state.captureSystemAudio && !Platform.isLinux) {
      final systemPath = _sysAudioPath;
      final micFallbackPath = _micAudioPath;
      Object? systemStopError;

      try {
        await _sysAudio.stopRecording();
      } catch (e) {
        systemStopError = e;
      } finally {
        _sysAudioPath = null;
      }

      final stoppedMicPath = await _recorder.stop();
      final micPath = stoppedMicPath ?? micFallbackPath;
      _micAudioPath = null;

      final hasSystem = systemPath != null && File(systemPath).existsSync();
      final hasMic = micPath != null && File(micPath).existsSync();

      if (hasSystem && hasMic) {
        try {
          path = await _sysAudio.mixWithMicrophone(
            systemPath: systemPath,
            microphonePath: micPath,
          );
        } on Exception catch (e) {
          state = state.copyWith(
            status: RecordStatus.error,
            errorMessage: 'Failed to mix audio: $e',
          );
          return;
        }
      } else if (hasMic) {
        path = micPath;
      } else if (hasSystem) {
        path = systemPath;
      } else {
        state = state.copyWith(
          status: RecordStatus.error,
          errorMessage: systemStopError is PlatformException
              ? systemStopError.message ?? 'No audio was captured.'
              : 'No audio was captured.',
        );
        return;
      }
    } else {
      path = await _recorder.stop();
    }

    if (path == null) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'Recording failed: no output file.',
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'No audio was captured.',
      );
      return;
    }

    await uploadFile(file);
  }

  Future<void> uploadFile(File file) async {
    final workspaceId = state.selectedWorkspaceId;
    if (workspaceId == null || workspaceId.isEmpty) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorMessage: 'No workspace selected. Please select or create a workspace first.',
      );
      return;
    }

    state = state.copyWith(
      status: RecordStatus.uploading,
      uploadProgress: 0,
      errorMessage: null,
    );
    try {
      final audioId = await _api.uploadAudio(
        workspaceId: workspaceId,
        audioFile: file,
        onProgress: (sent, total) {
          if (total > 0) state = state.copyWith(uploadProgress: sent / total);
        },
      );
      state = state.copyWith(
        status: RecordStatus.done,
        uploadedAudioId: audioId,
        uploadProgress: 1,
      );
    } on AppException catch (e) {
      state =
          state.copyWith(status: RecordStatus.error, errorMessage: e.message);
    }
  }

  void reset() => state = RecordState(
        selectedWorkspaceId: state.selectedWorkspaceId,
        selectedWorkspaceName: state.selectedWorkspaceName,
        inputDevices: state.inputDevices,
        selectedDevice: state.selectedDevice,
        captureSystemAudio: state.captureSystemAudio,
      );

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}

final recordNotifierProvider =
    StateNotifierProvider<RecordNotifier, RecordState>((ref) {
  return RecordNotifier(ref.read(audioIngestApiProvider));
});


// ─── State ────────────────────────────────────────────────────────────────────
