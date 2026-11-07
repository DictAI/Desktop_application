import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/features/workspace/data/workspace_api.dart';
import 'package:dict_ai/features/workspace/data/dto/workspace_dto.dart';
import 'package:dict_ai/features/workspace/data/dto/participant_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const workspaceId = '11111111-1111-4111-8111-111111111111';
const ownerId = '22222222-2222-4222-8222-222222222222';
const participantId = '33333333-3333-4333-8333-333333333333';
Map<String, Object> workspace({bool details = false}) => {
  'workspace_id': workspaceId,
  details ? 'owner_id' : 'owner_user_id': ownerId,
  'name': 'Demo',
  'created_at': '2026-10-24T09:00:00.123Z',
};
Map<String, Object> contact() => {
  'participant_id': participantId,
  'workspace_id': workspaceId,
  'name': 'Contact',
  'email': 'contact@example.invalid',
};
Map<String, Object> page({List<Object>? items}) => {
  'data': items ?? [workspace()],
  'pagination': {'page': 2, 'limit': 20, 'total': 21, 'total_pages': 2},
};

void main() {
  late ScriptedAdapter adapter;
  late Dio dio;
  late WorkspaceApi api;
  setUp(() {
    adapter = ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    api = WorkspaceApi(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    'all nine W01-W09 requests use the confirmed paths and bodies',
    () async {
      adapter
        ..enqueue(200, page())
        ..enqueue(200, workspace())
        ..enqueue(200, workspace(details: true))
        ..enqueue(200, workspace(details: true))
        ..enqueue(200, {'message': 'workspace deleted successfully'})
        ..enqueue(200, [contact()])
        ..enqueue(200, contact())
        ..enqueue(200, contact())
        ..enqueue(200, {'message': 'participant deleted successfully'});
      final listed = await api.getWorkspacesPage(page: 2);
      expect(listed.data.single.ownerUserId, ownerId);
      expect(listed.pagination.page, 2);
      expect(listed.pagination.limit, 20);
      expect(listed.pagination.total, 21);
      expect(listed.pagination.totalPages, 2);
      expect((await api.createWorkspace('New')).workspaceId, workspaceId);
      expect((await api.getWorkspace(workspaceId)).ownerUserId, ownerId);
      await api.updateWorkspace(workspaceId, 'Renamed');
      await api.deleteWorkspace(workspaceId);
      expect(
        (await api.getParticipants(workspaceId)).single.email,
        'contact@example.invalid',
      );
      await api.addParticipant(
        workspaceId: workspaceId,
        name: 'New',
        email: 'new@example.invalid',
      );
      await api.updateParticipant(
        workspaceId: workspaceId,
        participantId: participantId,
        name: 'Changed',
        email: '',
      );
      await api.deleteParticipant(
        workspaceId: workspaceId,
        participantId: participantId,
      );
      final requests = adapter.requests;
      expect(requests.map((r) => r.method).toList(), [
        'GET',
        'POST',
        'GET',
        'PUT',
        'DELETE',
        'GET',
        'POST',
        'PUT',
        'DELETE',
      ]);
      expect(requests.map((r) => r.path).toList(), [
        '/workspaces/',
        '/workspaces/',
        '/workspaces/$workspaceId',
        '/workspaces/$workspaceId',
        '/workspaces/$workspaceId',
        '/workspaces/$workspaceId/participants',
        '/workspaces/$workspaceId/participants',
        '/workspaces/$workspaceId/participants/$participantId',
        '/workspaces/$workspaceId/participants/$participantId',
      ]);
      expect(requests.first.queryParameters, {'page': 2, 'limit': 20});
      expect(requests[1].data, {'name': 'New'});
      expect(requests[3].data, {'name': 'Renamed'});
      expect(requests[6].data, {'name': 'New', 'email': 'new@example.invalid'});
      expect(requests[7].data, {'name': 'Changed', 'email': ''});
    },
  );

  test(
    'existing list method remains compatible and empty page is valid',
    () async {
      adapter.enqueue(200, page(items: []));
      expect(await api.getWorkspaces(page: 2), isEmpty);
    },
  );
  test('both owner variants and fractional UTC created_at stay supported', () {
    for (final details in [false, true]) {
      final item = WorkspaceDto.fromJson(workspace(details: details));
      expect(item.ownerUserId, ownerId);
      expect(item.createdAt, DateTime.utc(2026, 10, 24, 9, 0, 0, 123));
    }
  });
  test(
    'contacts are name/email records without voice identity wire fields',
    () {
      final item = ParticipantDto.fromJson({
        ...contact(),
        'voice_profile_id': 'unexpected',
      });
      expect(item.toJson(), contact());
      expect(item.toJson().keys.toSet(), {
        'participant_id',
        'workspace_id',
        'name',
        'email',
      });
      expect(item.copyWith(name: 'Renamed').name, 'Renamed');
    },
  );
  for (final body in [null, <Object>[]]) {
    test('empty participants body $body is an empty contact list', () async {
      adapter.enqueue(200, body);
      expect(await api.getParticipants(workspaceId), isEmpty);
    });
  }
  for (final entry in {
    400: ApiFailureKind.badRequest,
    401: ApiFailureKind.unauthorized,
    403: ApiFailureKind.forbidden,
    404: ApiFailureKind.notFound,
    409: ApiFailureKind.conflict,
    500: ApiFailureKind.serverError,
    503: ApiFailureKind.serviceUnavailable,
  }.entries) {
    test(
      'HTTP ${entry.key} retains its real meaning without body leakage',
      () async {
        adapter.enqueue(
          entry.key,
          '<html>synthetic-private-error</html>',
          contentType: 'text/html',
        );
        await expectLater(
          api.getWorkspace(workspaceId),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.kind, 'kind', entry.value)
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('synthetic-private-error')),
                ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }
  test(
    'missing workspace returning backend 500 is not invented as 404',
    () async {
      adapter.enqueue(500, {'error': 'internal server error'});
      await expectLater(
        api.getWorkspace(workspaceId),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.serverError,
          ),
        ),
      );
    },
  );
  for (final body in [
    null,
    'not JSON',
    {},
    {'data': null, 'pagination': {}},
    {
      'data': [],
      'pagination': {
        'page': 1,
        'limit': 20,
        'total': 'wrong',
        'total_pages': 0,
      },
    },
    {
      'data': [
        {'workspace_id': workspaceId},
      ],
      'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
    },
  ]) {
    test(
      'malformed page ${body.runtimeType} becomes safe AppException',
      () async {
        adapter.enqueue(200, body);
        await expectLater(
          api.getWorkspaces(),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.kind,
              'kind',
              ApiFailureKind.invalidResponse,
            ),
          ),
        );
      },
    );
  }
  test('malformed contacts cannot escape as a TypeError', () async {
    adapter.enqueue(200, [
      {'participant_id': 42},
    ]);
    await expectLater(
      api.getParticipants(workspaceId),
      throwsA(isA<ApiFailure>()),
    );
  });
  test('client avoids backend pagination limit>100 metadata mismatch', () {
    expect(
      () => api.getWorkspacesPage(page: 0),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => api.getWorkspacesPage(limit: 101),
      throwsA(isA<ValidationException>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test('path IDs cannot inject a second route or query', () async {
    adapter.enqueue(200, workspace(details: true));
    await api.getWorkspace('id/participants?limit=1');
    expect(
      adapter.requests.single.path,
      '/workspaces/id%2Fparticipants%3Flimit%3D1',
    );
  });
}
