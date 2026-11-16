import 'dart:async';
import 'dart:io';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/ios_audio_capture.dart';
import 'package:dict_ai/features/record/data/wav_validator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

// Explicit native target; the production entrypoint never imports this file.
// Use silence or a test tone: the capture phase really activates the microphone.
const _compiledPhase = String.fromEnvironment(
  'DICTAI_IOS_AUDIO_PHASE',
  defaultValue: 'capture',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final phase =
      Platform.environment['DICTAI_IOS_AUDIO_PHASE'] ?? _compiledPhase;
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('DictAI microphone verification')),
    ),
  );
  if (!Platform.isIOS ||
      !const {'capture', 'permission_denied'}.contains(phase)) {
    stdout.writeln('DICTAI_IOS_AUDIO FAIL invalid_configuration');
    exit(2);
  }
  final smoke = _AudioSmoke();
  stdout.writeln('DICTAI_IOS_AUDIO START $phase');
  var passed = false;
  try {
    await smoke.run(phase).timeout(const Duration(seconds: 45));
    passed = true;
  } catch (_) {
    // Do not log exceptions, private sandbox paths or audio bytes.
    stdout.writeln(
      'DICTAI_IOS_AUDIO FAIL $phase checkpoint=${smoke.checkpoint}',
    );
  } finally {
    try {
      await smoke.cleanup().timeout(const Duration(seconds: 15));
    } catch (_) {
      passed = false;
      stdout.writeln('DICTAI_IOS_AUDIO FAIL $phase checkpoint=cleanup');
    }
  }
  if (passed) stdout.writeln('DICTAI_IOS_AUDIO PASS $phase');
  exit(passed ? 0 : 1);
}

final class _AudioSmoke {
  String checkpoint = 'configuration';
  final _captures = <IosAudioCapture>[];
  final _ownedFiles = <String>{};

  IosAudioCapture _create() {
    final capture = IosAudioCapture(
      channel: const _DiagnosticChannel(),
      commandTimeout: const Duration(seconds: 5),
      permissionTimeout: const Duration(seconds: 15),
    );
    _captures.add(capture);
    return capture;
  }

  Future<void> run(String phase) async {
    final capture = _create();
    checkpoint = 'probe';
    _require((await capture.listInputDevices()).isEmpty);
    _require(capture.status == CaptureStatus.idle);
    checkpoint = 'start';
    if (phase == 'permission_denied') {
      var denied = false;
      try {
        await capture.start();
      } on ValidationException catch (error) {
        denied = error.message.contains('настройках iPhone');
      }
      _remember(capture);
      _require(denied && capture.status == CaptureStatus.failed);
      _require(capture.sourcePath == null);
      checkpoint = 'dispose_denied';
      await capture.dispose();
      _require(capture.status == CaptureStatus.disposed);
      return;
    }

    await capture.start();
    _remember(capture);
    _require(capture.status == CaptureStatus.recording);
    await capture.start();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    checkpoint = 'pause';
    await capture.pause();
    await capture.pause();
    _require(capture.status == CaptureStatus.paused);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    checkpoint = 'cancel_finish';
    _require(await capture.finish(confirmed: false) == null);
    _require(capture.status == CaptureStatus.paused);
    checkpoint = 'resume';
    await capture.resume();
    await capture.resume();
    _require(capture.status == CaptureStatus.recording);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    checkpoint = 'finish';
    final file = await capture.finish(confirmed: true);
    _require(file != null && capture.status == CaptureStatus.finished);
    _require(identical(file, await capture.finish(confirmed: true)));
    checkpoint = 'validate';
    final wav = await const WavValidator().validate(file!);
    _require(
      wav.encoding == WavEncoding.pcm &&
          wav.sampleRate == 16000 &&
          wav.bitsPerSample == 16 &&
          wav.channels == 1 &&
          wav.dataBytes > 0,
    );
    checkpoint = 'dispose_finished';
    await capture.dispose();
    await capture.dispose();
    _require(capture.status == CaptureStatus.disposed);
    _require(await file.exists());

    // A fresh native owner proves that the first recorder released the session.
    checkpoint = 'second_owner';
    final second = _create();
    await second.start();
    _remember(second);
    _require(second.status == CaptureStatus.recording);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    checkpoint = 'dispose_active';
    await second.dispose();
    _require(second.status == CaptureStatus.disposed);
    _require(await File(second.sourcePath!).exists());
  }

  void _remember(IosAudioCapture capture) {
    final path = capture.sourcePath;
    if (path != null) _ownedFiles.add(path);
  }

  Future<void> cleanup() async {
    for (final capture in _captures) {
      // Also remember a path allocated by a start that failed or timed out.
      _remember(capture);
      await capture.dispose();
      _remember(capture);
    }
    for (final path in _ownedFiles) {
      final file = File(path);
      if (await file.exists()) await file.delete();
      // The bridge gives each capture its own directory. Never delete recursively.
      if (await file.parent.exists()) await file.parent.delete();
    }
  }
}

final class _DiagnosticChannel extends MethodChannel {
  const _DiagnosticChannel() : super('com.dictai/ios_audio');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await super.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      const codes = {
        'recording_failed',
        'permission_denied',
        'session_cleanup',
        'unavailable',
        'busy',
        'cancelled',
        'interrupted',
      };
      const stages = {
        'category',
        'sample_rate',
        'activate',
        'directory',
        'recorder',
        'prepare',
        'protection',
        'record',
      };
      final code = codes.contains(error.code) ? error.code : 'other';
      final stage = stages.contains(error.details) ? error.details : 'none';
      stdout.writeln('DICTAI_IOS_AUDIO native=$code stage=$stage');
      rethrow;
    }
  }
}

void _require(bool value) {
  if (!value) throw StateError('Audio smoke assertion failed');
}
