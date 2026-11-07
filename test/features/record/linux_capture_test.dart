import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/linux_audio_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

Uint8List _wav({int rate = 16000}) {
  final bytes = Uint8List(48);
  final data = ByteData.sublistView(bytes);
  void tag(int at, String value) =>
      bytes.setRange(at, at + value.length, value.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, 4, Endian.little);
  return bytes;
}

class _FakeProcess implements Process {
  final _exit = Completer<int>();
  final _out = StreamController<List<int>>();
  final _err = StreamController<List<int>>();
  final signals = <ProcessSignal>[];
  Future<int> Function()? terminate;
  bool ignoreTerm = false;
  bool ignoreKill = false;
  bool get ended => _exit.isCompleted;
  void complete(int code, {String output = ''}) {
    if (ended) return;
    if (output.isNotEmpty) _out.add(output.codeUnits);
    unawaited(_out.close());
    unawaited(_err.close());
    _exit.complete(code);
  }

  @override
  Future<int> get exitCode => _exit.future;
  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => _err.stream;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    if (signal == ProcessSignal.sigkill) {
      if (!ignoreKill) complete(-9);
    } else if (!ignoreTerm) {
      unawaited(() async {
        complete(await (terminate?.call() ?? Future.value(0)));
      }());
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runner {
  String sources =
      '1 mic driver\n2 current.monitor driver\n3 other.monitor driver\n';
  String info = 'Default Sink: current\nDefault Source: mic\n';
  String? missing;
  final calls = <(String, List<String>)>[];
  final captures = <_FakeProcess>[];
  final paths = <String>[];
  Uint8List output = _wav();
  int captureExit = 0;
  bool earlyMonitorExit = false, ignoreTerm = false;
  bool failMix = false, hangMix = false;
  bool mixedAfterInputs = false;
  Completer<void>? finalization;
  final stopping = Completer<void>();
  final mixing = Completer<void>();
  _FakeProcess? mixer;
  _FakeProcess? stuckPactl;
  bool hangPactl = false;

  Future<Process> start(String program, List<String> args) async {
    calls.add((program, List.of(args)));
    if (program == missing) {
      throw ProcessException(program, args, 'private path');
    }
    final process = _FakeProcess();
    if (program == 'pactl') {
      if (hangPactl) {
        stuckPactl = process;
        process.ignoreTerm = true;
        process.ignoreKill = true;
      } else {
        process.complete(0, output: args.first == 'list' ? sources : info);
      }
    } else if (program == 'parec') {
      captures.add(process);
      paths.add(args.last);
      process.ignoreTerm = ignoreTerm;
      process.terminate = () async {
        if (!stopping.isCompleted) stopping.complete();
        await finalization?.future;
        await File(args.last).writeAsBytes(output);
        return captureExit;
      };
      if (earlyMonitorExit && captures.length == 2) process.complete(1);
    } else if (program == 'ffmpeg' &&
        args.length == 1 &&
        args.first == '-version') {
      process.complete(0);
    } else if (program == 'ffmpeg') {
      mixer = process;
      mixedAfterInputs =
          captures.every((p) => p.ended) &&
          paths.every((p) => File(p).existsSync());
      if (!mixing.isCompleted) mixing.complete();
      await File(args.last).writeAsBytes(failMix ? [1, 2, 3] : _wav());
      if (!hangMix) process.complete(failMix ? 1 : 0);
    } else {
      throw StateError('Unexpected executable');
    }
    return process;
  }
}

void main() {
  late Directory temp;
  late _Runner runner;
  late LinuxAudioCapture capture;
  LinuxAudioCapture create({bool combined = false, bool linux = true}) =>
      LinuxAudioCapture(
        captureSystemAudio: combined,
        isLinux: linux,
        startProcess: runner.start,
        temporaryDirectory: () async => temp,
        startupGrace: Duration.zero,
        stopTimeout: const Duration(milliseconds: 50),
        commandTimeout: const Duration(milliseconds: 500),
      );
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dictai-linux-test-');
    runner = _Runner();
    capture = create();
  });
  tearDown(() async {
    if (runner.finalization case final Completer<void> gate) {
      if (!gate.isCompleted) gate.complete();
    }
    await capture.dispose();
    await temp.delete(recursive: true);
  });

  test(
    'mic-only uses selected device, explicit WAV flags and one joined stop',
    () async {
      final devices = await capture.listInputDevices();
      expect(devices.map((d) => d.id), ['mic']);
      await Future.wait([
        capture.start(device: devices.single),
        capture.start(),
      ]);
      expect(runner.captures, hasLength(1));
      final args = runner.calls.singleWhere((c) => c.$1 == 'parec').$2;
      expect(
        args,
        containsAll([
          '--device=mic',
          '--rate=16000',
          '--channels=1',
          '--format=s16le',
          '--file-format=wav',
        ]),
      );
      expect(args[args.length - 2], '--');
      expect(await capture.finish(confirmed: false), isNull);
      expect(runner.captures.single.signals, isEmpty);
      expect(capture.status, CaptureStatus.recording);
      final files = await Future.wait([
        capture.finish(confirmed: true),
        capture.finish(confirmed: true),
      ]);
      expect(files[0]!.path, files[1]!.path);
      expect(await files[0]!.readAsBytes(), _wav());
      expect(runner.captures.single.signals, [ProcessSignal.sigterm]);
      expect(runner.calls.where((c) => c.$1 == 'ffmpeg'), isEmpty);
      expect(capture.status, CaptureStatus.finished);
    },
  );

  test(
    'combined capture uses current monitor and mixes only finalized inputs',
    () async {
      await capture.dispose();
      capture = create(combined: true);
      await capture.start();
      expect(
        runner.calls.where((c) => c.$1 == 'parec').last.$2,
        contains('--device=current.monitor'),
      );
      final file = await capture.finish(confirmed: true);
      expect(runner.mixedAfterInputs, isTrue);
      expect(await file!.readAsBytes(), _wav());
      expect(runner.paths.every((p) => !File(p).existsSync()), isTrue);
      await capture.dispose();
      expect(await file.exists(), isTrue);
    },
  );

  test('finish waits for process exit and file finalization', () async {
    runner.finalization = Completer<void>();
    await capture.start();
    var returned = false;
    final finish = capture.finish(confirmed: true).then((file) {
      returned = true;
      return file;
    });
    await runner.stopping.future;
    expect(returned, isFalse);
    expect(await File(capture.sourcePath!).exists(), isFalse);
    runner.finalization!.complete();
    expect(await (await finish)!.exists(), isTrue);
  });

  test('missing current monitor never chooses a different output', () async {
    await capture.dispose();
    capture = create(combined: true);
    runner.sources = '1 mic driver\n2 other.monitor driver\n';
    await expectLater(capture.start(), throwsA(isA<ValidationException>()));
    expect(runner.captures, isEmpty);
  });

  test('missing selected microphone never silently falls back', () async {
    await expectLater(
      capture.start(
        device: const InputDevice(id: 'absent', label: 'Absent'),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(runner.captures, isEmpty);
  });

  for (final missing in ['pactl', 'parec', 'ffmpeg']) {
    test(
      'missing $missing gives a safe actionable error without live children',
      () async {
        await capture.dispose();
        capture = create(combined: true);
        runner.missing = missing;
        await expectLater(
          capture.start(),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'safe message',
              allOf(contains(missing), isNot(contains('private path'))),
            ),
          ),
        );
        expect(runner.captures.every((p) => p.ended), isTrue);
      },
    );
  }

  test('failed second capture still terminates and joins microphone', () async {
    await capture.dispose();
    capture = create(combined: true);
    runner.earlyMonitorExit = true;
    await expectLater(capture.start(), throwsA(isA<AppException>()));
    expect(runner.captures.every((p) => p.ended), isTrue);
    expect(runner.captures.first.signals, [ProcessSignal.sigterm]);
    expect(capture.status, CaptureStatus.failed);
  });

  test('nonzero capture exit never publishes even a valid WAV', () async {
    runner.captureExit = 1;
    await capture.start();
    await expectLater(
      capture.finish(confirmed: true),
      throwsA(isA<AppException>()),
    );
    expect(await File(capture.sourcePath!).exists(), isTrue);
    expect(capture.status, CaptureStatus.failed);
  });

  for (final invalid in ['empty', 'wrong rate']) {
    test('invalid finalized capture $invalid is rejected', () async {
      runner.output = invalid == 'empty' ? Uint8List(0) : _wav(rate: 48000);
      await capture.start();
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(capture.status, CaptureStatus.failed);
    });
  }

  test(
    'TERM timeout escalates to KILL and never reports successful finish',
    () async {
      runner.ignoreTerm = true;
      await capture.start();
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(runner.captures.single.signals, [
        ProcessSignal.sigterm,
        ProcessSignal.sigkill,
      ]);
      expect(runner.captures.single.ended, isTrue);
    },
  );

  test(
    'failed mix removes partial output and preserves both source files',
    () async {
      await capture.dispose();
      capture = create(combined: true);
      runner.failMix = true;
      await capture.start();
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(runner.paths.every((p) => File(p).existsSync()), isTrue);
      final parent = File(runner.paths.first).parent;
      expect(await File('${parent.path}/mixed.part').exists(), isFalse);
      expect(await File('${parent.path}/recording.wav').exists(), isFalse);
    },
  );

  test(
    'dispose interrupts and joins a hanging mixer without an upload',
    () async {
      await capture.dispose();
      capture = create(combined: true);
      runner.hangMix = true;
      await capture.start();
      final assertion = expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      await runner.mixing.future;
      await capture.dispose();
      await assertion;
      expect(runner.mixer!.ended, isTrue);
      expect(capture.status, CaptureStatus.disposed);
      expect(runner.paths.every((p) => File(p).existsSync()), isTrue);
    },
  );

  test(
    'an unjoined auxiliary process keeps disposal failed and retryable',
    () async {
      await capture.dispose();
      capture = create(combined: true);
      runner.hangMix = true;
      await capture.start();
      final finishing = expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      await runner.mixing.future;
      final mixer = runner.mixer!;
      mixer.ignoreTerm = true;
      mixer.ignoreKill = true;
      final cleanup = expectLater(
        capture.dispose(),
        throwsA(isA<AppException>()),
      );
      await finishing;
      await cleanup;
      expect(capture.status, CaptureStatus.failed);
      expect(mixer.ended, isFalse);
      expect(mixer.signals, contains(ProcessSignal.sigkill));
      mixer.complete(0);
      await capture.dispose();
      expect(capture.status, CaptureStatus.disposed);
    },
  );

  test('failed auxiliary cleanup still stops active microphone', () async {
    await capture.start();
    runner.hangPactl = true;
    await expectLater(capture.listInputDevices(), throwsA(isA<AppException>()));
    await expectLater(capture.dispose(), throwsA(isA<AppException>()));
    expect(runner.captures.single.ended, isTrue);
    expect(runner.captures.single.signals, [ProcessSignal.sigterm]);
    expect(runner.stuckPactl!.ended, isFalse);
    expect(capture.status, CaptureStatus.failed);
    runner.stuckPactl!.complete(0);
    await capture.dispose();
    expect(capture.status, CaptureStatus.disposed);
  });

  test(
    'pause is unsupported and disposal of active capture stops once',
    () async {
      await capture.start();
      expect(capture.supportsPause, isFalse);
      await expectLater(capture.pause(), throwsA(isA<ValidationException>()));
      await expectLater(capture.resume(), throwsA(isA<ValidationException>()));
      await Future.wait([capture.dispose(), capture.dispose()]);
      expect(runner.captures.single.signals, [ProcessSignal.sigterm]);
      expect(capture.status, CaptureStatus.disposed);
      expect(await File(capture.sourcePath!).exists(), isTrue);
      await expectLater(capture.start(), throwsA(isA<AppException>()));
    },
  );

  test('non-Linux host never invokes real process dependencies', () async {
    await capture.dispose();
    capture = create(linux: false);
    await expectLater(capture.start(), throwsA(isA<AppException>()));
    expect(runner.calls, isEmpty);
  });
}
