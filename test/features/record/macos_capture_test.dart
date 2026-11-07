import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/macos_audio_capture.dart';
import 'package:dict_ai/features/record/data/system_audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

Uint8List wav({int sampleRate = 16000}) {
  final bytes = Uint8List(48);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String text) =>
      bytes.setRange(offset, offset + text.length, text.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, 4, Endian.little);
  return bytes;
}

class Microphone implements AudioCapture {
  Microphone(this.file);
  final File file;
  int starts = 0, stops = 0, disposals = 0;
  bool failStart = false, failStop = false;
  final started = Completer<void>();
  Completer<void>? permission;
  @override
  CaptureStatus status = CaptureStatus.idle;
  @override
  bool get supportsPause => true;
  @override
  String? get sourcePath => file.path;
  @override
  Future<List<InputDevice>> listInputDevices() async => const [
    InputDevice(id: 'mic', label: 'Microphone'),
  ];
  @override
  Future<void> start({InputDevice? device}) async {
    starts++;
    if (!started.isCompleted) started.complete();
    if (permission != null) await permission!.future;
    if (failStart) throw const ValidationException('Нет доступа к микрофону.');
    await file.writeAsBytes(wav());
    status = CaptureStatus.recording;
  }

  @override
  Future<File?> finish({required bool confirmed}) async {
    if (!confirmed) return null;
    stops++;
    status = CaptureStatus.finished;
    if (failStop) throw const ServerException('Не удалось завершить микрофон.');
    return file;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    if (permission case final gate? when !gate.isCompleted) gate.complete();
    status = CaptureStatus.disposed;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.dictai/system_audio');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temp;
  late SystemAudioService service;
  late Microphone mic;
  late MacosAudioCapture capture;
  late List<MethodCall> calls;
  String? systemPath, mixedPath;
  String? startError, stopError;
  Uint8List? mixedBytes;
  Completer<void>? startGate, mixGate;
  bool mixCancelled = false;
  int cancelFailures = 0;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dictai-macos-capture-test-');
    calls = [];
    systemPath = mixedPath = startError = stopError = null;
    mixedBytes = null;
    startGate = mixGate = null;
    mixCancelled = false;
    cancelFailures = 0;
    service = SystemAudioService(
      channel: channel,
      isMacOS: true,
      temporaryDirectory: () async => temp,
      commandTimeout: const Duration(milliseconds: 100),
      processingTimeout: const Duration(milliseconds: 100),
    );
    mic = Microphone(File('${temp.path}/mic.wav'));
    capture = MacosAudioCapture(system: service, microphone: mic);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'requestPermission':
          return true;
        case 'startRecording':
          systemPath = args!['path'] as String;
          if (startGate != null) await startGate!.future;
          if (startError != null) throw PlatformException(code: startError!);
          return null;
        case 'stopRecording':
          if (stopError != null) throw PlatformException(code: stopError!);
          await File(systemPath!).writeAsBytes(wav());
          return null;
        case 'mixWavFiles':
          expect(await File(args!['systemPath'] as String).exists(), isTrue);
          expect(await File(args['microphonePath'] as String).exists(), isTrue);
          mixedPath = args['outputPath'] as String;
          if (mixGate != null) await mixGate!.future;
          if (mixCancelled) throw PlatformException(code: 'CANCELLED');
          await File(mixedPath!).writeAsBytes(mixedBytes ?? wav());
          return null;
        case 'cancelRecording':
          if (cancelFailures > 0) {
            cancelFailures--;
            throw PlatformException(code: 'STOP_FAILED');
          }
          mixCancelled = true;
          if (startGate case final gate? when !gate.isCompleted) {
            gate.complete();
          }
          if (mixGate case final gate? when !gate.isCompleted) gate.complete();
          return null;
      }
      throw MissingPluginException();
    });
  });
  tearDown(() async {
    await capture.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });
  int count(String method) =>
      calls.where((call) => call.method == method).length;

  test(
    'channel agreement and complete mixed PCM WAV, no source fallback',
    () async {
      expect(await service.requestPermission(), isTrue);
      await capture.start();
      expect(capture.sourcePath, isNull);
      expect(capture.supportsPause, isFalse);
      final result = await capture.finish(confirmed: true);
      expect(await result!.readAsBytes(), wav());
      expect(result.path, mixedPath);
      expect(result.path, isNot(systemPath));
      expect(result.path, isNot(mic.file.path));
      expect(capture.status, CaptureStatus.finished);
      expect(await File(systemPath!).exists(), isTrue);
      expect(await mic.file.exists(), isTrue);
      expect(
        (calls.firstWhere((call) => call.method == 'startRecording').arguments
            as Map)['mode'],
        'system',
      );
      await capture.dispose();
      expect(await result.exists(), isTrue);
    },
  );

  test(
    'cancel confirmation does not stop either input or change recording',
    () async {
      await capture.start();
      expect(await capture.finish(confirmed: false), isNull);
      expect(count('stopRecording'), 0);
      expect(mic.stops, 0);
      expect(capture.status, CaptureStatus.recording);
    },
  );

  test('duplicate commands serialize to one capture, stop and mix', () async {
    await Future.wait([capture.start(), capture.start()]);
    final results = await Future.wait([
      capture.finish(confirmed: true),
      capture.finish(confirmed: true),
    ]);
    expect(results[0]!.path, results[1]!.path);
    expect(count('startRecording'), 1);
    expect(count('stopRecording'), 1);
    expect(count('mixWavFiles'), 1);
    expect(mic.starts, 1);
    expect(mic.stops, 1);
  });

  for (final code in ['PERMISSION_DENIED', 'NO_DISPLAY', 'START_FAILED']) {
    test(
      'system start $code never starts microphone or exposes output',
      () async {
        startError = code;
        await expectLater(capture.start(), throwsA(isA<AppException>()));
        expect(mic.starts, 0);
        expect(capture.sourcePath, isNull);
        expect(capture.status, CaptureStatus.failed);
      },
    );
  }

  test(
    'microphone start failure stops the already-started system input',
    () async {
      mic.failStart = true;
      await expectLater(capture.start(), throwsA(isA<ValidationException>()));
      expect(count('stopRecording'), 1);
      expect(count('mixWavFiles'), 0);
      expect(capture.sourcePath, isNull);
    },
  );

  for (final code in [
    'NO_AUDIO',
    'STOP_FAILED',
    'WRITE_TIMEOUT',
    'CAPTURE_INTERRUPTED',
  ]) {
    test(
      'stop $code still stops microphone and never returns mic-only',
      () async {
        await capture.start();
        stopError = code;
        await expectLater(
          capture.finish(confirmed: true),
          throwsA(isA<AppException>()),
        );
        expect(mic.stops, 1);
        expect(count('mixWavFiles'), 0);
        expect(capture.status, CaptureStatus.failed);
        expect(capture.sourcePath, isNull);
      },
    );
  }

  test('microphone finalization error prevents mixing', () async {
    await capture.start();
    mic.failStop = true;
    await expectLater(
      capture.finish(confirmed: true),
      throwsA(isA<AppException>()),
    );
    expect(count('stopRecording'), 1);
    expect(count('mixWavFiles'), 0);
  });

  for (final output in [
    Uint8List(0),
    Uint8List.fromList([1, 2]),
    wav(sampleRate: 48000),
  ]) {
    test(
      'invalid combined WAV is deleted, sources preserved (${output.length})',
      () async {
        await capture.start();
        mixedBytes = output;
        await expectLater(
          capture.finish(confirmed: true),
          throwsA(isA<AppException>()),
        );
        expect(await File(mixedPath!).exists(), isFalse);
        expect(await File(systemPath!).exists(), isTrue);
        expect(await mic.file.exists(), isTrue);
        expect(capture.sourcePath, isNull);
      },
    );
  }

  test('combined pause/resume is explicitly unavailable', () async {
    await capture.start();
    await expectLater(capture.pause(), throwsA(isA<ValidationException>()));
    await expectLater(capture.resume(), throwsA(isA<ValidationException>()));
    expect(capture.status, CaptureStatus.recording);
  });

  test(
    'dispose cancels pending system start and blocks late microphone start',
    () async {
      startGate = Completer<void>();
      final starting = capture.start();
      final rejected = expectLater(starting, throwsA(isA<AppException>()));
      while (count('startRecording') == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await capture.dispose();
      await rejected;
      expect(mic.starts, 0);
      expect(capture.status, CaptureStatus.disposed);
      expect(count('cancelRecording'), 1);
    },
  );

  test(
    'dispose cancels microphone permission without awaiting combined start',
    () async {
      mic.permission = Completer<void>();
      final starting = capture.start();
      final rejected = expectLater(starting, throwsA(isA<AppException>()));
      await mic.started.future;
      await capture.dispose();
      await rejected;
      expect(capture.status, CaptureStatus.disposed);
      expect(count('mixWavFiles'), 0);
    },
  );

  test('dispose during mix cannot publish late combined recording', () async {
    await capture.start();
    mixGate = Completer<void>();
    final finishing = capture.finish(confirmed: true);
    final rejected = expectLater(finishing, throwsA(isA<AppException>()));
    while (mixedPath == null) {
      await Future<void>.delayed(Duration.zero);
    }
    await capture.dispose();
    await rejected;
    expect(capture.status, CaptureStatus.disposed);
    expect(capture.sourcePath, isNull);
    expect(await File(mixedPath!).exists(), isFalse);
  });

  test(
    'lost native start callback times out and requests native cleanup',
    () async {
      startGate = Completer<void>();
      await expectLater(capture.start(), throwsA(isA<AppException>()));
      await Future<void>.delayed(Duration.zero);
      expect(count('cancelRecording'), 1);
      expect(mic.starts, 0);
    },
  );

  test(
    'dispose is idempotent and never mixes or reports successful finish',
    () async {
      await capture.start();
      await Future.wait([capture.dispose(), capture.dispose()]);
      expect(count('cancelRecording'), 1);
      expect(mic.disposals, 1);
      expect(count('mixWavFiles'), 0);
      expect(capture.status, CaptureStatus.disposed);
      await expectLater(capture.start(), throwsA(isA<AppException>()));
    },
  );

  test('mix timeout cancels native work and preserves both inputs', () async {
    await capture.start();
    mixGate = Completer<void>();
    await expectLater(
      capture.finish(confirmed: true),
      throwsA(isA<AppException>()),
    );
    expect(count('cancelRecording'), 1);
    expect(await File(mixedPath!).exists(), isFalse);
    expect(await File(systemPath!).exists(), isTrue);
    expect(await mic.file.exists(), isTrue);
  });

  test(
    'failed mix waits for cancellation acknowledgement before deleting its output',
    () async {
      final ready = Completer<void>();
      final pendingReply = Completer<void>();
      final cancelling = Completer<void>();
      final acknowledged = Completer<void>();
      late String destination;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'mixWavFiles') {
          destination = (call.arguments as Map)['outputPath'] as String;
          await File(destination).writeAsBytes(wav());
          ready.complete();
          await pendingReply.future;
          return null;
        }
        if (call.method == 'cancelRecording') {
          cancelling.complete();
          await acknowledged.future;
          pendingReply.complete();
          return null;
        }
        throw MissingPluginException();
      });
      final mixing = service.mixWithMicrophone(
        systemPath: 'system',
        microphonePath: 'mic',
      );
      final rejected = expectLater(mixing, throwsA(isA<PlatformException>()));
      await ready.future;
      final disposing = service.dispose();
      await cancelling.future;
      expect(await File(destination).exists(), isTrue);
      acknowledged.complete();
      await disposing;
      await rejected;
      expect(await File(destination).exists(), isFalse);
    },
  );

  test(
    'unconfirmed cleanup remains failed and a retry sends native cancel again',
    () async {
      await capture.start();
      cancelFailures = 1;
      await expectLater(capture.dispose(), throwsA(isA<AppException>()));
      expect(capture.status, CaptureStatus.failed);
      await expectLater(capture.start(), throwsA(isA<AppException>()));
      await capture.dispose();
      expect(count('cancelRecording'), 2);
      expect(capture.status, CaptureStatus.disposed);
      await capture.dispose();
      expect(count('cancelRecording'), 2);
    },
  );

  test('non-macOS fails before invoking any native channel', () async {
    final unsupported = SystemAudioService(channel: channel, isMacOS: false);
    expect(await unsupported.requestPermission(), isFalse);
    await expectLater(
      unsupported.startRecording(),
      throwsA(isA<PlatformException>()),
    );
    expect(calls, isEmpty);
  });
}
