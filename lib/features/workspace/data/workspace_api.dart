import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/workspace_dto.dart';
import 'dto/participant_dto.dart';

final class WorkspaceApi {
  final Dio _dio;
  WorkspaceApi(this._dio);

  Future<List<WorkspaceDto>> getWorkspaces({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/workspaces/',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      return list
          .map((e) => WorkspaceDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
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

  Future<WorkspaceDto> updateWorkspace(String workspaceId, String name) async {
    try {
      final response = await _dio.put(
        '/workspaces/$workspaceId',
        data: {'name': name},
      );
      return WorkspaceDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    try {
      await _dio.delete('/workspaces/$workspaceId');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<ParticipantDto>> getParticipants(String workspaceId) async {
    try {
      final response =
          await _dio.get('/workspaces/$workspaceId/participants');
      final list = (response.data as List<dynamic>?) ?? [];
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

  Future<ParticipantDto> updateParticipant({
    required String workspaceId,
    required String participantId,
    required String name,
    required String email,
  }) async {
    try {
      final response = await _dio.put(
        '/workspaces/$workspaceId/participants/$participantId',
        data: {'name': name, 'email': email},
      );
      return ParticipantDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteParticipant({
    required String workspaceId,
    required String participantId,
  }) async {
    try {
      await _dio.delete(
        '/workspaces/$workspaceId/participants/$participantId',
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
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
