import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/workspace_dto.dart';
import 'dto/participant_dto.dart';

final class WorkspaceApi {
  final Dio _dio;
  WorkspaceApi(this._dio);

  // ────────────────────────────────────────────────────────────────────────────
  // ЗАГЛУШКА: эндпоинт GET /workspaces/ отсутствует в backend.
  // См. MISSING_ENDPOINTS.md — пункт 1.
  // После реализации эндпоинта в workspace-service — заменить тело метода на:
  //
  //   final response = await _dio.get('/workspaces/');
  //   final list = response.data as List<dynamic>;
  //   return list
  //       .map((e) => WorkspaceDto.fromJson(e as Map<String, dynamic>))
  //       .toList();
  // ────────────────────────────────────────────────────────────────────────────
  Future<List<WorkspaceDto>> getWorkspaces() async {
    // TODO(backend): реализовать GET /workspaces/ в workspace-service
    // ignore: dead_code
    throw const StubException(
      'GET /workspaces/ не реализован в backend. '
      'См. MISSING_ENDPOINTS.md п.1',
    );
  }

  Future<WorkspaceDto> createWorkspace(String name) async {
    try {
      final response = await _dio.post(
        '/workspaces/',
        data: {'name': name},
      );
      return WorkspaceDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<WorkspaceDto> getWorkspace(String workspaceId) async {
    try {
      final response = await _dio.get('/workspaces/$workspaceId');
      return WorkspaceDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<ParticipantDto>> getParticipants(String workspaceId) async {
    try {
      final response =
          await _dio.get('/workspaces/$workspaceId/participants');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => ParticipantDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<ParticipantDto> addParticipant({
    required String workspaceId,
    required String name,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '/workspaces/$workspaceId/participants',
        data: {'name': name, 'email': email},
      );
      return ParticipantDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ЗАГЛУШКА: эндпоинт DELETE /workspaces/:workspace_id отсутствует в backend.
  // См. MISSING_ENDPOINTS.md — пункт 4.
  // После реализации — заменить тело на:
  //
  //   await _dio.delete('/workspaces/$workspaceId');
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> deleteWorkspace(String workspaceId) async {
    // TODO(backend): реализовать DELETE /workspaces/:workspace_id в workspace-service
    throw const StubException(
      'DELETE /workspaces/:id не реализован в backend. '
      'См. MISSING_ENDPOINTS.md п.4',
    );
  }

  AppException _mapError(DioException e) => switch (e.response?.statusCode) {
        400 => ValidationException(
            (e.response?.data as Map?)?['error'] as String? ?? 'Bad request',
          ),
        401 => const UnauthorizedException(),
        403 => const ValidationException('Access denied'),
        404 => const NotFoundException('Workspace not found'),
        _ => ServerException(
            (e.response?.data as Map?)?['error'] as String? ?? 'Server error',
          ),
      };
}

