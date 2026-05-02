import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Wraps the native ScreenCaptureKit Method Channel.
/// Only functional on macOS 13+.
class SystemAudioService {
  static const _channel = MethodChannel('com.dictai/system_audio');

  static bool get isSupported =>
      Platform.isMacOS; // runtime macOS version check is done natively

  /// Requests "Screen & System Audio Recording" permission.
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Starts capturing system audio. Saves to a temp .m4a file.
  /// Returns the output file path.
  Future<String> startRecording() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/sysaudio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _channel.invokeMethod<void>('startRecording', {'path': path});
    return path;
  }

  /// Stops capturing and finalises the file.
  Future<void> stopRecording() async {
    await _channel.invokeMethod<void>('stopRecording');
  }
}
