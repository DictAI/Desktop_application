import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/results/data/results_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

Map<String, Object?> item() => {
  'result_id': 'job-1',
  'audio_id': 'audio-1',
  'workspace_id': '',
  'workspace_name': '',
  'upload_user_id': 'owner-1',
  'summary_url': '',
  'transcript_url':
      '/meetings/results/audio-1/documents/transcript.txt?job_id=job-1',
  'status': 'done',
  'created_at': '2026-11-03T09:00:00.123456Z',
};

Map<String, Object?> page({
  List<Object?>? data,
  int number = 1,
  int total = 41,
}) => {
  'data': data ?? [item()],
  'pagination': {
    'page': number,
    'limit': 20,
    'total': total,
    'total_pages': (total / 20).ceil(),
  },
};

void main() {
  late ScriptedAdapter adapter;
  late Dio dio;
  late ResultsApi api;
  setUp(() {
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
      ..httpClientAdapter = adapter;
    api = ResultsApi(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    'retains page metadata, job identity and anonymous empty fields',
    () async {
      adapter.enqueue(200, page(number: 2));
      final result = await api.getResultsPage(page: 2);
      expect(result.pagination.page, 2);
      expect(result.pagination.total, 41);
      expect(result.pagination.totalPages, 3);
      expect(result.pagination.limit, 20);
      final row = result.data.single;
      expect(row.resultId, 'job-1');
      expect(row.audioId, 'audio-1');
      expect(row.workspaceId, '');
      expect(row.workspaceName, '');
      expect(row.status, 'done');
      expect(row.summaryUrl, ''); // done does not imply summary ready
      expect(row.transcriptUrl, endsWith('?job_id=job-1'));
      expect(row.createdAt!.microsecond, 456);
      expect(() => result.data.clear(), throwsUnsupportedError);
      expect(adapter.requests.single.path, '/meetings/results');
      expect(adapter.requests.single.queryParameters, {'page': 2, 'limit': 20});
    },
  );

  test(
    'UTC date bounds, server limit>100 reset20, no invented filters',
    () async {
      adapter.enqueue(200, page(data: [], total: 0));
      final start = DateTime.parse('2026-11-03T10:30:00+03:00');
      final end = DateTime.parse('2026-11-04T10:30:00+03:00');
      final result = await api.getResultsPage(
        startDate: start,
        endDate: end,
        limit: 101,
      );
      expect(result.data, isEmpty);
      expect(result.pagination.totalPages, 0);
      expect(adapter.requests.single.queryParameters, {
        'page': 1,
        'limit': 20,
        'start_date': start.toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
      });
    },
  );

  test(
    'old list consumer remains compatible; unknown status remains raw',
    () async {
      adapter.enqueue(
        200,
        page(
          data: [
            {...item(), 'status': 'future_state'},
          ],
        ),
      );
      expect((await api.getResults()).single.status, 'future_state');
    },
  );

  test('positive pagination validated locally without a request', () async {
    await expectLater(
      api.getResultsPage(page: 0),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      api.getResultsPage(limit: 0),
      throwsA(isA<ValidationException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'delete uses escaped audio id, 204 empty response and no body',
    () async {
      adapter.enqueue(204, '');
      await api.deleteResult('audio/one');
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/meetings/results/audio%2Fone');
      expect(adapter.requests.single.data, isNull);
    },
  );

  for (final status in [400, 401, 403, 404, 429, 500]) {
    test(
      'HTTP $status maps safely from non-JSON without raw technical text',
      () async {
        adapter.enqueue(
          status,
          '<html>sensitive backend error</html>',
          contentType: 'text/html',
        );
        await expectLater(
          api.getResultsPage(),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.statusCode, 'HTTP status', status)
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('sensitive')),
                ),
          ),
        );
      },
    );
  }

  final invalid = <Object?>[
    null,
    [],
    {'data': [], 'pagination': null},
    {'data': null, 'pagination': page()['pagination']},
    {
      'data': [],
      'pagination': {'page': 1, 'limit': 20, 'total': -1, 'total_pages': 0},
    },
    page(
      data: [
        {...item(), 'workspace_id': null},
      ],
    ),
    page(
      data: [
        {...item(), 'created_at': 'invalid'},
      ],
    ),
    page(
      data: [
        {...item(), 'result_id': ''},
      ],
    ),
    page(
      data: [
        {...item()}..remove('status'),
      ],
    ),
  ];
  for (var i = 0; i < invalid.length; i++) {
    test('malformed envelope/item $i is explicit invalid response', () async {
      adapter.enqueue(200, invalid[i]);
      await expectLater(
        api.getResultsPage(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });
  }

  test('cancelled read stays cancelled, no retry job creation', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      api.getResultsPage(cancelToken: token),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.kind, 'kind', ApiFailureKind.cancelled)
            .having((e) => e.actions, 'actions', isEmpty),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
}
