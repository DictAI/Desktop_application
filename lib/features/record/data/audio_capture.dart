import 'dart:io';

import 'package:record/record.dart';

enum CaptureStatus {
  idle,
  starting,
  recording,
  paused,
  finalizing,
  finished,
  failed,
  disposed,
}

/// File-based capture shared by the two upload modes. Dialogs belong to the UI.
abstract interface class AudioCapture {
  CaptureStatus get status;
  bool get supportsPause;
  String? get sourcePath;
  Future<List<InputDevice>> listInputDevices();
  Future<void> start({InputDevice? device});
  Future<void> pause();
  Future<void> resume();

  /// A cancelled confirmation must leave recording/paused capture untouched.
  Future<File?> finish({required bool confirmed});

  /// Forced lifecycle cleanup never uploads or deletes captured source files.
  Future<void> dispose();
}

/// Optional native state changes (interruptions or hardware failures).
/// Desktop adapters and their fakes need not implement this capability.
abstract interface class AudioCaptureEvents {
  Stream<CaptureEvent> get captureEvents;
}

final class CaptureEvent {
  const CaptureEvent(this.status, {this.message});

  final CaptureStatus status;
  final String? message;
}
