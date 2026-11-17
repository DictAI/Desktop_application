import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/ios_audio_capture.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Uint8List _wav() {
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

class _Native {
  _Native(this.file);
  final File file;
  final events = StreamController<dynamic>.broadcast(sync: true);
  final calls = <String>[];
  String? id;
  int revision = 0;
  String status = 'recording';
  PlatformException? startError;
  bool interrupted = false;
  bool wrongFinishPath = false;
  Completer<Map<String, Object?>>? startGate;
  Completer<Map<String, Object?>>? finishGate;
  final enteredStart = Completer<void>();
  void Function()? duringStart;
  void Function()? duringPause;
  void Function()? duringResume;
  int cleanupFailures = 0;
  Map<String, Object?> value({String? message}) => {
    'id': id,
    'revision': revision,
    'status': status,
    'path': file.path,
    if (message != null) 'message': message,
  };
  void emit(String next, {String? message}) {
    status = next;
    revision++;
    events.add(value(message: message));
  }

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    id ??= (call.arguments as Map)['id'] as String;
    switch (call.method) {
      case 'start':
        if (startError != null) throw startError!;
        await file.writeAsBytes(_wav());
        revision++;
        final response = value();
        duringStart?.call();
        if (!enteredStart.isCompleted) enteredStart.complete();
        return await (startGate?.future ?? Future.value(response));
      case 'pause':
        status = 'paused';
        revision++;
        final paused = value();
        duringPause?.call();
        return paused;
      case 'resume':
        if (interrupted) throw PlatformException(code: 'interrupted');
        status = 'recording';
        revision++;
        final resumed = value();
        duringResume?.call();
        return resumed;
      case 'finish':
        status = 'finished';
        revision++;
        return finishGate?.future ??
            {...value(), if (wrongFinishPath) 'path': '${file.path}.other'};
      case 'dispose':
        if (cleanupFailures > 0) {
          cleanupFailures--;
          throw PlatformException(code: 'session_cleanup');
        }
        if (startGate != null && !startGate!.isCompleted) {
          startGate!.completeError(PlatformException(code: 'cancelled'));
        }
        return null;
    }
    throw MissingPluginException();
  }
}

String _token() {
  String part(Object x) =>
      base64Url.encode(utf8.encode(jsonEncode(x))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': '11111111-1111-4111-8111-111111111111', 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.dictai/ios_audio');
  late Directory directory;
  late _Native native;
  late IosAudioCapture capture;
  setUp(() async {
    resetStorageFakes();
    directory = await Directory.systemTemp.createTemp('dictai-ios-audio-test-');
    native = _Native(File('${directory.path}/microphone.wav'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, native.handle);
    capture = IosAudioCapture(
      channel: channel,
      events: native.events.stream,
      commandTimeout: const Duration(milliseconds: 40),
      permissionTimeout: const Duration(milliseconds: 100),
    );
  });
  tearDown(() async {
    await capture.dispose();
    await native.events.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  test(
    'late matching Start retains only its owned path after disposal',
    () async {
      final gate = Completer<Map<String, Object?>>();
      final entered = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'start') {
              entered.complete((call.arguments as Map)['id'] as String);
              return gate.future;
            }
            return null;
          });
      final published = <CaptureStatus>[];
      final subscription = capture.captureEvents.listen(
        (event) => published.add(event.status),
      );
      final starting = expectLater(
        capture.start(),
        throwsA(isA<AppException>()),
      );
      final id = await entered.future;
      final disposal = capture.dispose();
      native.events.add({
        'id': 'another-recorder',
        'revision': 999,
        'status': 'recording',
        'path': '${native.file.path}.foreign',
      });
      gate.complete({
        'id': id,
        'revision': 1,
        'status': 'recording',
        'path': native.file.path,
      });
      await starting;
      await disposal;
      expect(capture.sourcePath, native.file.path);
      expect(capture.status, CaptureStatus.disposed);
      expect(published, isEmpty);
      await subscription.cancel();
    },
  );

  test('iOS probe does not activate a session or request permission', () async {
    expect(await capture.listInputDevices(), isEmpty);
    expect(native.calls, isEmpty);
    expect(capture.supportsPause, isTrue);
  });
  for (final command in ['start', 'pause', 'resume']) {
    test(
      'stream error during $command rejects late success permanently',
      () async {
        void fail() => native.events.addError(StateError('broken channel'));
        if (command != 'start') await capture.start();
        if (command == 'resume') await capture.pause();
        final Future<void> operation;
        switch (command) {
          case 'start':
            native.duringStart = fail;
            operation = capture.start();
          case 'pause':
            native.duringPause = fail;
            operation = capture.pause();
          default:
            native.duringResume = fail;
            operation = capture.resume();
        }
        await expectLater(operation, throwsA(isA<AppException>()));
        expect(capture.status, CaptureStatus.failed);
        expect(capture.sourcePath, native.file.path);
        native.emit('recording');
        expect(capture.status, CaptureStatus.failed);
        await expectLater(capture.start(), throwsA(isA<AppException>()));
        expect(native.calls, contains('dispose'));
        expect(await native.file.exists(), isTrue);
      },
    );
  }
  test(
    'duplicate Start/Pause/Resume/finish are serialized and idempotent',
    () async {
      await Future.wait([capture.start(), capture.start()]);
      expect(native.calls.where((x) => x == 'start'), hasLength(1));
      await Future.wait([capture.pause(), capture.pause()]);
      await Future.wait([capture.resume(), capture.resume()]);
      expect(native.calls.where((x) => x == 'pause'), hasLength(1));
      expect(native.calls.where((x) => x == 'resume'), hasLength(1));
      final files = await Future.wait([
        capture.finish(confirmed: true),
        capture.finish(confirmed: true),
      ]);
      expect(files[0]!.path, native.file.path);
      expect(files[1], same(files[0]));
      expect(native.calls.where((x) => x == 'finish'), hasLength(1));
      expect(capture.status, CaptureStatus.finished);
      expect(await native.file.exists(), isTrue);
    },
  );
  test(
    'cancelled confirmation leaves recording and never invokes Stop',
    () async {
      await capture.start();
      expect(await capture.finish(confirmed: false), isNull);
      expect(capture.status, CaptureStatus.recording);
      expect(native.calls, ['start']);
    },
  );
  test(
    'permission denial becomes a useful error and cleans up native owner',
    () async {
      native.startError = PlatformException(code: 'permission_denied');
      await expectLater(
        capture.start(),
        throwsA(
          isA<ValidationException>().having(
            (x) => x.message,
            'message',
            contains('настройках iPhone'),
          ),
        ),
      );
      expect(capture.status, CaptureStatus.failed);
      expect(native.calls, ['start', 'dispose']);
    },
  );
  test(
    'Dispose cancels Start while system permission prompt is pending',
    () async {
      native.startGate = Completer();
      final start = capture.start();
      final rejected = expectLater(start, throwsA(isA<AppException>()));
      await native.enteredStart.future;
      await capture.dispose();
      await rejected;
      expect(capture.status, CaptureStatus.disposed);
      expect(native.calls.where((x) => x == 'dispose'), isNotEmpty);
      await expectLater(capture.start(), throwsA(isA<ValidationException>()));
    },
  );
  test(
    'interruption is paused, never resumes automatically, manual retry waits',
    () async {
      await capture.start();
      native.emit('paused', message: 'Системное прерывание');
      expect(capture.status, CaptureStatus.paused);
      expect(native.calls, ['start']);
      native.interrupted = true;
      await expectLater(capture.resume(), throwsA(isA<ValidationException>()));
      expect(capture.status, CaptureStatus.paused);
      native.interrupted = false;
      native.emit('paused', message: 'Можно продолжить');
      expect(capture.status, CaptureStatus.paused);
      await capture.resume();
      expect(capture.status, CaptureStatus.recording);
    },
  );
  test('failed native cleanup can be retried by explicit Dispose', () async {
    await capture.start();
    native.cleanupFailures = 1;
    await expectLater(capture.dispose(), throwsA(isA<AppException>()));
    await capture.dispose();
    expect(capture.status, CaptureStatus.disposed);
    expect(native.calls.where((x) => x == 'dispose'), hasLength(2));
    expect(await native.file.exists(), isTrue);
  });
  test('newer interruption event wins over a late Start response', () async {
    native.duringStart = () => native.emit('paused', message: 'Interrupted');
    await capture.start();
    expect(capture.status, CaptureStatus.paused);
  });
  test(
    'events for old identities and older revisions cannot revive a capture',
    () async {
      await capture.start();
      native.emit('paused');
      native.events.add({
        ...native.value(),
        'id': 'other',
        'revision': 99,
        'status': 'recording',
      });
      native.events.add({
        ...native.value(),
        'revision': 0,
        'status': 'recording',
      });
      expect(capture.status, CaptureStatus.paused);
      await capture.dispose();
      native.emit('recording');
      expect(capture.status, CaptureStatus.disposed);
    },
  );
  test(
    'native reset and hardware failure are terminal and preserve file',
    () async {
      await capture.start();
      native.emit('failed', message: 'Аудиосервис перезапущен');
      expect(capture.status, CaptureStatus.failed);
      expect(await native.file.exists(), isTrue);
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<ValidationException>()),
      );
    },
  );
  test(
    'finish timeout releases native recorder and keeps source file',
    () async {
      await capture.start();
      native.finishGate = Completer();
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(native.calls.where((x) => x == 'dispose'), isNotEmpty);
      expect(capture.status, CaptureStatus.failed);
      expect(await native.file.exists(), isTrue);
      native.finishGate!.complete(native.value());
    },
  );
  test(
    'invalid or substituted WAV is rejected without deleting source',
    () async {
      await capture.start();
      await native.file.writeAsString('invalid WAV');
      await expectLater(
        capture.finish(confirmed: true),
        throwsA(isA<AppException>()),
      );
      expect(await native.file.exists(), isTrue);
    },
  );
  test('native finish cannot replace capture-owned path', () async {
    await capture.start();
    native.wrongFinishPath = true;
    await expectLater(
      capture.finish(confirmed: true),
      throwsA(isA<AppException>()),
    );
    expect(capture.sourcePath, native.file.path);
  });
  test('unexpected native sample rate cannot pass WAV finalization', () async {
    await capture.start();
    final bytes = _wav();
    ByteData.sublistView(bytes)
      ..setUint32(24, 48000, Endian.little)
      ..setUint32(28, 96000, Endian.little);
    await native.file.writeAsBytes(bytes);
    await expectLater(
      capture.finish(confirmed: true),
      throwsA(isA<AppException>()),
    );
    expect(capture.status, CaptureStatus.failed);
    expect(await native.file.exists(), isTrue);
  });

  for (final resuming in [false, true]) {
    test(
      'native failure during pause/resume stays terminal: $resuming',
      () async {
        await const SecureStorage().saveToken(_token());
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
            ),
            recordCaptureFactoryProvider.overrideWithValue((_) => capture),
            batchApplicationSupportDirectoryProvider.overrideWithValue(
              () async => Directory('${directory.path}/support'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(recordNotifierProvider.notifier)
          ..setAnonymous(true);
        await notifier.startRecording();
        if (resuming) await notifier.togglePause();
        void fail() => native.emit('failed', message: 'Hardware failure');
        if (resuming) {
          native.duringResume = fail;
        } else {
          native.duringPause = fail;
        }
        await notifier.togglePause();
        expect(
          container.read(recordNotifierProvider).status,
          RecordStatus.error,
        );
        expect(container.read(recordNotifierProvider).isActive, isFalse);
        expect(await native.file.exists(), isTrue);
      },
    );
  }

  for (final duringStart in [false, true]) {
    test(
      'notifier uses native paused state, including Start race=$duringStart',
      () async {
        await const SecureStorage().saveToken(_token());
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
            ),
            recordCaptureFactoryProvider.overrideWithValue((_) => capture),
            batchApplicationSupportDirectoryProvider.overrideWithValue(
              () async => Directory('${directory.path}/support'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(recordNotifierProvider.notifier)
          ..setAnonymous(true);
        if (duringStart) {
          native.duringStart = () =>
              native.emit('paused', message: 'Interrupted');
        }
        await notifier.startRecording();
        if (!duringStart) native.emit('paused', message: 'Interrupted');
        expect(
          container.read(recordNotifierProvider).status,
          RecordStatus.paused,
        );
        native.interrupted = true;
        await notifier.togglePause();
        expect(
          container.read(recordNotifierProvider).status,
          RecordStatus.paused,
        );
        expect(native.calls.where((x) => x == 'dispose'), isEmpty);
        native.interrupted = false;
        await notifier.togglePause();
        expect(
          container.read(recordNotifierProvider).status,
          RecordStatus.recording,
        );
        await container.read(authNotifierProvider.notifier).logout();
        native.emit('recording');
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(recordNotifierProvider).status,
          RecordStatus.idle,
        );
        expect(native.calls.where((x) => x == 'dispose'), isNotEmpty);
      },
    );
  }
}
