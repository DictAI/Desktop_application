import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import 'dto/workspace_dto.dart';
import 'dto/participant_dto.dart';

final class WorkspaceApi {
  final Dio _dio;
  WorkspaceApi(this._dio);

  Future<List<WorkspaceDto>> getWorkspaces({
    int page = 1,
    int limit = 20,
  }) async => (await getWorkspacesPage(page: page, limit: limit)).data;

  Future<WorkspacePage> getWorkspacesPage({int page = 1, int limit = 20}) {
    if (page < 1 || limit < 1 || limit > 100) {
      throw const ValidationException('Недопустимые параметры страницы.');
    }
    return _perform(
      () => _dio.get(
        '/workspaces/',
        queryParameters: {'page': page, 'limit': limit},
      ),
      (data) => WorkspacePage.fromJson(_object(data)),
    );
  }

  Future<WorkspaceDto> createWorkspace(String name) => _perform(
    () => _dio.post('/workspaces/', data: {'name': name}),
    (data) => WorkspaceDto.fromJson(_object(data)),
  );

  Future<WorkspaceDto> getWorkspace(String workspaceId) => _perform(
    () => _dio.get(_workspacePath(workspaceId)),
    (data) => WorkspaceDto.fromJson(_object(data)),
  );

  Future<WorkspaceDto> updateWorkspace(String workspaceId, String name) =>
      _perform(
        () => _dio.put(_workspacePath(workspaceId), data: {'name': name}),
        (data) => WorkspaceDto.fromJson(_object(data)),
      );

  Future<void> deleteWorkspace(String workspaceId) =>
      _perform(() => _dio.delete(_workspacePath(workspaceId)), (_) {});

  Future<List<ParticipantDto>> getParticipants(String workspaceId) => _perform(
    () => _dio.get('${_workspacePath(workspaceId)}/participants'),
    (data) {
      if (data == null) return const <ParticipantDto>[];
      if (data is! List) throw const FormatException('Expected contacts array');
      return data
          .map((item) => ParticipantDto.fromJson(_object(item)))
          .toList();
    },
  );

  Future<ParticipantDto> addParticipant({
    required String workspaceId,
    required String name,
    required String email,
  }) => _perform(
    () => _dio.post(
      '${_workspacePath(workspaceId)}/participants',
      data: {'name': name, 'email': email},
    ),
    (data) => ParticipantDto.fromJson(_object(data)),
  );

  Future<ParticipantDto> updateParticipant({
    required String workspaceId,
    required String participantId,
    required String name,
    required String email,
  }) => _perform(
    () => _dio.put(
      _participantPath(workspaceId, participantId),
      data: {'name': name, 'email': email},
    ),
    (data) => ParticipantDto.fromJson(_object(data)),
  );

  Future<void> deleteParticipant({
    required String workspaceId,
    required String participantId,
  }) => _perform(
    () => _dio.delete(_participantPath(workspaceId, participantId)),
    (_) {},
  );

  static String _workspacePath(String id) =>
      '/workspaces/${Uri.encodeComponent(id)}';
  static String _participantPath(String workspace, String participant) =>
      '${_workspacePath(workspace)}/participants/${Uri.encodeComponent(participant)}';

  static Map<String, dynamic> _object(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return data;
  }

  Future<T> _perform<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Object?) decode,
  ) async {
    try {
      return decode((await request()).data);
    } on DioException catch (error) {
      // Preserve safe local storage failures from the common AuthInterceptor.
      final local = error.error;
      if (local is AppException) throw local;
      throw ApiErrorMapper.fromDio(error) ?? _invalidResponse();
    } on FormatException {
      throw _invalidResponse();
    } on TypeError {
      throw _invalidResponse();
    }
  }

  static ApiFailure _invalidResponse() => ApiFailure(
    'Сервер вернул некорректные данные рабочего пространства.',
    kind: ApiFailureKind.invalidResponse,
  );
}
