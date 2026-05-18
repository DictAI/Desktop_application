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

  /// Starts capturing audio. Saves to a temp .wav file.
  /// [mode] can be "system" (default) or "both" (system + microphone mixed).
  /// Returns the output file path.
  Future<String> startRecording({String mode = 'system'}) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/sysaudio_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _channel.invokeMethod<void>('startRecording', {
      'path': path,
      'mode': mode,
    });
    return path;
  }

  /// Mixes two WAV files and returns a new temp .wav path.
  Future<String> mixWithMicrophone({
    required String systemPath,
    required String microphonePath,
  }) async {
    final dir = await getTemporaryDirectory();
    final outputPath =
        '${dir.path}/mixed_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _channel.invokeMethod<void>('mixWavFiles', {
      'systemPath': systemPath,
      'microphonePath': microphonePath,
      'outputPath': outputPath,
    });
    return outputPath;
  }

  /// Stops capturing and finalises the file.
  /// Throws [PlatformException] if no audio was captured.
  Future<void> stopRecording() async {
    await _channel.invokeMethod<void>('stopRecording');
  }
}
