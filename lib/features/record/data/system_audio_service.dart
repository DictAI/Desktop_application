import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// ScreenCaptureKit bridge for macOS 13+. The native stream records system
/// audio, while the Dart capture adapter manages the microphone separately.
class SystemAudioService {
  SystemAudioService({
    MethodChannel channel = const MethodChannel('com.dictai/system_audio'),
    Future<Directory> Function()? temporaryDirectory,
    bool? isMacOS,
    Duration commandTimeout = const Duration(seconds: 45),
    Duration processingTimeout = const Duration(minutes: 15),
  }) : _channel = channel,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _isMacOS = isMacOS ?? Platform.isMacOS,
       _commandTimeout = commandTimeout,
       _processingTimeout = processingTimeout;

  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _isMacOS;
  final Duration _commandTimeout;
  final Duration _processingTimeout;
  Completer<void>? _pendingCancellation;
  Future<void>? _disposal;
  bool _disposed = false;
  static int _nextPath = 0;

  static bool get isSupported => Platform.isMacOS;

  Future<bool> requestPermission() async {
    if (!_isMacOS) return false;
    try {
      return await _invoke<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Returns the system WAV destination. The file is complete only after Stop.
  /// The `mode` argument remains available for existing channel callers.
  Future<String> startRecording({String mode = 'system'}) async {
    final path = await _outputPath('sysaudio');
    await _invoke<void>('startRecording', {'path': path, 'mode': mode});
    return path;
  }

  /// Mixes both complete sources into a new WAV and preserves the inputs.
  Future<String> mixWithMicrophone({
    required String systemPath,
    required String microphonePath,
  }) async {
    final path = await _outputPath('mixed');
    try {
      await _invoke<void>('mixWavFiles', {
        'systemPath': systemPath,
        'microphonePath': microphonePath,
        'outputPath': path,
      }, _processingTimeout);
    } catch (_) {
      // This unique destination belongs to this call, never to the user.
      final file = File(path);
      if (await file.exists()) await file.delete();
      rethrow;
    }
    return path;
  }

  Future<void> stopRecording() async {
    _requireMacOS();
    await _invoke<void>('stopRecording', null, _processingTimeout);
  }

  /// Cancels pending native capture/conversion without publishing a recording.
  /// This is independent of a pending MethodChannel reply.
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    _disposed = true;
    final work = !_isMacOS
        ? Future<void>.value()
        : _channel
              .invokeMethod<void>('cancelRecording')
              .timeout(_commandTimeout);
    _disposal = work;
    final pending = _pendingCancellation;
    if (pending != null && !pending.isCompleted) pending.complete();
    unawaited(work.then((_) {}, onError: (Object _) => _disposal = null));
    return work;
  }

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object>? arguments,
    Duration? timeout,
  ]) async {
    _requireMacOS();
    if (_disposed) throw PlatformException(code: 'CANCELLED');
    final cancelled = Completer<void>();
    _pendingCancellation = cancelled;
    try {
      return await Future.any<T?>([
        _channel.invokeMethod<T>(method, arguments),
        cancelled.future.then<T?>(
          (_) => throw PlatformException(code: 'CANCELLED'),
        ),
      ]).timeout(timeout ?? _commandTimeout);
    } on TimeoutException {
      // A timed-out start may still be active natively. Do not leave it running.
      try {
        await _channel
            .invokeMethod<void>('cancelRecording')
            .timeout(_commandTimeout);
      } catch (_) {
        // The initial timeout stays explicit. Cleanup has its own deadline.
      }
      rethrow;
    } catch (_) {
      // Await the independent cancellation acknowledgement before a caller
      // removes a destination that the writer may have just completed.
      final disposal = _disposal;
      if (disposal != null) {
        try {
          await disposal;
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (identical(_pendingCancellation, cancelled)) {
        _pendingCancellation = null;
      }
    }
  }

  Future<String> _outputPath(String prefix) async {
    _requireMacOS();
    final dir = await _temporaryDirectory();
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${dir.path}/${prefix}_${now}_${++_nextPath}.wav';
  }

  void _requireMacOS() {
    if (!_isMacOS) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'System audio capture requires macOS.',
      );
    }
  }
}
