import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/results/data/documents_api.dart';
import 'package:dict_ai/features/results/data/dto/speech_status_dto.dart';
import 'package:dict_ai/features/results/data/ios_document_export.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

SpeechStatusDto _status({
  String transcript = 'ready',
  String summary = 'ready',
}) => SpeechStatusDto.fromJson({
  'job_id': 'job-a',
  'processing_version': 'v1',
  'workspace_id': null,
  'job_status': 'completed',
  'transcript_status': transcript,
  'summary_status': summary,
  'summary_error': null,
});

Uint8List _wav() {
  final bytes = Uint8List(46);
  final d = ByteData.sublistView(bytes);
  void tag(int at, String text) =>
      bytes.setRange(at, at + text.length, text.codeUnits);
  tag(0, 'RIFF');
  d.setUint32(4, 38, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, 1, Endian.little);
  d.setUint32(24, 16000, Endian.little);
  d.setUint32(28, 32000, Endian.little);
  d.setUint16(32, 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, 2, Endian.little);
  return bytes;
}

final class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions)? handler;
  Uint8List bytes = Uint8List.fromList(
    utf8.encode('Исходные байты\r\nстрока 2\n'),
  );
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    if (handler != null) return handler!(options);
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [options.headers['Accept'] as String],
        Headers.contentLengthHeader: [bytes.length.toString()],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Sheet implements IosShareSheet {
  Completer<void> presented = Completer<void>();
  Completer<IosShareOutcome> completion = Completer<IosShareOutcome>();
  File? file;
  String? id;
  String? contentType;
  bool failCancel = false;
  int calls = 0;
  final cancellations = <String>[];
  @override
  Future<IosShareOutcome> present({
    required String id,
    required File file,
    required String contentType,
    void Function()? onPresented,
  }) {
    calls++;
    this.id = id;
    this.file = file;
    this.contentType = contentType;
    onPresented?.call();
    presented.complete();
    return completion.future;
  }

  @override
  Future<void> cancel(String id) async {
    cancellations.add(id);
    if (failCancel) throw const ServerException('Системный экспорт не закрыт.');
    // Explicitly keep the result pending: UIKit has not finished dismissal yet.
  }
}

final class _Harness {
  _Harness(this.root, this.dio, this.adapter, this.sheet);
  final Directory root;
  final Dio dio;
  final _Adapter adapter;
  final _Sheet sheet;
  bool current = true;
  late IosDocumentExporter exporter;
  static Future<_Harness> create({
    Future<void> Function(Directory)? prepare,
    Future<void> Function(DownloadedFile)? delete,
  }) async {
    final root = await Directory.systemTemp.createTemp('dictai-export-test-');
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final h = _Harness(root, dio, adapter, _Sheet());
    h.exporter = IosDocumentExporter(
      api: DocumentsApi(dio),
      sheet: h.sheet,
      temporaryDirectory: () async => root,
      isCurrentSession: () => h.current,
      prepareDirectory: prepare,
      deleteDownloaded: delete,
    );
    return h;
  }

  Future<IosShareOutcome> start({
    IosExportKind kind = IosExportKind.transcriptTxt,
    SpeechStatusDto? status,
    String jobId = 'job-a',
  }) => exporter.share(
    audioId: 'audio-a',
    jobId: jobId,
    kind: kind,
    status: status ?? _status(),
  );
  Future<void> cleanup() async {
    if (!sheet.completion.isCompleted) {
      sheet.completion.complete(IosShareOutcome.cancelled);
    }
    await exporter.close();
    exporter.dispose();
    dio.close(force: true);
    await root.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'transcript and summary permissions are independent; missing status permits nothing',
    () {
      expect(
        IosExportKind.transcriptTxt.canRequest(_status(summary: 'pending')),
        isTrue,
      );
      expect(
        IosExportKind.transcriptPdf.canRequest(_status(transcript: 'pending')),
        isFalse,
      );
      expect(
        IosExportKind.summaryPdf.canRequest(_status(transcript: 'failed')),
        isTrue,
      );
      expect(
        IosExportKind.summaryTxt.canRequest(_status(summary: 'failed')),
        isFalse,
      );
      for (final kind in IosExportKind.values) {
        expect(kind.canRequest(null), isFalse);
      }
    },
  );

  for (final kind in IosExportKind.values) {
    test(
      '${kind.name}: original server bytes, MIME and fixed filename survive until completion',
      () async {
        final h = await _Harness.create();
        addTearDown(h.cleanup);
        h.adapter.bytes = kind == IosExportKind.original
            ? _wav()
            : kind.contentType == 'application/pdf'
            ? Uint8List.fromList('%PDF-1.7\nfixture\n'.codeUnits)
            : h.adapter.bytes;
        final future = h.start(kind: kind);
        await h.sheet.presented.future;
        expect(await h.sheet.file!.readAsBytes(), h.adapter.bytes);
        expect(h.sheet.contentType, kind.contentType);
        expect(
          h.sheet.file!.uri.pathSegments.last,
          kind.document?.fileName ?? 'original.wav',
        );
        expect(
          h.adapter.requests.single.queryParameters,
          kind == IosExportKind.original ? isEmpty : {'job_id': 'job-a'},
        );
        expect(h.exporter.busy, isTrue);
        final saved = File('${h.root.path}/user-export.bin');
        await h.sheet.file!.copy(saved.path);
        h.sheet.completion.complete(IosShareOutcome.completed);
        expect(await future, IosShareOutcome.completed);
        expect(await h.sheet.file!.exists(), isFalse);
        expect(await saved.readAsBytes(), h.adapter.bytes);
        expect(h.exporter.needsCleanup, isFalse);
      },
    );
  }

  test(
    'double tap and mismatched/ungenerated documents never create a second transfer',
    () async {
      final h = await _Harness.create();
      addTearDown(h.cleanup);
      await expectLater(
        h.start(jobId: 'other-job'),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        h.start(status: _status(transcript: 'pending')),
        throwsA(isA<ValidationException>()),
      );
      expect(h.adapter.requests, isEmpty);
      final pending = h.start();
      await h.sheet.presented.future;
      await expectLater(h.start(), throwsA(isA<ValidationException>()));
      expect(h.adapter.requests, hasLength(1));
      expect(h.sheet.calls, 1);
      h.sheet.completion.complete(IosShareOutcome.cancelled);
      await pending;
    },
  );

  test(
    'document status ready with R05 unavailable does not open a sheet',
    () async {
      final h = await _Harness.create();
      addTearDown(h.cleanup);
      h.adapter.handler = (_) async => ResponseBody.fromString(
        '{"error":"document unavailable"}',
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
      await expectLater(
        h.start(kind: IosExportKind.transcriptPdf),
        throwsA(isA<AppException>()),
      );
      expect(h.sheet.calls, 0);
      expect(h.exporter.errorMessage, isNotNull);
      expect(await h.root.list().isEmpty, isTrue);
    },
  );

  test('provider failure is visible and cleans only owned staging', () async {
    final h = await _Harness.create();
    addTearDown(h.cleanup);
    final operation = h.start();
    final expected = expectLater(operation, throwsA(isA<ServerException>()));
    await h.sheet.presented.future;
    h.sheet.completion.completeError(
      const ServerException('Поставщик файлов недоступен.'),
    );
    await expected;
    expect(h.exporter.errorMessage, 'Поставщик файлов недоступен.');
    expect(await h.sheet.file!.exists(), isFalse);
  });

  test('cancel waits for activity settlement before deleting input', () async {
    final h = await _Harness.create();
    addTearDown(h.cleanup);
    final pending = h.start();
    await h.sheet.presented.future;
    await h.exporter.cancel();
    expect(h.sheet.cancellations, [h.sheet.id]);
    expect(await h.sheet.file!.exists(), isTrue);
    expect(h.exporter.busy, isTrue);
    h.sheet.completion.complete(IosShareOutcome.cancelled);
    expect(await pending, IosShareOutcome.cancelled);
    expect(await h.sheet.file!.exists(), isFalse);
  });

  test(
    'failed native cancel on session close keeps input until real completion',
    () async {
      final h = await _Harness.create();
      addTearDown(h.cleanup);
      final pending = h.start();
      await h.sheet.presented.future;
      h.current = false;
      h.sheet.failCancel = true;
      var closed = false;
      final closing = h.exporter.close().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      expect(await h.sheet.file!.exists(), isTrue);
      h.sheet.completion.complete(IosShareOutcome.completed);
      expect(await pending, IosShareOutcome.cancelled);
      await closing;
      expect(await h.sheet.file!.exists(), isFalse);
    },
  );

  test(
    'session becomes stale during protected directory preparation: no HTTP or sheet',
    () async {
      final gate = Completer<void>();
      final prepared = Completer<void>();
      final h = await _Harness.create(
        prepare: (_) {
          prepared.complete();
          return gate.future;
        },
      );
      addTearDown(h.cleanup);
      final pending = h.start();
      await prepared.future;
      h.current = false;
      gate.complete();
      expect(await pending, IosShareOutcome.cancelled);
      expect(h.adapter.requests, isEmpty);
      expect(h.sheet.calls, 0);
      expect(await h.root.list().isEmpty, isTrue);
    },
  );

  test(
    'cancel in-flight partial transfer never publishes or retains partial bytes',
    () async {
      final h = await _Harness.create();
      addTearDown(h.cleanup);
      final body = StreamController<Uint8List>();
      final requested = Completer<void>();
      h.adapter.handler = (_) async {
        requested.complete();
        return ResponseBody(
          body.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['text/plain'],
          },
        );
      };
      final pending = h.start();
      await requested.future;
      body.add(Uint8List.fromList('partial'.codeUnits));
      await Future<void>.delayed(Duration.zero);
      await h.exporter.cancel();
      await body.close();
      expect(await pending, IosShareOutcome.cancelled);
      expect(h.sheet.calls, 0);
      expect(await h.root.list().isEmpty, isTrue);
    },
  );

  test(
    'cleanup failure retains ownership and blocks new export until explicit retry',
    () async {
      var fail = true;
      final h = await _Harness.create(
        delete: (file) async {
          if (fail) {
            throw const ServerException(
              'Удаление временного файла не выполнено.',
            );
          }
          await file.delete();
        },
      );
      addTearDown(h.cleanup);
      final pending = h.start();
      final expected = expectLater(pending, throwsA(isA<ServerException>()));
      await h.sheet.presented.future;
      h.sheet.completion.complete(IosShareOutcome.completed);
      await expected;
      expect(h.exporter.needsCleanup, isTrue);
      expect(await h.sheet.file!.exists(), isTrue);
      await expectLater(h.start(), throwsA(isA<ValidationException>()));
      fail = false;
      await h.exporter.retryCleanup();
      expect(h.exporter.needsCleanup, isFalse);
      expect(h.exporter.errorMessage, isNull);
      expect(await h.sheet.file!.exists(), isFalse);
    },
  );

  test(
    'prepare failure removes even an owned leftover partial subtree',
    () async {
      final h = await _Harness.create(
        prepare: (directory) async {
          final partial = await Directory(
            '${directory.path}/dictai-download-incomplete',
          ).create();
          await File('${partial.path}/payload.part').writeAsString('partial');
          throw const ServerException('Подготовка не выполнена.');
        },
      );
      addTearDown(h.cleanup);
      await expectLater(h.start(), throwsA(isA<ServerException>()));
      expect(await h.root.list().isEmpty, isTrue);
      expect(h.sheet.calls, 0);
    },
  );

  test(
    'large download is streamed to file before sheet; no bytes in channel contract',
    () async {
      final h = await _Harness.create();
      addTearDown(h.cleanup);
      const count = 320;
      const chunkBytes = 65536;
      h.adapter.handler = (_) async => ResponseBody(
        Stream.fromIterable(
          Iterable.generate(count, (_) => Uint8List(chunkBytes)),
        ),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
          Headers.contentLengthHeader: ['${count * chunkBytes}'],
        },
      );
      final pending = h.start();
      await h.sheet.presented.future;
      expect(await h.sheet.file!.length(), count * chunkBytes);
      h.sheet.completion.complete(IosShareOutcome.cancelled);
      await pending;
      expect(await h.sheet.file!.exists(), isFalse);
    },
  );

  test(
    'native channel maps completion/cancel and sends only local file metadata',
    () async {
      const channel = MethodChannel('dictai/export-contract-fixture');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final arguments = <Map<dynamic, dynamic>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        arguments.add(call.arguments as Map);
        return call.method == 'share' ? 'cancelled' : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final native = NativeIosShareSheet(channel: channel);
      expect(
        await native.present(
          id: 'fixture-id',
          file: File('/tmp/transcript.txt'),
          contentType: 'text/plain',
        ),
        IosShareOutcome.cancelled,
      );
      await native.cancel('fixture-id');
      expect(arguments.first, {
        'id': 'fixture-id',
        'path': '/tmp/transcript.txt',
        'contentType': 'text/plain',
      });
      expect(arguments.last, {'id': 'fixture-id'});
    },
  );
}
