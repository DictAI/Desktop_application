import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../../../core/error/app_exception.dart';
import 'audio_capture.dart';
import 'wav_validator.dart';

/// iOS microphone only. The native bridge owns the session and WAV recorder.
final class IosAudioCapture implements AudioCapture, AudioCaptureEvents {
  IosAudioCapture({
    MethodChannel channel = const MethodChannel('com.dictai/ios_audio'),
    Stream<dynamic>? events,
    Duration commandTimeout = const Duration(seconds: 10),
    Duration permissionTimeout = const Duration(minutes: 2),
  }) : _channel = channel,
       _commandTimeout = commandTimeout,
       _permissionTimeout = permissionTimeout {
    _subscription = (events ?? _nativeEvents).listen(
      _nativeEvent,
      onError: (Object _) {
        if (_disposeRequested) return;
        _streamFailed = true;
        _publish(
          CaptureStatus.failed,
          'Связь с микрофоном прервана. Доступный WAV сохранён.',
        );
        unawaited(_releaseNative().catchError((Object _) {}));
      },
    );
  }

  static final _nativeEvents = const EventChannel(
    'com.dictai/ios_audio_events',
  ).receiveBroadcastStream();
  static int _nextID = 0;
  final String _id =
      'ios-${DateTime.now().microsecondsSinceEpoch}-${++_nextID}';
  final MethodChannel _channel;
  final Duration _commandTimeout;
  final Duration _permissionTimeout;
  final _events = StreamController<CaptureEvent>.broadcast(sync: true);
  late final StreamSubscription<dynamic> _subscription;
  Future<void> _tail = Future.value();
  Future<void>? _disposal;
  CaptureStatus _status = CaptureStatus.idle;
  bool _disposeRequested = false;
  bool _streamFailed = false;
  int _revision = -1;
  String? _path;
  File? _finished;

  @override
  CaptureStatus get status => _status;
  @override
  bool get supportsPause => true;
  @override
  String? get sourcePath => _path;
  @override
  Stream<CaptureEvent> get captureEvents => _events.stream;

  void _publish(CaptureStatus status, [String? message]) {
    if (_disposeRequested || _events.isClosed) return;
    _status = status;
    _events.add(CaptureEvent(status, message: message));
  }

  void _nativeEvent(dynamic value) {
    if (value is Map && value['id'] == _id) _apply(value);
  }

  void _apply(Map<dynamic, dynamic> value) {
    final revision = value['revision'];
    if (_disposeRequested || revision is! int || revision < _revision) return;
    _revision = revision;
    final path = value['path'];
    if (path is String) _path ??= path;
    // Stream faults have no native revision. A delayed command reply may still
    // recover the owned path, but cannot restore an unobservable recorder.
    if (_streamFailed) return;
    final next = switch (value['status']) {
      'recording' => CaptureStatus.recording,
      'paused' => CaptureStatus.paused,
      'finished' => CaptureStatus.finished,
      'failed' => CaptureStatus.failed,
      _ => null,
    };
    if (next != null) {
      _publish(
        next,
        value['message'] is String ? value['message'] as String : null,
      );
    }
  }

  Future<T> _queue<T>(Future<T> Function() work) {
    if (_disposeRequested) return Future.error(_closed);
    final before = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await before;
      try {
        if (_disposeRequested) throw _closed;
        if (_streamFailed) throw _failed;
        return await work();
      } finally {
        done.complete();
      }
    }();
  }

  static const _closed = ValidationException(
    'Запись закрыта. Начните новую запись.',
  );
  static const _failed = ServerException(
    'Не удалось продолжить запись микрофона. Доступный WAV сохранён.',
  );

  Future<Map<dynamic, dynamic>> _invoke(
    String command, {
    Duration? timeout,
  }) async {
    try {
      final value = await _channel
          .invokeMapMethod<dynamic, dynamic>(command, {'id': _id})
          .timeout(timeout ?? _commandTimeout);
      if (value == null) throw _failed;
      _apply(value);
      if (_streamFailed) throw _failed;
      return value;
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied') {
        throw const ValidationException(
          'Разрешите доступ к микрофону в настройках iPhone.',
        );
      }
      if (error.code == 'interrupted') {
        throw const ValidationException(
          'Дождитесь завершения прерывания и нажмите «Продолжить».',
        );
      }
      if (error.code == 'cancelled') throw _closed;
      throw _failed;
    } on TimeoutException {
      // A timed out method can still finish natively. Release by identity now.
      await _releaseNative();
      _publish(
        CaptureStatus.failed,
        'Микрофон не ответил вовремя. Доступный WAV сохранён.',
      );
      throw _failed;
    } on MissingPluginException {
      throw const ServerException('Аудиоадаптер iOS недоступен в этой сборке.');
    }
  }

  Future<void> _releaseNative() async {
    try {
      await _channel
          .invokeMethod<void>('dispose', {'id': _id})
          .timeout(_commandTimeout);
    } catch (_) {
      throw const ServerException(
        'Не удалось освободить микрофон. Повторите попытку.',
      );
    }
  }

  @override
  Future<List<InputDevice>> listInputDevices() async => const [];

  @override
  Future<void> start({InputDevice? device}) => _queue(() async {
    if (_status == CaptureStatus.recording || _status == CaptureStatus.paused) {
      return;
    }
    if (_status != CaptureStatus.idle) throw _closed;
    _status = CaptureStatus.starting;
    try {
      await _invoke('start', timeout: _permissionTimeout);
      if (_disposeRequested) throw _closed;
      if (_status != CaptureStatus.recording &&
          _status != CaptureStatus.paused) {
        throw _failed;
      }
    } catch (_) {
      _status = CaptureStatus.failed;
      await _releaseNative();
      rethrow;
    }
  });

  @override
  Future<void> pause() => _queue(() async {
    if (_status != CaptureStatus.recording) return;
    await _invoke('pause');
  });

  @override
  Future<void> resume() => _queue(() async {
    if (_status != CaptureStatus.paused) return;
    await _invoke('resume');
  });

  @override
  Future<File?> finish({required bool confirmed}) {
    if (!confirmed) return Future.value();
    return _queue(() async {
      if (_finished != null) return _finished;
      if (_status != CaptureStatus.recording &&
          _status != CaptureStatus.paused) {
        throw const ValidationException('Нет активной записи для завершения.');
      }
      _status = CaptureStatus.finalizing;
      try {
        final value = await _invoke('finish');
        final path = value['path'];
        if (path is! String ||
            path != _path ||
            _status != CaptureStatus.finished) {
          throw _failed;
        }
        final file = File(path);
        final wav = await const WavValidator()
            .validate(file)
            .timeout(_commandTimeout, onTimeout: () => throw _failed);
        if (wav.encoding != WavEncoding.pcm ||
            wav.bitsPerSample != 16 ||
            wav.sampleRate != 16000 ||
            wav.channels != 1) {
          throw _failed;
        }
        _finished = file;
        return file;
      } catch (_) {
        _publish(
          CaptureStatus.failed,
          'Не удалось завершить WAV. Доступный исходник сохранён.',
        );
        rethrow;
      } finally {
        await _releaseNative();
      }
    });
  }

  @override
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _disposeRequested = true;
    // Do not wait behind a permission prompt/start command to cancel it.
    final work = () async {
      try {
        await _releaseNative();
        await _tail.timeout(_commandTimeout);
        _status = CaptureStatus.disposed;
      } finally {
        await _subscription.cancel();
        await _events.close();
      }
    }();
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
