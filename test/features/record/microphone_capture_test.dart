import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/microphone_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

Uint8List wav() {
  final bytes = Uint8List(46);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String s) =>
      bytes.setRange(offset, offset + s.length, s.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, 38, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, 2, Endian.little);
  return bytes;
}

/// Only the pinned RecordPlatform methods used by MicrophoneCapture, no channels.
class FakeRecorder implements RecordPlatform {
  bool permission = true, encoder = true, nativeRecording = false;
  final createdIds = <String>[];
  int get creates => createdIds.length;
  Completer<String?>? stopGate;
  @override
  Future<void> create(String recorderId) async {
    createdIds.add(recorderId);
  }

  @override
  Future<bool> isRecording(String recorderId) async => nativeRecording;
  bool startFails = false,
      stopFails = false,
      pauseFails = false,
      resumeFails = false;
  bool disposeFails = false, missingPath = false;
  int starts = 0, stops = 0, pauses = 0, resumes = 0, disposals = 0;
  String? path;
  RecordConfig? config;
  Uint8List output = wav();
  Completer<bool>? permissionGate;
  final permissionAsked = Completer<void>();
  final devices = const [InputDevice(id: 'mic-1', label: 'Microphone')];
  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    if (!permissionAsked.isCompleted) permissionAsked.complete();
    return permissionGate == null ? permission : await permissionGate!.future;
  }

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async => this.encoder;
  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async =>
      devices;
  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    starts++;
    nativeRecording = true;
    this.path = path;
    this.config = config;
    await File(path).writeAsBytes(output);
    if (startFails) throw StateError('private device error');
  }

  @override
  Future<String?> stop(String recorderId) async {
    stops++;
    if (stopFails) throw StateError('private stop error');
    if (stopGate case final Completer<String?> gate) return gate.future;
    nativeRecording = false;
    return missingPath ? null : path;
  }

  @override
  Future<void> pause(String recorderId) async {
    pauses++;
    if (pauseFails) throw StateError('private error');
  }

  @override
  Future<void> resume(String recorderId) async {
    resumes++;
    if (resumeFails) throw StateError('private error');
  }

  @override
  Future<void> dispose(String recorderId) async {
    disposals++;
    if (disposeFails) throw StateError('private disposal error');
    nativeRecording = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late FakeRecorder recorder;
  late MicrophoneCapture capture;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dictai-capture-test-');
    recorder = FakeRecorder();
    capture = MicrophoneCapture(
      platform: recorder,
      isMacOS: true,
      temporaryDirectory: () async => temp,
    );
  });
  tearDown(() async {
    recorder.disposeFails = false;
    await capture.dispose();
    await temp.delete(recursive: true);
  });

  test(
    'WAV encoder and selected device; confirmed finish preserves real PCM file',
    () async {
      await capture.start(device: recorder.devices.single);
      expect(capture.status, CaptureStatus.recording);
      expect(recorder.config!.encoder, AudioEncoder.wav);
      expect(recorder.config!.sampleRate, 16000);
      expect(recorder.config!.numChannels, 1);
      expect(recorder.config!.device!.id, 'mic-1');
      final file = await capture.finish(confirmed: true);
      expect(await file!.readAsBytes(), wav());
      expect(capture.status, CaptureStatus.finished);
      expect(recorder.stops, 1);
      expect(recorder.disposals, 1);
      await capture.dispose();
      expect(await file.exists(), isTrue);
    },
  );

  test(
    'cancel stop from recording and paused does not stop/release/change state',
    () async {
      await capture.start();
      expect(await capture.finish(confirmed: false), isNull);
      expect(capture.status, CaptureStatus.recording);
      await capture.pause();
      expect(await capture.finish(confirmed: false), isNull);
      expect(capture.status, CaptureStatus.paused);
      expect(recorder.stops, 0);
      expect(recorder.disposals, 0);
      await capture.resume();
      expect(capture.status, CaptureStatus.recording);
      expect(recorder.pauses, 1);
      expect(recorder.resumes, 1);
    },
  );

  test('double start/confirmed finish serializes to one native call', () async {
    await Future.wait([capture.start(), capture.start()]);
    final files = await Future.wait([
      capture.finish(confirmed: true),
      capture.finish(confirmed: true),
    ]);
    expect(recorder.starts, 1);
    expect(recorder.stops, 1);
    expect(files[0]!.path, files[1]!.path);
  });

  test(
    'permission denied is safe and releases driver without starting',
    () async {
      recorder.permission = false;
      await expectLater(capture.start(), throwsA(isA<ValidationException>()));
      expect(recorder.starts, 0);
      expect(recorder.disposals, 1);
      expect(capture.status, CaptureStatus.failed);
    },
  );

  test(
    'unavailable selected device never silently falls back to default',
    () async {
      await expectLater(
        capture.start(
          device: const InputDevice(id: 'missing', label: 'Missing'),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(recorder.starts, 0);
    },
  );

  test('unsupported WAV never starts AAC/Opus fallback', () async {
    recorder.encoder = false;
    await expectLater(capture.start(), throwsA(isA<ValidationException>()));
    expect(recorder.starts, 0);
  });

  test(
    'native start failure retains partial source but releases recorder',
    () async {
      recorder.startFails = true;
      await expectLater(
        capture.start(),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'safe',
            isNot(contains('private')),
          ),
        ),
      );
      expect(await File(capture.sourcePath!).exists(), isTrue);
      expect(recorder.disposals, 1);
      expect(capture.status, CaptureStatus.failed);
    },
  );

  for (final scenario in ['empty', 'not_wav', 'missing_path', 'stop_error']) {
    test(
      'failed finalization $scenario retains file and is never successful',
      () async {
        if (scenario == 'empty') recorder.output = Uint8List(0);
        if (scenario == 'not_wav') {
          recorder.output = Uint8List.fromList(
            'fake compressed audio'.codeUnits,
          );
        }
        recorder.missingPath = scenario == 'missing_path';
        recorder.stopFails = scenario == 'stop_error';
        await capture.start();
        await expectLater(
          capture.finish(confirmed: true),
          throwsA(isA<AppException>()),
        );
        expect(capture.status, CaptureStatus.failed);
        expect(await File(capture.sourcePath!).exists(), isTrue);
        expect(recorder.stops, 1);
        expect(recorder.disposals, 1);
      },
    );
  }

  test('pause and resume failures are explicit and release hardware', () async {
    await capture.start();
    recorder.pauseFails = true;
    await expectLater(capture.pause(), throwsA(isA<AppException>()));
    expect(recorder.disposals, 1);
    recorder.pauseFails = false;
    await capture.start();
    await capture.pause();
    recorder.resumeFails = true;
    await expectLater(capture.resume(), throwsA(isA<AppException>()));
    expect(capture.status, CaptureStatus.failed);
  });

  test(
    'dispose during permission wait prevents late recording start',
    () async {
      recorder.permissionGate = Completer<bool>();
      final starting = capture.start();
      final assertion = expectLater(starting, throwsA(isA<AppException>()));
      await recorder.permissionAsked.future;
      final disposing = capture.dispose();
      recorder.permissionGate!.complete(true);
      await assertion;
      await disposing;
      expect(recorder.starts, 0);
      expect(capture.status, CaptureStatus.disposed);
    },
  );

  test(
    'failed cleanup is explicit and retryable; confirmed source stays intact',
    () async {
      await capture.start();
      recorder.disposeFails = true;
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(capture.status, CaptureStatus.failed);
      recorder.disposeFails = false;
      final file = await capture.finish(confirmed: true);
      expect(await file!.exists(), isTrue);
      expect(recorder.stops, 1);
      expect(capture.status, CaptureStatus.finished);
    },
  );

  test(
    'active dispose stops once, no implicit successful finish or source deletion',
    () async {
      await capture.start();
      final path = capture.sourcePath!;
      await Future.wait([capture.dispose(), capture.dispose()]);
      expect(recorder.stops, 1);
      expect(recorder.disposals, 1);
      expect(await File(path).exists(), isTrue);
      expect(capture.status, CaptureStatus.disposed);
      await expectLater(capture.start(), throwsA(isA<AppException>()));
    },
  );

  test(
    'repeated recordings reuse channels while independent adapters have distinct IDs',
    () async {
      await capture.start();
      await capture.finish(confirmed: true);
      await capture.start();
      await capture.finish(confirmed: true);
      final second = MicrophoneCapture(
        platform: recorder,
        isMacOS: true,
        temporaryDirectory: () async => temp,
      );
      addTearDown(second.dispose);
      await second.start();
      await second.finish(confirmed: true);
      expect(recorder.createdIds, hasLength(3));
      expect(recorder.createdIds[0], recorder.createdIds[1]);
      expect(recorder.createdIds[2], isNot(recorder.createdIds[0]));
    },
  );

  test('Linux path fails before touching the unsafe file recorder', () async {
    final linux = MicrophoneCapture(platform: recorder, isMacOS: false);
    addTearDown(linux.dispose);
    expect(linux.supportsPause, isFalse);
    await expectLater(linux.start(), throwsA(isA<ValidationException>()));
    await expectLater(linux.pause(), throwsA(isA<ValidationException>()));
    await expectLater(linux.resume(), throwsA(isA<ValidationException>()));
    expect(recorder.creates, 0);
    expect(recorder.starts, 0);
  });

  test(
    'already-ended native recording is released without waiting for Stop',
    () async {
      await capture.start();
      recorder.nativeRecording = false;
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(recorder.stops, 0);
      expect(recorder.disposals, 1);
      expect(await File(capture.sourcePath!).exists(), isTrue);
    },
  );

  test('lost native Stop callback still permits independent dispose', () async {
    final bounded = MicrophoneCapture(
      platform: recorder,
      isMacOS: true,
      temporaryDirectory: () async => temp,
      commandTimeout: const Duration(milliseconds: 150),
    );
    addTearDown(bounded.dispose);
    recorder.stopGate = Completer<String?>();
    await bounded.start();
    await expectLater(
      bounded.finish(confirmed: true),
      throwsA(isA<AppException>()),
    );
    expect(recorder.stops, 1);
    expect(recorder.disposals, 1);
    expect(await File(bounded.sourcePath!).exists(), isTrue);
    recorder.stopGate!.complete(bounded.sourcePath);
    await bounded.dispose();
    expect(bounded.status, CaptureStatus.disposed);
  });
}
