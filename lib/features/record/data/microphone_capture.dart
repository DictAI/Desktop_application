import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/error/app_exception.dart';
import 'audio_capture.dart';
import 'wav_validator.dart';

/// macOS mic capture using the pinned record plugin's PCM WAV encoder.
/// The platform API lets cleanup run independently of a lost Stop callback.
final class MicrophoneCapture implements AudioCapture {
  MicrophoneCapture({
    RecordPlatform? platform,
    Future<Directory> Function()? temporaryDirectory,
    bool? isMacOS,
    Duration commandTimeout = const Duration(seconds: 10),
  }) : _platform = platform ?? RecordPlatform.instance,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _isMacOS = isMacOS ?? Platform.isMacOS,
       _commandTimeout = commandTimeout;

  final RecordPlatform _platform;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _isMacOS;
  final Duration _commandTimeout;
  static int _nextRecorder = 0;
  final String _nativeId = 'dictai-mic-${++_nextRecorder}';
  String? _recorderId;
  Completer<bool>? _pendingPermission;
  Future<void> _tail = Future<void>.value();
  bool _disposeRequested = false;
  Future<void>? _disposal;
  CaptureStatus _status = CaptureStatus.idle;
  String? _sourcePath;
  File? _finished;

  @override
  CaptureStatus get status => _status;
  @override
  bool get supportsPause => _isMacOS;
  @override
  String? get sourcePath => _sourcePath;

  // Serializes start/stop/dispose, including disposal during a permission prompt.
  Future<T> _queue<T>(Future<T> Function() action) {
    if (_disposeRequested) return Future.error(_unavailable);
    if (!_isMacOS) return Future.error(_unsupported);
    return _enqueue(action);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        done.complete();
      }
    }();
  }

  static const _unavailable = ValidationException(
    'Запись уже закрыта. Начните новую запись.',
  );
  static const _failed = ServerException(
    'Не удалось завершить запись микрофона. Доступный исходный файл сохранён.',
  );

  static const _unsupported = ValidationException(
    'Запись на этой платформе требует отдельного аудиоадаптера.',
  );

  Future<T> _bounded<T>(Future<T> command) => command.timeout(_commandTimeout);

  Future<String> _ensureRecorder() async {
    if (_recorderId case final String id) return id;
    // Reuse the channels for this adapter. Pinned Darwin leaves the channel
    // registrations in the messenger after disposing the recorder.
    final id = _nativeId;
    _recorderId = id;
    try {
      await _bounded(_platform.create(id));
    } on TimeoutException {
      // Native creation may have succeeded. Preserve the id for cleanup.
      rethrow;
    } catch (_) {
      _recorderId = null;
      rethrow;
    }
    return id;
  }

  Future<bool> _requestPermission(String id) async {
    if (_disposeRequested) throw _unavailable;
    final cancelled = Completer<bool>();
    _pendingPermission = cancelled;
    try {
      return await Future.any([_platform.hasPermission(id), cancelled.future]);
    } finally {
      _pendingPermission = null;
    }
  }

  @override
  Future<List<InputDevice>> listInputDevices() => _queue(() async {
    try {
      final id = await _ensureRecorder();
      return List.unmodifiable(await _bounded(_platform.listInputDevices(id)));
    } catch (_) {
      throw const ServerException(
        'Не удалось получить список микрофонов. Проверьте разрешения и устройства.',
      );
    }
  });

  @override
  Future<void> start({InputDevice? device}) => _queue(() async {
    if (_status == CaptureStatus.recording || _status == CaptureStatus.paused) {
      return;
    }
    if (_status == CaptureStatus.failed && _recorderId != null) {
      await _release();
    }
    _status = CaptureStatus.starting;
    _finished = null;
    _sourcePath = null;
    try {
      final id = await _ensureRecorder();
      if (!await _requestPermission(id)) {
        throw const ValidationException(
          'Разрешите доступ к микрофону в настройках системы.',
        );
      }
      if (!await _bounded(_platform.isEncoderSupported(id, AudioEncoder.wav))) {
        throw const ValidationException(
          'Запись WAV недоступна на этом устройстве.',
        );
      }
      if (device != null &&
          !(await _bounded(
            _platform.listInputDevices(id),
          )).any((d) => d.id == device.id)) {
        throw const ValidationException(
          'Выбранный микрофон недоступен. Выберите устройство снова.',
        );
      }
      final directory = await (await _temporaryDirectory()).createTemp(
        'dictai-capture-',
      );
      _sourcePath = '${directory.path}/microphone.wav';
      if (_disposeRequested) throw _unavailable;
      await _bounded(
        _platform.start(
          id,
          RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
            device: device,
          ),
          path: _sourcePath!,
        ),
      );
      _status = CaptureStatus.recording;
    } catch (error) {
      _status = CaptureStatus.failed;
      await _release();
      if (error is AppException) rethrow;
      throw const ServerException(
        'Не удалось начать запись. Проверьте микрофон и разрешения.',
      );
    }
  });

  @override
  Future<void> pause() => _queue(() async {
    if (_status != CaptureStatus.recording) return;
    try {
      await _bounded(_platform.pause(_recorderId!));
      _status = CaptureStatus.paused;
    } catch (_) {
      _status = CaptureStatus.failed;
      await _release();
      throw _failed;
    }
  });

  @override
  Future<void> resume() => _queue(() async {
    if (_status != CaptureStatus.paused) return;
    try {
      await _bounded(_platform.resume(_recorderId!));
      _status = CaptureStatus.recording;
    } catch (_) {
      _status = CaptureStatus.failed;
      await _release();
      throw _failed;
    }
  });

  @override
  Future<File?> finish({required bool confirmed}) {
    if (!confirmed) return Future<File?>.value();
    return _queue(() async {
      if (_finished != null) {
        await _release();
        _status = CaptureStatus.finished;
        return _finished;
      }
      if (_status != CaptureStatus.recording &&
          _status != CaptureStatus.paused) {
        throw const ValidationException('Нет активной записи для завершения.');
      }
      _status = CaptureStatus.finalizing;
      try {
        final path = await _stop(_recorderId!);
        if (path == null || path != _sourcePath) throw _failed;
        final file = File(path);
        final metadata = await const WavValidator().validate(file);
        if (metadata.encoding != WavEncoding.pcm) throw _failed;
        _finished = file;
        _status = CaptureStatus.finished;
        return file;
      } catch (_) {
        _status = CaptureStatus.failed;
        throw _failed;
      } finally {
        await _release();
      }
    });
  }

  Future<String?> _stop(String id) async {
    if (!await _bounded(_platform.isRecording(id))) throw _failed;
    // Pinned Darwin can drop a late stop callback when its output already
    // ended. Dispose still has its own method call and does not share this wait.
    return _bounded(_platform.stop(id));
  }

  Future<void> _release() async {
    final id = _recorderId;
    if (id == null) return;
    try {
      await _bounded(_platform.dispose(id));
      _recorderId = null;
    } catch (_) {
      // Keep the handle for an explicit cleanup retry. Do not create a second
      // recorder while release of the previous one is unconfirmed.
      _status = CaptureStatus.failed;
      throw _failed;
    }
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _disposeRequested = true;
    final permission = _pendingPermission;
    if (permission != null && !permission.isCompleted) {
      permission.completeError(_unavailable);
    }
    final work = _enqueue(() async {
      try {
        if (_status == CaptureStatus.recording ||
            _status == CaptureStatus.paused) {
          // Lifecycle/security cleanup, not a user-confirmed successful finish.
          await _stop(_recorderId!);
        }
      } catch (_) {
        // Retain the path for recovery, even when finalization failed.
      } finally {
        await _release();
        _status = CaptureStatus.disposed;
      }
    });
    _disposal = work;
    work.then(
      (_) {},
      onError: (Object _) {
        _disposal = null;
      },
    );
    return work;
  }
}
