import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dict_ai/features/record/data/audio_capture.dart';
import 'package:dict_ai/features/record/data/ios_audio_capture.dart';
import 'package:dict_ai/features/record/data/wav_validator.dart';
import 'package:dict_ai/features/results/data/documents_api.dart';
import 'package:dict_ai/features/results/data/dto/speech_status_dto.dart';
import 'package:dict_ai/features/results/data/ios_document_export.dart';
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
  if (!Platform.isIOS || !{'capture', 'timeout', 'export'}.contains(phase)) {
    stdout.writeln('DICTAI_IOS_MEDIA FAIL invalid_configuration');
    exit(2);
  }
  final _NativeSmoke smoke = phase == 'export' ? _ExportSmoke() : _Smoke();
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

abstract interface class _NativeSmoke {
  String get checkpoint;
  Future<void> run(String phase);
  Future<void> cleanup();
}

final class _Smoke implements _NativeSmoke {
  @override
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

  @override
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

  @override
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

final class _ObservedExportChannel extends MethodChannel {
  const _ObservedExportChannel() : super('com.dictai/ios_document_export');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await super.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      const codes = {
        'busy',
        'invalid_file',
        'no_presenter',
        'provider_failure',
        'invalid_request',
      };
      stdout.writeln(
        'DICTAI_IOS_MEDIA CHECK export_native_error_${codes.contains(error.code) ? error.code : 'unexpected'}',
      );
      rethrow;
    }
  }
}

final class _ObservedShareSheet implements IosShareSheet {
  final native = NativeIosShareSheet(channel: const _ObservedExportChannel());
  Completer<void> started = Completer<void>();
  String? id;
  @override
  Future<IosShareOutcome> present({
    required String id,
    required File file,
    required String contentType,
    VoidCallback? onPresented,
  }) {
    this.id = id;
    final result = native.present(
      id: id,
      file: file,
      contentType: contentType,
      onPresented: onPresented,
    );
    started.complete();
    return result;
  }

  @override
  Future<void> cancel(String id) => native.cancel(id);
}

final class _ExportSmoke implements _NativeSmoke {
  @override
  String checkpoint = 'export_initialization';
  Directory? directory;
  Dio? dio;
  IosDocumentExporter? exporter;
  final sheet = _ObservedShareSheet();

  @override
  Future<void> run(String phase) async {
    checkpoint = 'export_foreground';
    final foreground = _ForegroundWaiter();
    WidgetsBinding.instance.addObserver(foreground);
    try {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await foreground.resumed.future.timeout(const Duration(seconds: 10));
      }
    } finally {
      WidgetsBinding.instance.removeObserver(foreground);
    }
    directory = await (await getTemporaryDirectory()).createTemp(
      'dictai-export-smoke-',
    );
    dio = Dio(BaseOptions(baseUrl: 'https://synthetic.invalid'))
      ..httpClientAdapter = _ExportFixtureAdapter();
    exporter = IosDocumentExporter(
      api: DocumentsApi(dio!),
      sheet: sheet,
      temporaryDirectory: () async => directory!,
      isCurrentSession: () => true,
    );
    final status = SpeechStatusDto.fromJson({
      'job_id': 'synthetic-job',
      'processing_version': 'fixture-v1',
      'workspace_id': null,
      'job_status': 'completed',
      'transcript_status': 'ready',
      'summary_status': 'ready',
      'summary_error': null,
    });
    for (final kind in [
      IosExportKind.transcriptTxt,
      IosExportKind.summaryPdf,
      IosExportKind.original,
    ]) {
      checkpoint = 'export_present_${kind.name}';
      final presented = Completer<void>();
      sheet.started = Completer<void>();
      final operation = exporter!.share(
        audioId: 'synthetic-audio',
        jobId: 'synthetic-job',
        kind: kind,
        status: status,
        onPresented: presented.complete,
      );
      unawaited(
        operation.then(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (!presented.isCompleted) presented.completeError(error, stack);
          },
        ),
      );
      checkpoint = 'export_wait_presented_${kind.name}';
      await presented.future.timeout(const Duration(seconds: 15));
      checkpoint = 'export_busy_${kind.name}';
      _require(exporter!.busy);
      checkpoint = 'export_file_${kind.name}';
      final files = await directory!
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      _require(files.length == 1 && await File(files.single.path).length() > 0);
      checkpoint = 'export_stale_cancel_${kind.name}';
      await sheet.cancel('stale-export-identity');
      _require(exporter!.busy && await files.single.exists());
      checkpoint = 'export_cancel_${kind.name}';
      await exporter!.cancel();
      _require(await operation == IosShareOutcome.cancelled);
      _require(await directory!.list().isEmpty);
      stdout.writeln(
        'DICTAI_IOS_MEDIA CHECK export_present_cancel_${kind.name}',
      );
    }
    // Cancel during UIKit's presentation animation, before its presented event.
    checkpoint = 'export_early_cancel';
    sheet.started = Completer<void>();
    final pending = exporter!.share(
      audioId: 'synthetic-audio',
      jobId: 'synthetic-job',
      kind: IosExportKind.transcriptTxt,
      status: status,
    );
    await sheet.started.future;
    await exporter!.cancel();
    _require(await pending == IosShareOutcome.cancelled);
    _require(await directory!.list().isEmpty);
    stdout.writeln('DICTAI_IOS_MEDIA CHECK export_early_cancel');
  }

  @override
  Future<void> cleanup() async {
    await exporter?.close();
    exporter?.dispose();
    dio?.close(force: true);
    if (directory case final owned? when await owned.exists()) {
      await owned.delete(recursive: true);
    }
  }
}

final class _ForegroundWaiter with WidgetsBindingObserver {
  final resumed = Completer<void>();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !resumed.isCompleted) {
      resumed.complete();
    }
  }
}

final class _ExportFixtureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<dynamic>? cancelFuture,
  ) async {
    final mime = options.headers['Accept'] as String;
    final bytes = switch (mime) {
      'text/plain' => Uint8List.fromList(
        'Synthetic export fixture\n'.codeUnits,
      ),
      'application/pdf' => _syntheticPdf(),
      'audio/wav' => _tone(),
      _ => throw StateError('Unexpected export fixture request'),
    };
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [mime],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Uint8List _syntheticPdf() {
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  final objects = [
    '<</Type /Catalog /Pages 2 0 R>>',
    '<</Type /Pages /Kids [3 0 R] /Count 1>>',
    '<</Type /Page /Parent 2 0 R /MediaBox [0 0 300 300] /Contents 4 0 R>>',
    '<</Length 0>>\nstream\n\nendstream',
  ];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(buffer.length);
    buffer.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final start = buffer.length;
  buffer.write('xref\n0 5\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n<</Size 5 /Root 1 0 R>>\nstartxref\n$start\n%%EOF\n');
  return Uint8List.fromList(buffer.toString().codeUnits);
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
