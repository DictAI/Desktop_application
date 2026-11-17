import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/lifecycle/ios_lifecycle_observer.dart';
import 'package:dict_ai/features/results/data/documents_api.dart';
import 'package:dict_ai/features/results/data/original_audio_cache.dart';
import 'package:dict_ai/features/results/presentation/audio_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Uint8List _wav() {
  final bytes = Uint8List(32044);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, 32000, Endian.little);
  return bytes;
}

class _Player implements AudioPlayer {
  _Player(this.order) {
    creatingCompleter.complete();
  }
  final List<String> order;
  @override
  final creatingCompleter = Completer<void>();
  final positions = StreamController<Duration>.broadcast(sync: true);
  final events = StreamController<AudioEvent>.broadcast(sync: true);
  Completer<void>? contextGate;
  Completer<void>? sourceGate;
  Completer<void>? resumeGate;
  String? path;
  Duration? sought;
  bool disposed = false;
  bool failFinalDispose = false;
  bool failResume = false;
  bool failStop = false;
  @override
  PlayerState get state =>
      disposed ? PlayerState.disposed : PlayerState.stopped;
  @override
  Stream<Duration> get onDurationChanged => eventStream
      .where((event) => event.eventType == AudioEventType.duration)
      .map((event) => event.duration!);
  @override
  Stream<Duration> get onPositionChanged => positions.stream;
  @override
  Stream<void> get onPlayerComplete =>
      eventStream.where((event) => event.eventType == AudioEventType.complete);
  @override
  Stream<AudioEvent> get eventStream => events.stream;
  @override
  Future<void> setAudioContext(AudioContext context) async {
    order.add('context');
    await contextGate?.future;
    order.add('contextDone');
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {
    order.add('mode');
  }

  @override
  Future<void> setSourceDeviceFile(String path, {String? mimeType}) async {
    this.path = path;
    order.add('source');
    await sourceGate?.future;
    order.add('sourceDone');
  }

  @override
  Future<Duration?> getDuration() async => const Duration(seconds: 2);
  @override
  Future<void> resume() async {
    order.add('resume');
    await resumeGate?.future;
    if (failResume) throw StateError('Synthetic prepare failure');
  }

  @override
  Future<void> pause() async {
    order.add('pause');
  }

  @override
  Future<void> seek(Duration position) async {
    sought = position;
  }

  @override
  Future<void> stop() async {
    if (disposed) throw StateError('AudioPlayer has been disposed');
    order.add('stop');
    if (failStop) throw StateError('Synthetic stop failure');
  }

  @override
  Future<void> dispose() async {
    order.add('dispose');
    disposed = true;
    if (failFinalDispose) {
      throw StateError('Synthetic final native dispose failure');
    }
  }

  Future<void> closeStreams() async {
    await positions.close();
    await events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _until(bool Function() check) async {
  for (var i = 0; i < 100 && !check(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(check(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.dictai/playback');
  late Directory temporary;
  late ScriptedAdapter adapter;
  late Dio dio;
  late OriginalAudioCache cache;
  late _Player player;
  late List<String> order;
  late IosPlaybackCoordinator coordinator;
  late ResultAudioController controller;
  late bool current;
  String? owner;
  bool reject = false;
  void enqueue() => adapter.defer().complete(
    ResponseBody.fromBytes(
      _wav(),
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/wav'],
      },
    ),
  );
  setUp(() async {
    current = true;
    reject = false;
    owner = null;
    order = [];
    temporary = await Directory.systemTemp.createTemp('dictai-cache-test-');
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    cache = OriginalAudioCache(
      ownerId: 'account-A',
      api: DocumentsApi(dio),
      temporaryDirectory: () async => temporary,
      isCurrentSession: () => current,
    );
    player = _Player(order);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'acquire') {
            if (reject) throw PlatformException(code: 'busy');
            owner = (call.arguments as Map)['id'] as String;
          }
          order.add('native-${call.method}');
          return null;
        });
    coordinator = IosPlaybackCoordinator(channel: channel);
    controller = ResultAudioController(
      cache: cache,
      audioId: 'audio',
      jobId: 'job',
      isCurrentSession: () => current,
      coordinator: coordinator,
      playerFactory: () => player,
    );
  });
  tearDown(() async {
    await controller.close();
    controller.dispose();
    await cache.close();
    await player.closeStreams();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
    dio.close(force: true);
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });
  Future<void> nativeStop() async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            MethodCall('stopForCapture', {'id': owner}),
          ),
          (data) {
            try {
              channel.codec.decodeEnvelope(data!);
              done.complete();
            } catch (error, stack) {
              done.completeError(error, stack);
            }
          },
        );
    return done.future;
  }

  test(
    'same key shares completed original, leases prevent eviction, account/job keys isolate',
    () async {
      enqueue();
      final a = await cache.acquire('audio', 'job');
      final b = await cache.acquire('audio', 'job');
      expect(a.file.path, b.file.path);
      expect(adapter.requests, hasLength(1));
      await expectLater(
        cache.acquire('audio', 'other-job'),
        throwsA(isA<ValidationException>()),
      );
      await a.release();
      await a.release();
      expect(await b.file.exists(), isTrue);
      await b.release();
      enqueue();
      final c = await cache.acquire('audio', 'other-job');
      expect(c.file.path, isNot(a.file.path));
      expect(await a.file.exists(), isFalse);
      await c.release();
      current = false;
      await expectLater(
        cache.acquire('audio', 'job'),
        throwsA(isA<UnauthorizedException>()),
      );
    },
  );

  test(
    'concurrent same key deduplicates; different key does not start parallel quota staging',
    () async {
      final response = adapter.defer();
      final first = cache.acquire('audio', 'job');
      final second = cache.acquire('audio', 'job');
      final other = cache.acquire('other', 'job');
      final rejected = expectLater(other, throwsA(isA<ValidationException>()));
      response.complete(
        ResponseBody.fromBytes(
          _wav(),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      final leases = await Future.wait([first, second]);
      await rejected;
      expect(adapter.requests, hasLength(1));
      await Future.wait(leases.map((lease) => lease.release()));
    },
  );

  test(
    'missing cached tmp file is refetched rather than leased as ready',
    () async {
      enqueue();
      final a = await cache.acquire('audio', 'job');
      await a.release();
      await a.file.delete();
      enqueue();
      final b = await cache.acquire('audio', 'job');
      expect(await b.file.exists(), isTrue);
      expect(adapter.requests, hasLength(2));
      await b.release();
    },
  );

  test(
    'failed eviction retains cleanup ownership and retry does not accumulate old originals',
    () async {
      await cache.close();
      var fail = true;
      cache = OriginalAudioCache(
        ownerId: 'A',
        api: DocumentsApi(dio),
        temporaryDirectory: () async => temporary,
        isCurrentSession: () => current,
        deleteDownloaded: (download) async {
          if (fail) {
            fail = false;
            throw const ServerException('Synthetic cleanup failure');
          }
          await download.delete();
        },
      );
      enqueue();
      final a = await cache.acquire('audio', 'job');
      await a.release();
      await expectLater(
        cache.acquire('other', 'job'),
        throwsA(isA<ServerException>()),
      );
      expect(adapter.requests, hasLength(1));
      expect(await a.file.exists(), isTrue);
      enqueue();
      final b = await cache.acquire('other', 'job');
      expect(await a.file.exists(), isFalse);
      expect(adapter.requests, hasLength(2));
      await b.release();
    },
  );

  test(
    'close waits leased decoder input and failed cleanup may be retried',
    () async {
      enqueue();
      final lease = await cache.acquire('audio', 'job');
      var done = false;
      final closing = cache.close().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(await lease.file.exists(), isTrue);
      await lease.release();
      await closing;
      expect(await lease.file.exists(), isFalse);
    },
  );

  test(
    'play pause seek and actual duration use one authorized completed file',
    () async {
      enqueue();
      await controller.toggle();
      expect(controller.playing, isTrue);
      expect(controller.duration, const Duration(seconds: 2));
      expect(
        order.indexOf('native-acquire'),
        lessThan(order.indexOf('context')),
      );
      await controller.seek(const Duration(seconds: 7));
      expect(player.sought, const Duration(seconds: 2));
      await controller.toggle();
      expect(controller.playing, isFalse);
      await controller.toggle();
      expect(controller.playing, isTrue);
      expect(adapter.requests, hasLength(1));
      player.events.add(const AudioEvent(eventType: AudioEventType.complete));
      expect(controller.playing, isFalse);
    },
  );

  for (final delayed in ['context', 'source', 'resume']) {
    test(
      'capture ACK waits delayed $delayed and cannot leave a late resume',
      () async {
        final gate = Completer<void>();
        if (delayed == 'context') player.contextGate = gate;
        if (delayed == 'source') player.sourceGate = gate;
        if (delayed == 'resume') player.resumeGate = gate;
        enqueue();
        final playing = controller.toggle();
        await _until(() => order.contains(delayed));
        var acknowledged = false;
        final stopping = nativeStop().then((_) => acknowledged = true);
        await Future<void>.delayed(Duration.zero);
        expect(acknowledged, isFalse);
        expect(order, isNot(contains('native-release')));
        gate.complete();
        await playing;
        await stopping;
        expect(player.disposed, isTrue);
        expect(controller.playing, isFalse);
        expect(
          order.indexOf('dispose'),
          lessThan(order.indexOf('native-release')),
        );
        if (delayed != 'resume') expect(order, isNot(contains('resume')));
      },
    );
  }

  test(
    'session revocation during source preparation keeps input until decoder disposal',
    () async {
      player.sourceGate = Completer<void>();
      enqueue();
      final playing = controller.toggle();
      await _until(() => player.path != null);
      current = false;
      final stopping = controller.close();
      final closing = cache.close();
      expect(await File(player.path!).exists(), isTrue);
      player.sourceGate!.complete();
      await playing;
      await stopping;
      await closing;
      expect(order, isNot(contains('resume')));
      expect(await File(player.path!).exists(), isFalse);
    },
  );

  test(
    'native capture reservation refuses playback before decoder creation',
    () async {
      reject = true;
      enqueue();
      await controller.toggle();
      expect(controller.playing, isFalse);
      expect(controller.errorMessage, isNotNull);
      expect(order, isNot(contains('context')));
      expect(order, isNot(contains('resume')));
    },
  );

  test(
    'decoder stream error is handled once and releases input safely',
    () async {
      enqueue();
      await controller.toggle();
      final path = player.path!;
      player.events.addError(StateError('Synthetic native decoder error'));
      await _until(() => order.contains('native-release'));
      expect(controller.playing, isFalse);
      expect(controller.errorMessage, contains('воспроизвести'));
      expect(order.where((value) => value == 'stop'), hasLength(1));
      expect(
        order.indexOf('dispose'),
        lessThan(order.indexOf('native-release')),
      );
      await cache.close();
      expect(await File(path).exists(), isFalse);
    },
  );

  test('foreground loss stops playback; resume does not start sound', () async {
    controller.dispose();
    final lifecycle = IosLifecycleObserver();
    controller = ResultAudioController(
      cache: cache,
      audioId: 'audio',
      jobId: 'job',
      isCurrentSession: () => current,
      coordinator: coordinator,
      lifecycle: lifecycle,
      playerFactory: () => player,
    );
    enqueue();
    await controller.toggle();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await _until(() => player.disposed);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(order.where((x) => x == 'resume'), hasLength(1));
    expect(controller.playing, isFalse);
    lifecycle.dispose();
  });
  test(
    'cached validation and eviction cannot lease a deleting input',
    () async {
      enqueue();
      final first = await cache.acquire('audio', 'job');
      await first.release();
      final hit = cache.acquire('audio', 'job');
      final other = cache.acquire('other', 'job');
      final rejected = expectLater(other, throwsA(isA<ValidationException>()));
      final lease = await hit;
      await rejected;
      expect(lease.file.path, first.file.path);
      expect(await lease.file.exists(), isTrue);
      expect(adapter.requests, hasLength(1));
      await lease.release();
    },
  );

  test('coordinator serializes three concurrent playback owners', () async {
    final aStopped = Completer<void>();
    final bStopped = Completer<void>();
    await coordinator.acquire('A', () async {
      order.add('stop-A');
      await aStopped.future;
      await coordinator.release('A');
    });
    final b = coordinator.acquire('B', () async {
      order.add('stop-B');
      await bStopped.future;
      await coordinator.release('B');
    });
    final c = coordinator.acquire('C', () async {});
    await _until(() => order.contains('stop-A'));
    expect(owner, 'A');
    aStopped.complete();
    await b;
    await _until(() => order.contains('stop-B'));
    expect(owner, 'B');
    bStopped.complete();
    await c;
    expect(owner, 'C');
    await coordinator.release('C');
  });
  test(
    'final plugin disposal failure after Dart-disposed keeps audio stopped and frees safe input',
    () async {
      enqueue();
      await controller.toggle();
      final path = player.path!;
      player.failFinalDispose = true;
      await controller.stop();
      expect(controller.playing, isFalse);
      expect(controller.errorMessage, contains('остановлен'));
      expect(order.last, 'native-release');
      await controller.stop();
      await cache.close();
      expect(await File(path).exists(), isFalse);
    },
  );
  test(
    'button handles preparation plus cleanup failure and retains safe retry ownership',
    () async {
      player.failResume = true;
      player.failStop = true;
      enqueue();
      await expectLater(controller.toggle(), completes);
      expect(controller.errorMessage, contains('освободить'));
      expect(order, isNot(contains('native-release')));
      final path = player.path!;
      expect(await File(path).exists(), isTrue);
      player.failStop = false;
      await controller.stop();
      await cache.close();
      expect(await File(path).exists(), isFalse);
    },
  );

  test(
    'native stop failure cannot acknowledge unsafe capture cleanup',
    () async {
      enqueue();
      await controller.toggle();
      player.failStop = true;
      await expectLater(nativeStop(), throwsA(isA<PlatformException>()));
      expect(order, isNot(contains('native-release')));
      player.failStop = false;
      await nativeStop();
      expect(order.last, 'native-release');
    },
  );

  test(
    'close cleanup failure preserves owned reference for a successful retry',
    () async {
      await cache.close();
      var fail = true;
      cache = OriginalAudioCache(
        ownerId: 'A',
        api: DocumentsApi(dio),
        temporaryDirectory: () async => temporary,
        isCurrentSession: () => current,
        deleteDownloaded: (download) async {
          if (fail) {
            fail = false;
            throw const ServerException('Synthetic delete failure');
          }
          await download.delete();
        },
      );
      enqueue();
      final lease = await cache.acquire('audio', 'job');
      await lease.release();
      await expectLater(cache.close(), throwsA(isA<ServerException>()));
      expect(await lease.file.exists(), isTrue);
      await cache.close();
      expect(await lease.file.exists(), isFalse);
    },
  );

  test(
    'eviction started first cannot return another key to queued old-key acquire',
    () async {
      await cache.close();
      final deleting = Completer<void>();
      final deleted = Completer<void>();
      cache = OriginalAudioCache(
        ownerId: 'A',
        api: DocumentsApi(dio),
        temporaryDirectory: () async => temporary,
        isCurrentSession: () => current,
        deleteDownloaded: (download) async {
          if (!deleting.isCompleted) {
            deleting.complete();
            await deleted.future;
          }
          await download.delete();
        },
      );
      enqueue();
      final first = await cache.acquire('audio', 'job');
      await first.release();
      enqueue();
      final replacement = cache.acquire('other', 'job');
      await deleting.future;
      final stale = cache.acquire('audio', 'job');
      final rejected = expectLater(stale, throwsA(isA<ValidationException>()));
      expect(await first.file.exists(), isTrue);
      deleted.complete();
      final lease = await replacement;
      await rejected;
      expect(lease.file.path, isNot(first.file.path));
      expect(adapter.requests, hasLength(2));
      await lease.release();
    },
  );
}
