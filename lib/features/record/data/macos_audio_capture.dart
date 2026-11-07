import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../../../core/error/app_exception.dart';
import 'audio_capture.dart';
import 'microphone_capture.dart';
import 'system_audio_service.dart';
import 'wav_validator.dart';

/// Combined system and microphone capture. The app must explicitly choose
/// MicrophoneCapture for mic-only; failure of either input cannot downgrade.
final class MacosAudioCapture implements AudioCapture {
  MacosAudioCapture({SystemAudioService? system, AudioCapture? microphone})
    : _system = system ?? SystemAudioService(),
      _microphone = microphone ?? MicrophoneCapture();

  final SystemAudioService _system;
  final AudioCapture _microphone;
  Future<void> _tail = Future<void>.value();
  Future<void>? _disposal;
  bool _disposeRequested = false;
  bool _systemActive = false;
  CaptureStatus _status = CaptureStatus.idle;
  String? _systemPath;
  File? _finished;

  @override
  CaptureStatus get status => _status;
  @override
  bool get supportsPause => false;
  // Expose only the combined source. A failed mix must not look like a
  // successful recording of either individual track to an upload caller.
  @override
  String? get sourcePath => _finished?.path;

  @override
  Future<List<InputDevice>> listInputDevices() =>
      _queue(_microphone.listInputDevices);

  @override
  Future<void> start({InputDevice? device}) => _queue(() async {
    if (_status == CaptureStatus.recording) return;
    _status = CaptureStatus.starting;
    _finished = null;
    _systemPath = null;
    try {
      _systemPath = await _system.startRecording();
      _systemActive = true;
      if (_disposeRequested) throw _closed;
      await _microphone.start(device: device);
      if (_disposeRequested) throw _closed;
      _status = CaptureStatus.recording;
    } catch (error) {
      _status = CaptureStatus.failed;
      try {
        await _stopSystem();
      } catch (_) {
        // Keep the initial failure. The native stop handler owns its cleanup.
      }
      throw _failure(error);
    }
  });

  @override
  Future<void> pause() async => throw _pauseUnavailable;
  @override
  Future<void> resume() async => throw _pauseUnavailable;

  @override
  Future<File?> finish({required bool confirmed}) {
    if (!confirmed) return Future<File?>.value();
    return _queue(() async {
      if (_finished != null) return _finished;
      if (_status != CaptureStatus.recording) {
        throw const ValidationException('Нет активной записи для завершения.');
      }
      _status = CaptureStatus.finalizing;
      try {
        File? microphone;
        // Stop both as close together as possible. Wait for both cleanup
        // outcomes even when one source fails, then mix only complete files.
        await Future.wait<void>([
          _stopSystem(),
          () async {
            microphone = await _microphone.finish(confirmed: true);
          }(),
        ]);
        if (_disposeRequested) throw _closed;
        final system = _systemPath;
        final mic = microphone;
        if (system == null || mic == null) throw _incomplete;
        final output = File(
          await _system.mixWithMicrophone(
            systemPath: system,
            microphonePath: mic.path,
          ),
        );
        try {
          if (_disposeRequested) throw _closed;
          final metadata = await const WavValidator().validate(output);
          if (metadata.encoding != WavEncoding.pcm ||
              metadata.sampleRate != 16000 ||
              metadata.channels != 1 ||
              metadata.bitsPerSample != 16) {
            throw _incomplete;
          }
          if (_disposeRequested) throw _closed;
        } catch (_) {
          if (await output.exists()) await output.delete();
          rethrow;
        }
        _finished = output;
        _status = CaptureStatus.finished;
        return output;
      } catch (error) {
        _status = CaptureStatus.failed;
        throw _failure(error);
      }
    });
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _disposeRequested = true;
    final systemStop = Future<void>.sync(_system.dispose);
    // The microphone owns its own queue and can cancel a pending permission
    // wait. Waiting for the combined start first would deadlock that cleanup.
    final microphoneStop = Future<void>.sync(_microphone.dispose);
    final disposal = () async {
      try {
        await Future.wait<void>([systemStop, microphoneStop]);
        // Drain the combined operation after independently cancelling its
        // native commands. Late replies cannot publish a successful file.
        await _enqueue(() async {});
        _systemActive = false;
        _status = CaptureStatus.disposed;
      } catch (error) {
        _status = CaptureStatus.failed;
        throw _failure(error);
      }
    }();
    _disposal = disposal;
    unawaited(disposal.then((_) {}, onError: (Object _) => _disposal = null));
    return disposal;
  }

  Future<void> _stopSystem() async {
    if (!_systemActive) return;
    _systemActive = false;
    await _system.stopRecording();
  }

  Future<T> _queue<T>(Future<T> Function() action) {
    if (_disposeRequested) return Future.error(_closed);
    return _enqueue(() {
      if (_disposeRequested) throw _closed;
      return action();
    });
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

  static const _closed = ValidationException('Запись уже закрыта.');
  static const _pauseUnavailable = ValidationException(
    'Пауза недоступна при записи системного звука вместе с микрофоном.',
  );
  static const _incomplete = ServerException(
    'Не удалось создать полную запись из системного звука и микрофона.',
  );

  static AppException _failure(Object error) {
    if (error is AppException) return error;
    if (error is PlatformException) {
      return switch (error.code) {
        'PERMISSION_DENIED' => const ValidationException(
          'Разрешите запись системного звука в настройках конфиденциальности macOS.',
        ),
        'NO_DISPLAY' => const ValidationException(
          'Нет доступного экрана для захвата системного звука.',
        ),
        'NO_AUDIO' => const ValidationException(
          'Системный звук не записан. Проверьте источник звука и повторите запись.',
        ),
        'TOO_LONG' => const ValidationException(
          'Длительность записи превышает два часа.',
        ),
        'CLEANUP_PENDING' => const ValidationException(
          'Остановка предыдущего захвата системного звука не подтверждена. Повторите завершение записи.',
        ),
        _ => _incomplete,
      };
    }
    return _incomplete;
  }
}
