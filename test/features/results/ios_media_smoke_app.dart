import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/ios_audio_capture.dart';
import 'package:dict_ai/features/record/data/wav_validator.dart';
import 'package:dict_ai/features/results/data/documents_api.dart';
import 'package:dict_ai/features/results/data/original_audio_cache.dart';
import 'package:dict_ai/features/results/presentation/audio_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

// Explicit native target. Production never imports this synthetic fixture.
const _compiledPhase = String.fromEnvironment(
  'DICTAI_IOS_MEDIA_PHASE',
  defaultValue: 'capture',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final phase =
      Platform.environment['DICTAI_IOS_MEDIA_PHASE'] ?? _compiledPhase;
  runApp(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('DictAI media verification')),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  if (!Platform.isIOS || !{'capture', 'timeout'}.contains(phase)) {
    stdout.writeln('DICTAI_IOS_MEDIA FAIL invalid_configuration');
    exit(2);
  }
  final smoke = _Smoke();
  stdout.writeln('DICTAI_IOS_MEDIA START $phase');
  var passed = false;
  try {
    await smoke.run(phase).timeout(const Duration(seconds: 90));
    passed = true;
  } catch (_) {
    stdout.writeln(
      'DICTAI_IOS_MEDIA FAIL $phase checkpoint=${smoke.checkpoint}',
    );
  } finally {
    try {
      await smoke.cleanup().timeout(const Duration(seconds: 15));
    } catch (_) {
      passed = false;
      stdout.writeln('DICTAI_IOS_MEDIA FAIL $phase checkpoint=cleanup');
    }
  }
  if (passed) stdout.writeln('DICTAI_IOS_MEDIA PASS $phase');
  exit(passed ? 0 : 1);
}

final class _ObservedPlaybackChannel extends MethodChannel {
  _ObservedPlaybackChannel(this.order) : super('com.dictai/ios_playback');
  final List<String> order;
  String? oldOwner;
  Completer<void>? ackGate;
  @override
  void setMethodCallHandler(Future<dynamic> Function(MethodCall)? handler) {
    super.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              order.add('request-${call.method}');
              final value = await handler(call);
              order.add('stopped-${call.method}');
              if (call.method == 'stopForCapture') await ackGate?.future;
              order.add('ack-${call.method}');
              return value;
            },
    );
  }

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    final value = await super.invokeMethod<T>(method, arguments);
    if (method == 'acquire') oldOwner = (arguments as Map)['id'] as String;
    order.add('native-$method');
    return value;
  }
}

final class _Smoke {
  String checkpoint = 'initialization';
  final order = <String>[];
  final captures = <IosAudioCapture>[];
  late final channel = _ObservedPlaybackChannel(order);
  late final coordinator = IosPlaybackCoordinator(channel: channel);
  ResultAudioController? controller;
  OriginalAudioCache? cache;
  Dio? dio;

  IosAudioCapture createCapture() {
    final capture = IosAudioCapture(
      commandTimeout: const Duration(seconds: 10),
      permissionTimeout: const Duration(seconds: 30),
    );
    captures.add(capture);
    return capture;
  }

  Future<void> run(String phase) async {
    dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'))
      ..httpClientAdapter = _FixtureAdapter();
    cache = OriginalAudioCache(
      ownerId: 'synthetic-account',
      api: DocumentsApi(dio!),
      temporaryDirectory: getTemporaryDirectory,
      isCurrentSession: () => true,
    );
    controller = ResultAudioController(
      cache: cache!,
      audioId: 'synthetic-audio',
      jobId: 'synthetic-job',
      isCurrentSession: () => true,
      coordinator: coordinator,
    );
    checkpoint = 'real_player_prepare';
    await controller!.toggle();
    _require(controller!.playing && controller!.errorMessage == null);
    _require(
      controller!.duration != null &&
          controller!.duration!.inMilliseconds >= 1900,
    );
    checkpoint = 'real_player_seek_pause_resume';
    await controller!.seek(const Duration(milliseconds: 500));
    await controller!.toggle();
    _require(!controller!.playing);
    await controller!.toggle();
    _require(controller!.playing);
    if (phase == 'capture') {
      await controller!.seek(const Duration(milliseconds: 1850));
    }
    final previousOwner = channel.oldOwner!;
    var capture = createCapture();
    if (phase == 'timeout') channel.ackGate = Completer<void>();
    checkpoint = 'capture_handshake';
    var failed = false;
    try {
      await capture.start();
    } catch (_) {
      failed = true;
    }
    if (phase == 'timeout') {
      _require(failed && capture.status == CaptureStatus.failed);
      _require(
        order.contains('stopped-stopForCapture') &&
            !order.contains('ack-stopForCapture'),
      );
      stdout.writeln('DICTAI_IOS_MEDIA CHECK timeout_before_late_ack');
      checkpoint = 'replacement_capture';
      capture = createCapture();
      await capture.start();
      _require(capture.status == CaptureStatus.recording);
      channel.ackGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _require(capture.status == CaptureStatus.recording);
    } else {
      _require(!failed && capture.status == CaptureStatus.recording);
      final request = order.indexOf('request-stopForCapture');
      final stopped = order.indexOf('stopped-stopForCapture');
      final acknowledged = order.indexOf('ack-stopForCapture');
      _require(request >= 0 && stopped > request && acknowledged > stopped);
      stdout.writeln(
        'DICTAI_IOS_MEDIA CHECK stopped_and_acknowledged_before_capture',
      );
    }
    checkpoint = 'stale_release';
    await channel.invokeMethod<void>('release', {'id': previousOwner});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _require(capture.status == CaptureStatus.recording);
    checkpoint = 'finish_valid_native_wav';
    final file = await capture.finish(confirmed: true);
    _require(file != null);
    final validated = await const WavValidator().validate(file!);
    _require(validated.fileBytes > 44);
    stdout.writeln('DICTAI_IOS_MEDIA CHECK valid_capture_after_stale_release');
  }

  Future<void> cleanup() async {
    if (channel.ackGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    for (final capture in captures) {
      final path = capture.sourcePath;
      await capture.dispose();
      final owned = path ?? capture.sourcePath;
      if (owned != null) {
        final file = File(owned);
        if (await file.exists()) await file.delete();
        if (await file.parent.exists()) await file.parent.delete();
      }
    }
    await controller?.close();
    controller?.dispose();
    await cache?.close();
    dio?.close(force: true);
    channel.setMethodCallHandler(null);
  }
}

final class _FixtureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path != '/ingest/v2/audio/synthetic-audio/original') {
      throw StateError('Unexpected fixture request');
    }
    return ResponseBody.fromBytes(
      _tone(),
      200,
      headers: {
        Headers.contentTypeHeader: ['audio/wav'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _tone() {
  final bytes = Uint8List(64044);
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
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, 64000, Endian.little);
  for (var i = 0; i < 32000; i++) {
    data.setInt16(
      44 + i * 2,
      (math.sin(i * 2 * math.pi * 440 / 16000) * 1500).round(),
      Endian.little,
    );
  }
  return bytes;
}

void _require(bool value) {
  if (!value) throw StateError('Media smoke assertion failed');
}
