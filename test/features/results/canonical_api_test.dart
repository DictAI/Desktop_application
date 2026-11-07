import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/results/data/canonical_api.dart';
import 'package:dict_ai/features/results/data/dto/canonical_transcript_dto.dart';
import 'package:dict_ai/features/results/data/dto/speech_status_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

final _fixtureJson = File('test/fixtures/canonical_v1.json').readAsStringSync();
Map<String, dynamic> fixture({bool noSpeech = false}) =>
    (jsonDecode(_fixtureJson) as Map<String, dynamic>)[noSpeech
            ? 'no_speech'
            : 'speech']
        as Map<String, dynamic>;
Map<String, dynamic> segment(Map<String, dynamic> json, [int index = 0]) =>
    (json['segments'] as List)[index] as Map<String, dynamic>;
Map<String, dynamic> word(Map<String, dynamic> json, [int index = 0]) =>
    (segment(json)['words'] as List)[index] as Map<String, dynamic>;
Map<String, dynamic> status({
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

void main() {
  late ScriptedAdapter adapter;
  late Dio dio;
  late CanonicalApi api;
  setUp(() {
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    api = CanonicalApi(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    '200 canonical preserves every wire field, overlap, UNKNOWN and nulls',
    () async {
      adapter.enqueue(200, fixture());
      final ready =
          await api.getTranscript('audio-fixture', jobId: 'job-fixture')
              as CanonicalReady;
      final dto = ready.transcript;
      expect(dto.schemaVersion, 'dictai-transcript/v1');
      expect(dto.recordingId, 'audio-fixture');
      expect(dto.jobId, 'job-fixture');
      expect(dto.processingVersion, 'processing-fixture-v1');
      expect(dto.access.ownerUserId, 'owner-fixture');
      expect(dto.access.workspaceId, isNull);
      expect(dto.durationUs, 5000000);
      expect(dto.speechState, CanonicalSpeechState.speech);
      expect(dto.language, 'mul');
      expect(dto.engines.single.role, CanonicalEngineRole.combined);
      expect(dto.engines.single.name, 'synthetic-engine');
      expect(dto.engines.single.model, 'synthetic-fixture');
      expect(dto.engines.single.revision, 'fixture-revision-v1');
      expect(dto.speakers.map((s) => s.speakerId), ['speaker_1', 'speaker_2']);
      expect(dto.speakers.map((s) => s.label), ['Speaker 1', 'Speaker 2']);
      expect(dto.segments[0].startUs, 0);
      expect(dto.segments[0].endUs, 2000000);
      expect(dto.segments[0].text, 'Первая реплика.');
      expect(dto.segments[0].confidence, isNull);
      expect(dto.segments[0].language, 'ru');
      expect(dto.segments[0].wordTiming, CanonicalWordTiming.available);
      expect(dto.segments[0].words.first.startUs, 0);
      expect(dto.segments[0].words.first.endUs, 1000000);
      expect(dto.segments[0].words.first.text, 'Первая');
      expect(dto.segments[0].words.first.confidence, 0.0);
      expect(dto.segments[0].words.first.language, 'ru');
      expect(dto.segments[1].startUs, lessThan(dto.segments[0].endUs));
      expect(dto.segments[1].speakerId, 'speaker_2');
      expect(dto.segments[1].wordTiming, CanonicalWordTiming.unavailable);
      expect(dto.segments[1].words, isEmpty);
      expect(dto.segments[2].speakerId, 'UNKNOWN');
      expect(dto.segments[2].confidence, isNull);
      expect(dto.segments[2].language, isNull);
      expect(
        adapter.requests.single.path,
        '/meetings/results/audio-fixture/structured',
      );
      expect(adapter.requests.single.queryParameters, {
        'job_id': 'job-fixture',
      });
      expect(adapter.requests.single.method, 'GET');
    },
  );

  test(
    'no_speech is successful canonical, not a failed or fabricated result',
    () async {
      adapter.enqueue(200, fixture(noSpeech: true));
      final dto = (await api.getTranscript('audio-fixture') as CanonicalReady)
          .transcript;
      expect(dto.speechState, CanonicalSpeechState.noSpeech);
      expect(dto.speakers, isEmpty);
      expect(dto.segments, isEmpty);
      expect(dto.language, isNull);
      expect(adapter.requests.single.queryParameters, isEmpty);
    },
  );

  test(
    'unknown-only transcript has no invented speaker and keeps original text',
    () {
      final json = fixture();
      json['speakers'] = [];
      json['segments'] = [segment(json, 2)];
      final dto = CanonicalTranscriptDto.fromJson(json);
      expect(dto.speakers, isEmpty);
      expect(dto.segments.single.speakerId, 'UNKNOWN');
      expect(dto.segments.single.text, 'Неизвестный голос.');
    },
  );

  test(
    'separate engines, workspace ID and JSON-exact upper bound stay valid',
    () {
      final json = fixture();
      json['duration_us'] = CanonicalTranscriptDto.maxTimeUs;
      json['access']['workspace_id'] = 'workspace-fixture';
      json['engines'] = [
        {
          'role': 'asr',
          'name': 'synthetic-asr',
          'model': 'asr-fixture',
          'revision': 'asr-v1',
        },
        {
          'role': 'diarization',
          'name': 'synthetic-diarization',
          'model': 'diarization-fixture',
          'revision': 'diarization-v1',
        },
      ];
      final dto = CanonicalTranscriptDto.fromJson(json);
      expect(dto.durationUs, 9007199254740991);
      expect(dto.access.workspaceId, 'workspace-fixture');
      expect(dto.engines.map((e) => e.role), [
        CanonicalEngineRole.asr,
        CanonicalEngineRole.diarization,
      ]);
    },
  );

  test('DTO lists are immutable and input mutation cannot rewrite them', () {
    final json = fixture();
    final dto = CanonicalTranscriptDto.fromJson(json);
    json['segments'].clear();
    expect(dto.segments, hasLength(3));
    expect(() => dto.segments.clear(), throwsUnsupportedError);
    expect(() => dto.speakers.clear(), throwsUnsupportedError);
    expect(() => dto.engines.clear(), throwsUnsupportedError);
    expect(() => dto.segments.first.words.clear(), throwsUnsupportedError);
  });

  final invalid = <String, void Function(Map<String, dynamic>)>{
    'unknown schema version': (j) =>
        j['schema_version'] = 'dictai-transcript/v2',
    'missing nullable transcript language': (j) => j.remove('language'),
    'missing nullable workspace': (j) => j['access'].remove('workspace_id'),
    'missing nullable segment confidence': (j) =>
        segment(j).remove('confidence'),
    'missing nullable word language': (j) => word(j).remove('language'),
    'missing engines': (j) => j.remove('engines'),
    'null segments': (j) => j['segments'] = null,
    'null words': (j) => segment(j)['words'] = null,
    'top level invented identity': (j) =>
        j['participant_id'] = 'person-fixture',
    'speaker invented identity': (j) =>
        j['speakers'][0]['participant_id'] = 'person-fixture',
    'word invented identity': (j) => word(j)['speaker_id'] = 'speaker_1',
    'empty owner': (j) => j['access']['owner_user_id'] = '',
    'blank workspace': (j) => j['access']['workspace_id'] = ' ',
    'zero duration': (j) => j['duration_us'] = 0,
    'negative duration': (j) => j['duration_us'] = -1,
    'JSON-inexact duration': (j) => j['duration_us'] = 9007199254740992,
    'fractional offset': (j) => segment(j)['start_us'] = 0.5,
    'seconds instead of integer microseconds': (j) => j['duration_us'] = 5.0,
    'negative offset': (j) => segment(j)['start_us'] = -1,
    'empty interval': (j) => segment(j)['end_us'] = 0,
    'offset beyond recording': (j) => segment(j, 2)['end_us'] = 6000000,
    'invalid language': (j) => j['language'] = 'ru/en',
    'language newline': (j) => word(j)['language'] = 'ru\n',
    'missing provenance revision': (j) => j['engines'][0]['revision'] = '',
    'duplicate engine role': (j) =>
        j['engines'].add(<String, dynamic>{...j['engines'][0]}),
    'missing diarization provenance': (j) => j['engines'][0]['role'] = 'asr',
    'unknown engine role': (j) => j['engines'][0]['role'] = 'future',
    'no_speech with segments': (j) => j['speech_state'] = 'no_speech',
    'speech without segments': (j) => j['segments'] = [],
    'unknown speech state': (j) => j['speech_state'] = 'future',
    'speaker ordinal gap': (j) => j['speakers'][0]['speaker_id'] = 'speaker_3',
    'renamed backend label': (j) => j['speakers'][0]['label'] = 'Alice',
    'undefined speaker': (j) => segment(j)['speaker_id'] = 'person-fixture',
    'unused speaker': (j) =>
        j['speakers'].add({'speaker_id': 'speaker_3', 'label': 'Speaker 3'}),
    'speaker order differs from first appearance': (j) {
      segment(j)['speaker_id'] = 'speaker_2';
      segment(j, 1)['speaker_id'] = 'speaker_1';
    },
    'known speaker overlaps itself': (j) =>
        segment(j, 1)['speaker_id'] = 'speaker_1',
    'segments out of order': (j) =>
        j['segments'] = (j['segments'] as List).reversed.toList(),
    'duplicate segment': (j) => j['segments'].insert(1, {...segment(j)}),
    'unavailable with fabricated word times': (j) =>
        segment(j)['word_timing'] = 'unavailable',
    'available without words': (j) => segment(j)['words'] = [],
    'unknown word timing': (j) => segment(j)['word_timing'] = 'future',
    'word beyond segment': (j) => word(j, 1)['end_us'] = 2000001,
    'zero-length word': (j) => word(j)['end_us'] = 0,
    'overlapping words': (j) => word(j, 1)['start_us'] = 999999,
    'blank speech': (j) => segment(j)['text'] = ' \n\u0085',
    'surrounding ID whitespace': (j) => j['job_id'] = '\u0085job-fixture',
    'invalid unicode': (j) => segment(j)['text'] = String.fromCharCode(0xD800),
    'out of range confidence': (j) => word(j)['confidence'] = 1.01,
    'wrong confidence type': (j) => segment(j)['confidence'] = '0.8',
  };
  for (final entry in invalid.entries) {
    test('invalid canonical: ${entry.key}', () {
      final json = fixture();
      entry.value(json);
      expect(
        () => CanonicalTranscriptDto.fromJson(json),
        throwsFormatException,
      );
    });
  }

  test(
    'explicit confidence null differs from zero and nonfinite is rejected',
    () {
      for (final confidence in [double.nan, double.infinity, -0.1]) {
        final json = fixture();
        word(json)['confidence'] = confidence;
        expect(
          () => CanonicalTranscriptDto.fromJson(json),
          throwsFormatException,
        );
      }
      final dto = CanonicalTranscriptDto.fromJson(fixture());
      expect(dto.segments.first.confidence, isNull);
      expect(dto.segments.first.words.first.confidence, 0);
    },
  );

  test('Unicode whitespace policy follows backend without altering text', () {
    for (final text in ['\u001c', '\u200b', '\uFEFF', '😀']) {
      final json = fixture();
      segment(json)['text'] = text;
      expect(CanonicalTranscriptDto.fromJson(json).segments.first.text, text);
    }
    for (final text in [
      '\u0085',
      '\u00a0',
      '\u1680',
      '\u2001',
      '\u202f',
      '\u205f',
      '\u3000',
    ]) {
      final json = fixture();
      segment(json)['text'] = text;
      expect(
        () => CanonicalTranscriptDto.fromJson(json),
        throwsFormatException,
      );
    }
  });

  for (final job in ['queued', 'running', 'completed', 'failed', 'cancelled']) {
    test('202 $job preserves status, terminal jobs do not wait', () async {
      final terminal = job == 'failed' || job == 'cancelled';
      adapter.enqueue(
        202,
        status(job: job, transcript: terminal ? job : 'pending'),
      );
      final result =
          await api.getTranscript('audio-fixture', jobId: 'job-fixture')
              as CanonicalStatus;
      expect(result.status.rawJobStatus, job);
      expect(result.status.isTerminalFailure, terminal);
      expect(result.status.shouldPollTranscript, !terminal);
      expect(result.status.summaryStatus, SummaryStatus.pending);
      expect(adapter.requests, hasLength(1));
    });
  }

  test(
    '202 unknown states stay diagnostic and never become canonical ready',
    () async {
      adapter.enqueue(202, status(job: 'future', transcript: 'future'));
      final result =
          await api.getTranscript('audio-fixture') as CanonicalStatus;
      expect(result.status.hasUnknownStatus, isTrue);
      expect(result.status.shouldPollTranscript, isFalse);
    },
  );

  test(
    'summary failure does not gate 200 canonical and artifact503 is distinct',
    () async {
      adapter
        ..enqueue(202, {
          ...status(summary: 'failed'),
          'summary_error': 'model_specific_failure',
        })
        ..enqueue(200, fixture())
        ..enqueue(503, {'error': 'artifact unavailable'});
      final processing =
          await api.getTranscript('audio-fixture') as CanonicalStatus;
      expect(processing.status.summaryStatus, SummaryStatus.failed);
      expect(await api.getTranscript('audio-fixture'), isA<CanonicalReady>());
      final unavailable =
          await api.getTranscript('audio-fixture') as CanonicalUnavailable;
      expect(unavailable.failure.kind, ApiFailureKind.artifactUnavailable);
      expect(
        unavailable.failure.actions,
        contains(ApiRecoveryAction.retryRead),
      );
      expect(adapter.requests, hasLength(3));
    },
  );

  test(
    'malformed responses, unsupported version and mismatched identity fail safely',
    () async {
      final responses = <(int, Object?)>[
        (200, null),
        (200, []),
        (200, 'not JSON'),
        (200, status()),
        (200, {...fixture(), 'schema_version': 'dictai-transcript/v2'}),
        (200, {...fixture(), 'recording_id': 'different-audio'}),
        (200, {...fixture(), 'job_id': 'different-job'}),
        (202, fixture()),
        (202, {...status(), 'job_id': 'different-job'}),
        (202, status(transcript: 'ready')),
        (204, null),
      ];
      for (final (code, body) in responses) {
        adapter.enqueue(code, body);
        await expectLater(
          api.getTranscript('audio-fixture', jobId: 'job-fixture'),
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
    500: ApiFailureKind.serverError,
    503: ApiFailureKind.serviceUnavailable,
  }.entries) {
    test(
      'HTTP ${entry.key} keeps shared error meaning without empty transcript',
      () async {
        adapter.enqueue(
          entry.key,
          '<html>private-fixture</html>',
          contentType: 'text/html',
        );
        await expectLater(
          api.getTranscript('audio-fixture'),
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
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test('transport and local interceptor errors propagate safely', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
      ),
    );
    await expectLater(
      api.getTranscript('audio-fixture'),
      throwsA(
        isA<ApiFailure>().having((e) => e.kind, 'kind', ApiFailureKind.timeout),
      ),
    );
    dio.interceptors.clear();
    const local = ServerException('Local secure storage unavailable');
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) =>
            handler.reject(DioException(requestOptions: options, error: local)),
      ),
    );
    await expectLater(api.getTranscript('audio-fixture'), throwsA(same(local)));
    expect(adapter.requests, isEmpty);
  });

  test(
    'encoded paths and pinned query remain exact; blank IDs cannot select latest',
    () async {
      const audioId = 'audio/structured?other=1';
      const jobId = 'job/with?query=1';
      adapter.enqueue(200, {
        ...fixture(),
        'recording_id': audioId,
        'job_id': jobId,
      });
      await api.getTranscript(audioId, jobId: jobId);
      expect(
        adapter.requests.single.path,
        '/meetings/results/audio%2Fstructured%3Fother%3D1/structured',
      );
      expect(adapter.requests.single.queryParameters, {'job_id': jobId});
      for (final id in ['', ' ', ' job-fixture']) {
        await expectLater(
          api.getTranscript('audio-fixture', jobId: id),
          throwsA(isA<ValidationException>()),
        );
      }
      expect(adapter.requests, hasLength(1));
    },
  );
}
