import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/record/data/dto/v2_session_dto.dart';
import 'package:dict_ai/features/results/data/dto/speech_status_dto.dart';
import 'package:dict_ai/features/results/data/speech_status_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Map<String, dynamic> speechStatus({
  String job = 'running',
  String transcript = 'pending',
  String summary = 'pending',
}) => {
  'job_id': 'job-fixture',
  'processing_version': 'processing-fixture-v1',
  'workspace_id': null,
  'job_status': job,
  'transcript_status': transcript,
  'summary_status': summary,
  'summary_error': null,
};

Map<String, dynamic> session({String state = 'queued'}) => {
  'session_id': 'session-fixture',
  'audio_id': 'audio-fixture',
  'job_id': 'job-fixture',
  'processing_version': 'processing-fixture-v1',
  'status': state,
  'status_url': '/meetings/results/audio-fixture/speech-status',
  'confirm_required': false,
};

void main() {
  late ScriptedAdapter adapter;
  late Dio dio;
  late SpeechStatusApi api;
  setUp(() {
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    api = SpeechStatusApi(dio);
  });
  tearDown(() => dio.close(force: true));

  test('R03 pins exact job; latest request has no query or history', () async {
    adapter
      ..enqueue(200, speechStatus())
      ..enqueue(200, speechStatus());
    final status = await api.getSpeechStatus(
      'audio-fixture',
      jobId: 'job-fixture',
    );
    expect(status.jobId, 'job-fixture');
    expect(status.processingVersion, 'processing-fixture-v1');
    expect(status.workspaceId, isNull);
    expect(status.summaryError, isNull);
    await api.getSpeechStatus('audio-fixture');
    expect(adapter.requests.map((r) => r.path), [
      '/meetings/results/audio-fixture/speech-status',
      '/meetings/results/audio-fixture/speech-status',
    ]);
    expect(adapter.requests.first.queryParameters, {'job_id': 'job-fixture'});
    expect(adapter.requests.last.queryParameters, isEmpty);
    expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('all job/transcript/summary states remain independent', () {
    for (final job in SpeechJobStatus.values.where(
      (s) => s != SpeechJobStatus.unknown,
    )) {
      for (final transcript in TranscriptStatus.values.where(
        (s) => s != TranscriptStatus.unknown,
      )) {
        for (final summary in SummaryStatus.values.where(
          (s) => s != SummaryStatus.unknown,
        )) {
          final dto = SpeechStatusDto.fromJson(
            speechStatus(
              job: job.name,
              transcript: transcript.name,
              summary: summary.name,
            ),
          );
          expect(dto.jobStatus, job);
          expect(dto.transcriptStatus, transcript);
          expect(dto.summaryStatus, summary);
          expect(dto.hasUnknownStatus, isFalse);
        }
      }
    }
    expect(
      SpeechStatusDto.fromJson(
        speechStatus(job: 'completed'),
      ).shouldPollTranscript,
      isTrue,
    );
    final ready = SpeechStatusDto.fromJson(
      speechStatus(job: 'completed', transcript: 'ready', summary: 'failed'),
    );
    expect(ready.transcriptStatus, TranscriptStatus.ready);
    expect(ready.summaryStatus, SummaryStatus.failed);
    expect(ready.shouldPollTranscript, isFalse);
    for (final terminal in ['failed', 'cancelled']) {
      final dto = SpeechStatusDto.fromJson(
        speechStatus(job: terminal, transcript: terminal),
      );
      expect(dto.isTerminalFailure, isTrue);
      expect(dto.shouldPollTranscript, isFalse);
      expect(dto.summaryStatus, SummaryStatus.pending);
    }
  });

  test('unknown states are diagnostic; summary_error stays an open code', () {
    final dto = SpeechStatusDto.fromJson({
      ...speechStatus(
        job: 'future-job',
        transcript: 'future-transcript',
        summary: 'future-summary',
      ),
      'workspace_id': 'workspace-fixture',
      'summary_error': 'model_specific_failure',
      'progress': 100,
    });
    expect(dto.jobStatus, SpeechJobStatus.unknown);
    expect(dto.transcriptStatus, TranscriptStatus.unknown);
    expect(dto.summaryStatus, SummaryStatus.unknown);
    expect(dto.rawJobStatus, 'future-job');
    expect(dto.rawTranscriptStatus, 'future-transcript');
    expect(dto.rawSummaryStatus, 'future-summary');
    expect(dto.hasUnknownStatus, isTrue);
    expect(dto.shouldPollTranscript, isFalse);
    expect(dto.summaryError, 'model_specific_failure');
    expect(dto.workspaceId, 'workspace-fixture');
  });

  test('unknown summary does not gate a known pending transcript', () {
    final dto = SpeechStatusDto.fromJson(
      speechStatus(summary: 'future-summary'),
    );
    expect(dto.hasUnknownStatus, isTrue);
    expect(dto.summaryStatus, SummaryStatus.unknown);
    expect(dto.transcriptStatus, TranscriptStatus.pending);
    expect(dto.shouldPollTranscript, isTrue);
  });

  test('U03 uses V2 path and all six states without confirmation', () async {
    for (final state in V2SessionStatus.values.where(
      (s) => s != V2SessionStatus.unknown,
    )) {
      adapter.enqueue(200, session(state: state.name));
      final dto = await api.getAnonymousSession('session-fixture');
      expect(dto.status, state);
      expect(dto.sessionId, 'session-fixture');
      expect(dto.audioId, 'audio-fixture');
      expect(dto.jobId, 'job-fixture');
      expect(dto.processingVersion, 'processing-fixture-v1');
      expect(dto.statusUrl, '/meetings/results/audio-fixture/speech-status');
      expect(dto.confirmRequired, isFalse);
      expect(
        dto.shouldPoll,
        state == V2SessionStatus.queued || state == V2SessionStatus.running,
      );
    }
    expect(
      adapter.requests.every(
        (r) =>
            r.path == '/ingest/v2/audio/anonymous/session-fixture' &&
            r.queryParameters.isEmpty,
      ),
      isTrue,
    );
    final unknown = V2SessionDto.fromJson(session(state: 'future-state'));
    expect(unknown.status, V2SessionStatus.unknown);
    expect(unknown.rawStatus, 'future-state');
    expect(unknown.shouldPoll, isFalse);
  });

  test(
    'missing fields, malformed responses and mismatched jobs fail safely',
    () async {
      final bodies = <Object?>[
        null,
        'not JSON',
        [],
        {},
        {...speechStatus(), 'job_id': 'different-job'},
      ];
      for (final field in speechStatus().keys) {
        bodies.add({...speechStatus()}..remove(field));
      }
      bodies.addAll([
        {...speechStatus(), 'summary_error': 4},
        {...speechStatus(), 'workspace_id': []},
        {...speechStatus(), 'job_status': null},
      ]);
      for (final body in bodies) {
        adapter.enqueue(200, body);
        await expectLater(
          api.getSpeechStatus('audio-fixture', jobId: 'job-fixture'),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
      adapter.enqueue(202, speechStatus());
      await expectLater(
        api.getSpeechStatus('audio-fixture'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test(
    'session rejects missing keys, confirmation and mismatched identity',
    () async {
      final bodies = [
        {...session(), 'confirm_required': true},
        {...session(), 'session_id': 'different-session'},
        {...session(), 'audio_id': null},
        for (final field in session().keys) ({...session()}..remove(field)),
      ];
      for (final body in bodies) {
        adapter.enqueue(200, body);
        await expectLater(
          api.getAnonymousSession('session-fixture'),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      }
    },
  );

  for (final entry in {
    401: ApiFailureKind.unauthorized,
    403: ApiFailureKind.forbidden,
    404: ApiFailureKind.notFound,
    503: ApiFailureKind.serviceUnavailable,
  }.entries) {
    test(
      'HTTP ${entry.key} preserves shared error meaning with no retry',
      () async {
        for (final request in [
          () => api.getSpeechStatus('audio-fixture'),
          () => api.getAnonymousSession('session-fixture'),
        ]) {
          adapter.enqueue(
            entry.key,
            '<html>private-fixture</html>',
            contentType: 'text/html',
          );
          await expectLater(
            request(),
            throwsA(
              isA<ApiFailure>()
                  .having((e) => e.kind, 'kind', entry.value)
                  .having(
                    (e) => e.message,
                    'safe message',
                    isNot(contains('private-fixture')),
                  ),
            ),
          );
        }
        expect(adapter.requests, hasLength(2));
      },
    );
  }

  test(
    'transport and local auth storage failures retain shared behavior',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
              ),
            );
          },
        ),
      );
      await expectLater(
        api.getSpeechStatus('audio-fixture'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.timeout,
          ),
        ),
      );
      dio.interceptors.clear();
      const local = ServerException('Local secure storage unavailable');
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(DioException(requestOptions: options, error: local));
          },
        ),
      );
      await expectLater(
        api.getAnonymousSession('session-fixture'),
        throwsA(same(local)),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'route IDs are encoded and empty pinned IDs never select latest',
    () async {
      adapter.enqueue(200, speechStatus());
      await api.getSpeechStatus('audio/structured?other=1');
      expect(
        adapter.requests.single.path,
        '/meetings/results/audio%2Fstructured%3Fother%3D1/speech-status',
      );
      for (final invalid in ['', ' ', ' job-fixture']) {
        expect(
          () => api.getSpeechStatus('audio-fixture', jobId: invalid),
          throwsA(isA<ValidationException>()),
        );
      }
      expect(adapter.requests, hasLength(1));
    },
  );
}
