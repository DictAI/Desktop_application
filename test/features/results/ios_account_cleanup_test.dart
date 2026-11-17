import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/core/storage/ios_file_policy.dart';
import 'package:flutter/services.dart';
import 'package:dict_ai/features/auth/presentation/auth_notifier.dart';
import 'package:dict_ai/features/record/data/dto/pending_upload.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/pending_upload_store.dart';
import 'package:dict_ai/features/results/data/ios_document_export.dart';
import 'package:dict_ai/features/results/presentation/result_detail_notifier.dart';
import 'package:dict_ai/features/results/presentation/results_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _audio = '33333333-3333-4333-8333-333333333333';
const _job = '44444444-4444-4444-8444-444444444444';
const _storage = SecureStorage(namespace: 'account-cleanup-fixture');

String _jwt(String owner) {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': owner, 'exp': DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000})}.fixture';
}

Uint8List _wav() {
  final bytes = Uint8List(48);
  final view = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  view.setUint32(4, 40, Endian.little);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, 16000, Endian.little);
  view.setUint32(28, 32000, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  view.setUint32(40, 4, Endian.little);
  return bytes;
}

class _Sheet implements IosShareSheet {
  final presented = Completer<File>();
  final completion = Completer<IosShareOutcome>();
  int cancellations = 0;
  @override
  Future<IosShareOutcome> present({
    required String id,
    required File file,
    required String contentType,
    VoidCallback? onPresented,
  }) {
    presented.complete(file);
    onPresented?.call();
    return completion.future;
  }

  @override
  Future<void> cancel(String id) async {
    cancellations++;
    if (!completion.isCompleted) completion.complete(IosShareOutcome.cancelled);
  }
}

class _Transport extends ScriptedAdapter {
  Completer<ResponseBody>? statusGate;
  Completer<ResponseBody>? originalGate;
  int deleteStatus = 204;
  bool staleRow = true;
  Map<String, Object?> get status => {
    'job_id': _job,
    'processing_version': 'fixture-v1',
    'workspace_id': null,
    'job_status': 'completed',
    'transcript_status': 'ready',
    'summary_status': 'failed',
    'summary_error': 'not_configured',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancellation,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') {
      return ScriptedAdapter.reply(
        deleteStatus,
        deleteStatus == 204 ? null : {'error': 'missing result'},
      );
    }
    if (options.path == '/meetings/results') {
      return ScriptedAdapter.reply(200, {
        'data': staleRow
            ? [
                {
                  'result_id': _job,
                  'audio_id': _audio,
                  'workspace_id': '',
                  'workspace_name': '',
                  'upload_user_id': _owner,
                  'summary_url': '',
                  'transcript_url': '',
                  'status': 'done',
                  'created_at': '2026-11-18T09:00:00Z',
                },
              ]
            : [],
        'pagination': {
          'page': 1,
          'limit': 20,
          'total': staleRow ? 1 : 0,
          'total_pages': staleRow ? 1 : 0,
        },
      });
    }
    if (options.path.endsWith('/speech-status')) {
      if (statusGate case final held?) {
        statusGate = null;
        return held.future;
      }
      return ScriptedAdapter.reply(200, status);
    }
    if (options.path.endsWith('/structured')) {
      final canonical =
          (jsonDecode(
                    File('test/fixtures/canonical_v1.json').readAsStringSync(),
                  )
                  as Map)['speech']
              as Map;
      canonical['recording_id'] = _audio;
      canonical['job_id'] = _job;
      canonical['processing_version'] = 'fixture-v1';
      canonical['access'] = {'owner_user_id': _owner, 'workspace_id': null};
      return ScriptedAdapter.reply(200, canonical);
    }
    if (options.path.endsWith('/original')) {
      if (originalGate case final held?) {
        originalGate = null;
        return held.future;
      }
      return ResponseBody.fromBytes(
        _wav(),
        200,
        headers: {
          Headers.contentTypeHeader: ['audio/wav'],
        },
      );
    }
    if (options.path.endsWith('/documents/transcript.txt')) {
      return ResponseBody.fromBytes(
        utf8.encode('Synthetic transcript'),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    if (options.path == '/auth/login') {
      return ScriptedAdapter.reply(200, {'token': _jwt(_other)});
    }
    if (options.method == 'POST') {
      return ScriptedAdapter.reply(202, {
        'audio_id': _audio,
        'job_id': _job,
        'session_id': '55555555-5555-4555-8555-555555555555',
        'processing_version': 'fixture-v1',
        'status_url': '/meetings/results/$_audio/speech-status',
      });
    }
    throw StateError('Unexpected cleanup fixture request ${options.path}');
  }
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Cleanup operation did not settle');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Transport transport;
  late Dio dio;
  late _Sheet sheet;
  late ProviderContainer container;
  late BatchSession session;
  setUp(() async {
    resetStorageFakes();
    await _storage.saveToken(_jwt(_owner));
    directory = await Directory.systemTemp.createTemp(
      'dictai-account-cleanup-',
    );
    transport = _Transport();
    sheet = _Sheet();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = transport;
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_storage),
        dioProvider.overrideWithValue(dio),
        batchApplicationSupportDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
        resultTemporaryDirectoryProvider.overrideWithValue(
          () async => directory,
        ),
        iosShareSheetProvider.overrideWithValue(sheet),
      ],
    );
    session = await container.read(batchSessionProvider.future);
  });
  tearDown(() async {
    container.dispose();
    dio.close(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    resetStorageFakes();
  });

  test(
    'temporary native policy failure preserves the durable same-key recovery and external source',
    () async {
      const channel = MethodChannel('test.dictai/pending_policy');
      var blocked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (blocked) {
              throw PlatformException(code: 'protected_data_unavailable');
            }
            return {
              'excludedFromBackup': true,
              'protection': 'completeUntilFirstUserAuthentication',
              'protectionVerified': true,
              'environment': 'device',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final store = PendingUploadStore(
        ownerId: _owner,
        isCurrentSession: () => true,
        applicationSupportDirectory: () async => directory,
        filePolicy: const IosFilePolicy(channel: channel, enabled: true),
      );
      final source = File('${directory.path}/external.wav')
        ..writeAsBytesSync(_wav());
      final draft = await store.prepare(
        source: source,
        options: UploadOptions(
          anonymous: true,
          idempotencyKey: 'retained-policy-fixture',
          source: const ImportedWavUploadSource(),
        ),
      );
      blocked = true;
      await expectLater(store.list(), throwsA(isA<ValidationException>()));
      blocked = false;
      final listing = await store.list();
      expect(listing.damagedEntries, 0);
      expect(listing.entries.single.localId, draft.localId);
      expect(
        listing.entries.single.options.idempotencyKey,
        'retained-policy-fixture',
      );
      expect(source.readAsBytesSync(), _wav());
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'recursive per-owner protection is serialized by the journal lock',
    () async {
      const channel = MethodChannel('test.dictai/pending_serial_policy');
      final entered = Completer<void>();
      final release = Completer<void>();
      var ownerCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final path = (call.arguments as Map)['path'] as String;
            if (path.endsWith('/dictai-pending-v1/$_owner')) {
              ownerCalls++;
              if (ownerCalls == 1) {
                entered.complete();
                await release.future;
              }
            }
            return {
              'excludedFromBackup': true,
              'protection': 'completeUntilFirstUserAuthentication',
              'protectionVerified': true,
              'environment': 'device',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      PendingUploadStore store() => PendingUploadStore(
        ownerId: _owner,
        isCurrentSession: () => true,
        applicationSupportDirectory: () async => directory,
        filePolicy: const IosFilePolicy(channel: channel, enabled: true),
      );
      final first = store().list();
      await entered.future;
      final second = store().list();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ownerCalls, 1);
      release.complete();
      expect((await first).entries, isEmpty);
      expect((await second).entries, isEmpty);
      expect(ownerCalls, 2);
    },
  );

  ResultsNotifier library() {
    container.listen(resultsNotifierProvider(session), (_, _) {});
    return container.read(resultsNotifierProvider(session).notifier);
  }

  for (final response in [204, 404]) {
    test(
      'R02 $response revokes detail, notice, cache lease and native share; stale row stays hidden',
      () async {
        transport.deleteStatus = response;
        final results = library();
        final key = (session: session, audioId: _audio, jobId: _job);
        final detailKey = (
          session: session,
          audioId: _audio,
          jobId: _job as String?,
        );
        container.listen(resultDetailNotifierProvider(detailKey), (_, _) {});
        container.listen(resultReadyNoticeProvider(session), (_, _) {});
        container.listen(originalAudioCacheProvider(session), (_, _) {});
        container.listen(iosDocumentExporterProvider(key), (_, _) {});
        await _until(
          () =>
              container
                  .read(resultDetailNotifierProvider(detailKey))
                  .progress
                  ?.canonicalReady ==
              true,
        );
        expect(
          container.read(resultReadyNoticeProvider(session)),
          hasLength(1),
        );
        final cache = container.read(originalAudioCacheProvider(session));
        final lease = await cache.acquire(_audio, _job);
        final exported = container
            .read(iosDocumentExporterProvider(key))
            .share(
              audioId: _audio,
              jobId: _job,
              kind: IosExportKind.transcriptTxt,
              status: container
                  .read(resultDetailNotifierProvider(detailKey))
                  .progress!
                  .status!,
            );
        final sharedFile = await sheet.presented.future;
        final external = File('${directory.path}/user-export.txt')
          ..writeAsStringSync('User-owned export');
        await results.delete(_audio);
        expect(session.jobs.isDeleted((audioId: _audio, jobId: _job)), isTrue);
        expect(
          container.read(resultDetailNotifierProvider(detailKey)).error,
          isA<NotFoundException>(),
        );
        expect(container.read(resultReadyNoticeProvider(session)), isEmpty);
        expect(
          container
              .read(resultsNotifierProvider(session))
              .page
              .asData!
              .value
              .data,
          isEmpty,
        );
        expect(await exported, IosShareOutcome.cancelled);
        expect(sheet.cancellations, 1);
        expect(sharedFile.existsSync(), isFalse);
        expect(
          lease.file.existsSync(),
          isTrue,
          reason: 'Decoder lease has not been released',
        );
        await expectLater(
          cache.acquire(_audio, _job),
          throwsA(isA<NotFoundException>()),
        );
        await lease.release();
        await _until(() => !lease.file.existsSync());
        expect(external.readAsStringSync(), 'User-owned export');
      },
    );
  }

  test(
    'missing pinned version does not revoke a valid sibling cache lease',
    () async {
      container.listen(originalAudioCacheProvider(session), (_, _) {});
      final cache = container.read(originalAudioCacheProvider(session));
      final first = await cache.acquire(_audio, _job);
      session.jobs.markUnavailable((audioId: _audio, jobId: 'missing-version'));
      final second = await cache.acquire(_audio, _job);
      expect(second.file.path, first.file.path);
      expect(first.file.existsSync(), isTrue);
      expect(session.jobs.isDeleted((audioId: _audio, jobId: _job)), isFalse);
      expect(
        transport.requests.where((r) => r.path.endsWith('/original')),
        hasLength(1),
      );
      await first.release();
      await second.release();
      await cache.close();
    },
  );

  test(
    'R02 cancels unresolved latest-job read and rejects its late reply',
    () async {
      final held = Completer<ResponseBody>();
      transport.statusGate = held;
      final key = (session: session, audioId: _audio, jobId: null as String?);
      container.listen(resultDetailNotifierProvider(key), (_, _) {});
      final results = library();
      await _until(
        () => transport.requests.any((r) => r.path.endsWith('/speech-status')),
      );
      final request = transport.requests.firstWhere(
        (r) => r.path.endsWith('/speech-status'),
      );
      await results.delete(_audio);
      expect(request.cancelToken!.isCancelled, isTrue);
      held.complete(ScriptedAdapter.reply(200, transport.status));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(resultDetailNotifierProvider(key)).error,
        isA<NotFoundException>(),
      );
      expect(
        transport.requests.where((r) => r.path.endsWith('/structured')),
        isEmpty,
      );
    },
  );

  test(
    'R02 cancels an original transfer without waiting for its late body',
    () async {
      final held = Completer<ResponseBody>();
      transport.originalGate = held;
      final results = library();
      container.listen(originalAudioCacheProvider(session), (_, _) {});
      final cache = container.read(originalAudioCacheProvider(session));
      final loading = expectLater(
        cache.acquire(_audio, _job),
        throwsA(isA<AppException>()),
      );
      await _until(
        () => transport.requests.any((r) => r.path.endsWith('/original')),
      );
      final request = transport.requests.firstWhere(
        (r) => r.path.endsWith('/original'),
      );
      await results.delete(_audio);
      expect(request.cancelToken!.isCancelled, isTrue);
      held.complete(
        ResponseBody.fromBytes(
          _wav(),
          200,
          headers: {
            Headers.contentTypeHeader: ['audio/wav'],
          },
        ),
      );
      await loading;
      await cache.close();
      expect(
        directory.listSync().where((f) => f.path.contains('dictai-original-')),
        isEmpty,
      );
    },
  );

  test(
    'R02 prunes accepted receipts and leaves an unrelated pending same-key recovery intact',
    () async {
      final external = File('${directory.path}/user-original.wav')
        ..writeAsBytesSync(_wav());
      final accepted = await session.uploads.prepare(
        source: external,
        options: UploadOptions(
          anonymous: true,
          idempotencyKey: 'accepted-fixture',
          source: const ImportedWavUploadSource(),
        ),
      );
      await session.submit(accepted.localId);
      final pending = await session.uploads.prepare(
        source: external,
        options: UploadOptions(
          anonymous: true,
          idempotencyKey: 'unknown-outcome-fixture',
          source: const ImportedWavUploadSource(),
        ),
      );
      final results = library();
      await results.delete(_audio);
      final listing = await session.uploads.list();
      expect(listing.entries.map((e) => e.localId), [pending.localId]);
      expect(listing.entries.single.state, PendingUploadState.pending);
      expect(
        listing.entries.single.options.idempotencyKey,
        'unknown-outcome-fixture',
      );
      expect(external.readAsBytesSync(), _wav());
    },
  );

  test(
    'logout and account B cannot read or submit account A pending journal',
    () async {
      final source = File('${directory.path}/user-source.wav')
        ..writeAsBytesSync(_wav());
      final pending = await session.uploads.prepare(
        source: source,
        options: UploadOptions(
          anonymous: true,
          idempotencyKey: 'owner-a-fixture',
          source: const ImportedWavUploadSource(),
        ),
      );
      await container.read(authNotifierProvider.notifier).logout();
      expect(session.isCurrent, isFalse);
      await expectLater(
        session.uploads.list(),
        throwsA(isA<UnauthorizedException>()),
      );
      await container
          .read(authNotifierProvider.notifier)
          .login(
            email: 'b@fixture.invalid',
            password: 'synthetic-fixture',
            onSuccess: () {},
          );
      final other = await container.read(batchSessionProvider.future);
      expect(other.ownerId, _other);
      expect((await other.uploads.list()).entries, isEmpty);
      await expectLater(
        other.submit(pending.localId),
        throwsA(isA<ValidationException>()),
      );
      final retained = await PendingUploadStore(
        ownerId: _owner,
        isCurrentSession: () => true,
        applicationSupportDirectory: () async => directory,
      ).list();
      expect(retained.entries.single.options.idempotencyKey, 'owner-a-fixture');
      expect(
        transport.requests.where(
          (r) => r.method == 'POST' && r.path.startsWith('/ingest/'),
        ),
        isEmpty,
      );
      expect(source.existsSync(), isTrue);
    },
  );
}
