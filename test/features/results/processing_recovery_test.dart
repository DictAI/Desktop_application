import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/core/network/api_client.dart';
import 'package:dict_ai/core/storage/secure_storage.dart';
import 'package:dict_ai/features/record/data/pending_upload_store.dart';
import 'package:dict_ai/features/record/data/v2_upload_api.dart';
import 'package:dict_ai/features/results/data/canonical_api.dart';
import 'package:dict_ai/features/results/data/dto/result_dto.dart';
import 'package:dict_ai/features/results/data/dto/speech_status_dto.dart';
import 'package:dict_ai/features/results/data/pending_job_store.dart';
import 'package:dict_ai/features/results/data/speech_status_api.dart';
import 'package:dict_ai/features/results/presentation/processing_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const audio = '22222222-2222-4222-8222-222222222222';
const jobId = '33333333-3333-4333-8333-333333333333';
const sessionId = '44444444-4444-4444-8444-444444444444';
const job = ProcessingJob(
  ownerId: owner,
  audioId: audio,
  jobId: jobId,
  processingVersion: 'fixture-v1',
);
const key = (audioId: audio, jobId: jobId);

Map<String, dynamic> status({
  String job = 'running',
  String transcript = 'pending',
  String summary = 'pending',
  String version = 'fixture-v1',
}) => {
  'job_id': jobId,
  'processing_version': version,
  'workspace_id': null,
  'job_status': job,
  'transcript_status': transcript,
  'summary_status': summary,
  'summary_error': null,
};
Map<String, dynamic> anon(String state) => {
  'session_id': sessionId,
  'audio_id': audio,
  'job_id': jobId,
  'processing_version': 'fixture-v1',
  'status': state,
  'status_url': '/meetings/results/$audio/speech-status',
  'confirm_required': false,
};
Map<String, dynamic> acceptance() => {
  'audio_id': audio,
  'job_id': jobId,
  'session_id': null,
  'processing_version': 'fixture-v1',
  'status_url': '/meetings/results/$audio/speech-status',
};
Map<String, dynamic> canonical({String state = 'speech'}) {
  final data =
      (jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
              as Map)[state]
          as Map<String, dynamic>;
  data['recording_id'] = audio;
  data['job_id'] = jobId;
  data['processing_version'] = 'fixture-v1';
  (data['access'] as Map)['owner_user_id'] = owner;
  return data;
}

Uint8List wav() {
  final b = Uint8List(48);
  final d = ByteData.sublistView(b);
  void text(int at, String s) => b.setRange(at, at + s.length, s.codeUnits);
  text(0, 'RIFF');
  text(8, 'WAVE');
  text(12, 'fmt ');
  text(36, 'data');
  d.setUint32(4, 40, Endian.little);
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, 1, Endian.little);
  d.setUint32(24, 16000, Endian.little);
  d.setUint32(28, 32000, Endian.little);
  d.setUint16(32, 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  d.setUint32(40, 4, Endian.little);
  return b;
}

Future<void> until(
  ProcessingNotifier tracker,
  bool Function(Map<ProcessingKey, JobProgress>) done,
) async {
  if (done(tracker.state)) return;
  final complete = Completer<void>();
  final remove = tracker.addListener((state) {
    if (done(state) && !complete.isCompleted) complete.complete();
  }, fireImmediately: false);
  try {
    await complete.future.timeout(const Duration(seconds: 5));
  } finally {
    remove();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late ScriptedAdapter adapter;
  late Dio dio;
  late PendingUploadStore uploads;
  late PendingJobStore store;
  late ProcessingNotifier tracker;
  bool current = true;
  setUp(() async {
    resetStorageFakes();
    temp = await Directory.systemTemp.createTemp('dictai-processing-test-');
    current = true;
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    uploads = PendingUploadStore(
      ownerId: owner,
      isCurrentSession: () => current,
      applicationSupportDirectory: () async => temp,
    );
    store = PendingJobStore(uploads: uploads, isCurrentSession: () => current);
    tracker = ProcessingNotifier(
      store: store,
      statusApi: SpeechStatusApi(dio),
      canonicalApi: CanonicalApi(dio),
      isCurrentSession: () => current,
    );
  });
  tearDown(() async {
    tracker.dispose();
    dio.close(force: true);
    await temp.delete(recursive: true);
  });

  test(
    'canonical readiness is independent from pending/failed summary and never navigates',
    () async {
      adapter
        ..enqueue(200, status(job: 'completed', transcript: 'ready'))
        ..enqueue(200, canonical());
      tracker.track(job);
      await until(tracker, (s) => s[key]?.canonicalReady == true);
      expect(tracker.state[key]!.phase, ProcessingPhase.ready);
      expect(tracker.state[key]!.status!.summaryStatus, SummaryStatus.pending);
      expect(tracker.state[key]!.retryIn, const Duration(seconds: 3));
      adapter.enqueue(
        200,
        status(job: 'completed', transcript: 'ready', summary: 'failed'),
      );
      await tracker.refresh(key);
      expect(tracker.state[key]!.canonicalReady, isTrue);
      expect(tracker.state[key]!.retryIn, isNull);
      expect(adapter.requests, hasLength(3));
      expect(
        adapter.requests.every((r) => r.queryParameters['job_id'] == jobId),
        isTrue,
      );
    },
  );

  test('202 is not canonical ready; later valid no_speech is ready', () async {
    adapter
      ..enqueue(200, status(transcript: 'ready'))
      ..enqueue(202, status());
    tracker.track(job);
    await until(tracker, (s) => s[key]?.status != null);
    expect(tracker.state[key]!.canonicalReady, isFalse);
    expect(
      tracker.state[key]!.status!.transcriptStatus,
      TranscriptStatus.pending,
    );
    adapter
      ..enqueue(
        200,
        status(job: 'completed', transcript: 'ready', summary: 'ready'),
      )
      ..enqueue(200, canonical(state: 'no_speech'));
    await tracker.refresh(key);
    expect(tracker.state[key]!.canonical!.speakers, isEmpty);
    expect(tracker.state[key]!.phase, ProcessingPhase.ready);
    expect(tracker.state[key]!.retryIn, isNull);
  });

  for (final terminal in ['failed', 'cancelled']) {
    test('$terminal ends transcript polling without canonical GET', () async {
      adapter.enqueue(200, status(job: terminal, transcript: terminal));
      tracker.track(job);
      await until(tracker, (s) => s[key]?.status != null);
      expect(
        tracker.state[key]!.phase,
        terminal == 'failed'
            ? ProcessingPhase.failed
            : ProcessingPhase.cancelled,
      );
      expect(tracker.state[key]!.retryIn, isNull);
      expect(adapter.requests, hasLength(1));
    });
  }

  for (final terminal in ['failed', 'cancelled', 'expired', 'future']) {
    test(
      'anonymous $terminal ends waiting without confirmation or structured',
      () async {
        adapter
          ..enqueue(200, status())
          ..enqueue(200, anon(terminal));
        tracker.track(
          const ProcessingJob(
            ownerId: owner,
            audioId: audio,
            jobId: jobId,
            processingVersion: 'fixture-v1',
            sessionId: sessionId,
          ),
        );
        await until(tracker, (s) => s[key]?.phase != ProcessingPhase.waiting);
        expect(tracker.state[key]!.canonicalReady, isFalse);
        expect(tracker.state[key]!.retryIn, isNull);
        expect(adapter.requests.map((r) => r.path), [
          '/meetings/results/$audio/speech-status',
          '/ingest/v2/audio/anonymous/$sessionId',
        ]);
      },
    );
  }

  test('anonymous ready still obtains canonical through R03/R04', () async {
    adapter
      ..enqueue(200, status(transcript: 'ready', summary: 'ready'))
      ..enqueue(200, canonical());
    tracker.track(
      const ProcessingJob(
        ownerId: owner,
        audioId: audio,
        jobId: jobId,
        processingVersion: 'fixture-v1',
        sessionId: sessionId,
      ),
    );
    await until(tracker, (s) => s[key]?.canonicalReady == true);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
  });

  test(
    'U03 ready does not turn a pending transcript into canonical readiness',
    () async {
      adapter
        ..enqueue(200, status())
        ..enqueue(200, anon('ready'));
      tracker.track(
        const ProcessingJob(
          ownerId: owner,
          audioId: audio,
          jobId: jobId,
          processingVersion: 'fixture-v1',
          sessionId: sessionId,
        ),
      );
      await until(tracker, (s) => s[key]?.status != null);
      expect(tracker.state[key]!.canonicalReady, isFalse);
      expect(tracker.state[key]!.retryIn, const Duration(seconds: 3));
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'recovered anonymous receipt cannot gate readable canonical on session TTL',
    () async {
      final source = await File(
        '${temp.path}/anonymous.wav',
      ).writeAsBytes(wav());
      final draft = await uploads.prepare(
        source: source,
        options: UploadOptions(
          anonymous: true,
          idempotencyKey: 'anonymous-recovery',
          source: const ImportedWavUploadSource(),
        ),
      );
      adapter.enqueue(202, {...acceptance(), 'session_id': sessionId});
      await uploads.submit(
        draft.localId,
        api: V2UploadApi(dio),
        cancelToken: CancelToken(),
      );
      final restarted = PendingJobStore(
        uploads: PendingUploadStore(
          ownerId: owner,
          isCurrentSession: () => current,
          applicationSupportDirectory: () async => temp,
        ),
        isCurrentSession: () => current,
      );
      final recovered = await restarted.recover(
        results: const [
          ResultDto(
            resultId: jobId,
            audioId: audio,
            workspaceId: '',
            uploadUserId: owner,
            summaryUrl: '',
            transcriptUrl: '',
            status: 'done',
          ),
        ],
      );
      expect(recovered.single.sessionId, sessionId);
      adapter
        ..enqueue(
          200,
          status(job: 'completed', transcript: 'ready', summary: 'ready'),
        )
        ..enqueue(200, canonical());
      tracker.track(recovered.single);
      await until(tracker, (s) => s[key]?.canonicalReady == true);
      expect(
        adapter.requests.where((r) => r.path.contains('/anonymous/')),
        isEmpty,
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  test(
    'one in-flight poll per job; logout cancels request and rejects late success',
    () async {
      final deferred = adapter.defer();
      tracker.track(job);
      await adapter.firstRequest.future;
      await Future.wait([tracker.refresh(key), tracker.refresh(key)]);
      expect(adapter.requests, hasLength(1));
      final token = adapter.requests.single.cancelToken!;
      tracker.stopSession();
      current = false;
      expect(token.isCancelled, isTrue);
      deferred.complete(
        ScriptedAdapter.reply(200, status(transcript: 'ready')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tracker.state, isEmpty);
      expect(adapter.requests, hasLength(1));
    },
  );

  for (final code in [429, 502, 503]) {
    test(
      '$code read error has bounded backoff and explicit read retry',
      () async {
        adapter.enqueue(code, {'error': 'private technical detail'});
        tracker.track(job);
        await until(tracker, (s) => s[key]?.error != null);
        expect(tracker.state[key]!.retryIn, const Duration(seconds: 6));
        expect(tracker.state[key]!.error!.message, isNot(contains('private')));
        for (var i = 0; i < 8; i++) {
          adapter.enqueue(code, {'error': 'unavailable'});
          await tracker.refresh(key);
        }
        expect(tracker.state[key]!.retryIn, const Duration(seconds: 60));
        expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
      },
    );
  }

  test('artifact503 is retryable but never canonical readiness', () async {
    adapter
      ..enqueue(200, status(transcript: 'ready'))
      ..enqueue(503, {'error': 'artifact unavailable'});
    tracker.track(job);
    await until(tracker, (s) => s[key]?.error != null);
    expect(tracker.state[key]!.canonicalReady, isFalse);
    expect(tracker.state[key]!.retryIn, const Duration(seconds: 6));
  });

  test('401 has no retry; actual session invalidation clears jobs', () async {
    adapter.enqueue(401, {'error': 'authentication required'});
    tracker.track(job);
    await adapter.firstRequest.future;
    await until(tracker, (s) => s[key]?.error != null);
    expect(tracker.state[key]!.retryIn, isNull);
    tracker.stopSession();
    tracker.track(job);
    expect(tracker.state, isEmpty);
    expect(adapter.requests, hasLength(1));
  });

  test(
    'late old-credential 401 preserves renewed session and permits a new GET',
    () async {
      String token(int expiry) {
        String part(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        return '${part({'alg': 'HS256'})}.${part({'iss': 'dictai-auth-v2', 'aud': 'dictai-user', 'user_id': owner, 'exp': expiry})}.fixture';
      }

      const storage = SecureStorage();
      final expiry =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
      final original = token(expiry), renewed = token(expiry + 3600);
      await storage.saveToken(original);
      final credential = (await storage.readCredential())!;
      var invalidations = 0;
      dio.close(force: true);
      adapter = ScriptedAdapter();
      dio = createDio(
        baseUrl: 'https://fixture.invalid',
        storage: storage,
        onUnauthorized: () async {
          invalidations++;
          current = false;
          tracker.stopSession();
        },
      )..httpClientAdapter = adapter;
      tracker.dispose();
      tracker = ProcessingNotifier(
        store: store,
        statusApi: SpeechStatusApi(dio),
        canonicalApi: CanonicalApi(dio),
        isCurrentSession: () => current,
      );
      final oldReply = adapter.defer();
      tracker.track(job);
      await adapter.firstRequest.future;
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer $original',
      );
      expect(
        await storage.replaceCredentialIfCurrent(credential, renewed),
        isTrue,
      );
      oldReply.complete(
        ScriptedAdapter.reply(401, {'error': 'authentication required'}),
      );
      await until(tracker, (s) => s[key]?.error != null);
      expect(await storage.getToken(), renewed);
      expect(invalidations, 0);
      expect(tracker.state[key]!.retryIn, isNull);
      adapter.enqueue(200, status(job: 'failed', transcript: 'failed'));
      await tracker.refresh(key);
      expect(tracker.state[key]!.phase, ProcessingPhase.failed);
      expect(adapter.requests.last.headers['Authorization'], 'Bearer $renewed');
      expect(adapter.requests.map((r) => r.method), ['GET', 'GET']);
    },
  );

  test(
    'foreign owner, version mismatch and unknown state never become ready',
    () async {
      tracker.track(
        const ProcessingJob(ownerId: 'other', audioId: audio, jobId: jobId),
      );
      expect(tracker.state, isEmpty);
      adapter.enqueue(200, status(version: 'other-version'));
      tracker.track(job);
      await until(tracker, (s) => s[key]?.error != null);
      expect(tracker.state[key]!.retryIn, isNull);
      adapter.enqueue(200, status(job: 'future'));
      await tracker.refresh(key);
      expect(tracker.state[key]!.phase, ProcessingPhase.unsupported);
      expect(tracker.state[key]!.retryIn, isNull);
    },
  );

  test(
    'R01 and durable 202 recover same job after restart without another POST',
    () async {
      final source = await File('${temp.path}/fixture.wav').writeAsBytes(wav());
      final draft = await uploads.prepare(
        source: source,
        options: UploadOptions(
          anonymous: false,
          workspaceId: sessionId,
          idempotencyKey: 'fixture-recovery',
          source: const ImportedWavUploadSource(),
        ),
      );
      adapter.enqueue(202, acceptance());
      await uploads.submit(
        draft.localId,
        api: V2UploadApi(dio),
        cancelToken: CancelToken(),
      );
      final restarted = PendingJobStore(
        uploads: PendingUploadStore(
          ownerId: owner,
          isCurrentSession: () => current,
          applicationSupportDirectory: () async => temp,
        ),
        isCurrentSession: () => current,
      );
      const results = [
        ResultDto(
          resultId: jobId,
          audioId: audio,
          workspaceId: '',
          uploadUserId: owner,
          summaryUrl: '',
          transcriptUrl: '',
        ),
      ];
      final recovered = await restarted.recover(results: results);
      expect(recovered, hasLength(1));
      expect(recovered.single.processingVersion, 'fixture-v1');
      expect(adapter.requests, hasLength(1));
      await restarted.forgetAudio(audio);
      expect(await restarted.recover(results: results), isEmpty);
      expect((await uploads.list()).entries, isEmpty);
    },
  );

  test(
    'deleted result cancels in-flight work and cannot be resurrected by stale page',
    () async {
      final deferred = adapter.defer();
      tracker.track(job);
      await adapter.firstRequest.future;
      tracker.removeAudio(audio);
      deferred.complete(
        ScriptedAdapter.reply(200, status(transcript: 'ready')),
      );
      await Future<void>.delayed(Duration.zero);
      tracker.track(job);
      expect(tracker.state, isEmpty);
      expect(adapter.requests, hasLength(1));
    },
  );

  test('automatic polling schedules the next read after completion', () async {
    tracker.dispose();
    tracker = ProcessingNotifier(
      store: store,
      statusApi: SpeechStatusApi(dio),
      canonicalApi: CanonicalApi(dio),
      isCurrentSession: () => current,
      pollInterval: const Duration(milliseconds: 20),
    );
    adapter
      ..enqueue(200, status())
      ..enqueue(200, status(transcript: 'ready', summary: 'ready'))
      ..enqueue(200, canonical());
    tracker.track(job);
    await until(tracker, (s) => s[key]?.canonicalReady == true);
    expect(adapter.requests, hasLength(3));
    expect(tracker.state[key]!.retryIn, isNull);
  });

  test('concurrent job limit bounds HTTP reads across recordings', () async {
    tracker.dispose();
    tracker = ProcessingNotifier(
      store: store,
      statusApi: SpeechStatusApi(dio),
      canonicalApi: CanonicalApi(dio),
      isCurrentSession: () => current,
      maxConcurrent: 1,
    );
    final pending = adapter.defer();
    tracker.track(job);
    await adapter.firstRequest.future;
    tracker.track(
      const ProcessingJob(
        ownerId: owner,
        audioId: 'another-audio',
        jobId: 'another-job',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(adapter.requests, hasLength(1));
    expect(tracker.state, hasLength(2));
    tracker.stopSession();
    pending.complete(ScriptedAdapter.reply(200, status()));
  });

  test(
    'Riverpod disposal cancels in-flight read without late publication',
    () async {
      final pending = adapter.defer();
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      final provider = processingNotifierProvider(
        ProcessingSession(store: store, isCurrentSession: () => current),
      );
      container.listen(provider, (_, _) {});
      container.read(provider.notifier).track(job);
      await adapter.firstRequest.future;
      final token = adapter.requests.single.cancelToken!;
      container.dispose();
      expect(token.isCancelled, isTrue);
      pending.complete(ScriptedAdapter.reply(200, status(transcript: 'ready')));
      await Future<void>.delayed(Duration.zero);
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    '404 stops automatic waiting and does not erase durable receipts',
    () async {
      adapter.enqueue(404, {'error': 'result unavailable'});
      tracker.track(job);
      await until(tracker, (s) => s[key]?.error != null);
      expect(tracker.state[key]!.phase, ProcessingPhase.unavailable);
      expect(tracker.state[key]!.retryIn, isNull);
      expect(tracker.state[key]!.canonicalReady, isFalse);
    },
  );

  for (final code in [403, 404, 503]) {
    test(
      'HTTP $code after readiness updates access without deleting receipt',
      () async {
        adapter
          ..enqueue(200, status(transcript: 'ready'))
          ..enqueue(200, canonical());
        tracker.track(job);
        await until(tracker, (s) => s[key]?.canonicalReady == true);
        adapter.enqueue(code, {'error': 'result unavailable'});
        await tracker.refresh(key);
        final result = tracker.state[key]!;
        if (code == 503) {
          expect(result.phase, ProcessingPhase.ready);
          expect(result.canonicalReady, isTrue);
          expect(result.retryIn, const Duration(seconds: 6));
        } else {
          expect(result.phase, ProcessingPhase.unavailable);
          expect(result.canonical, isNull);
          expect(result.status, isNull);
          expect(result.retryIn, isNull);
        }
        expect(store.isDeleted(key), isFalse);
        expect(adapter.requests, hasLength(3));
      },
    );
  }

  test(
    'foreign canonical owner is rejected even when status IDs match',
    () async {
      final foreign = canonical();
      (foreign['access'] as Map)['owner_user_id'] = 'another-owner';
      adapter
        ..enqueue(200, status(transcript: 'ready'))
        ..enqueue(200, foreign);
      tracker.track(job);
      await until(tracker, (s) => s[key]?.error != null);
      expect(tracker.state[key]!.canonicalReady, isFalse);
      expect(tracker.state[key]!.retryIn, isNull);
    },
  );
}
