import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/anonymous_session_dto.dart';

class AnonymousSessionApi {
  final Dio _dio;

  AnonymousSessionApi(this._dio);

  Future<({String sessionId, String audioId})> uploadAnonymous({
    required File audioFile,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final fileName = audioFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(audioFile.path, filename: fileName),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/ingest/audio/upload/anonymous',
        data: formData,
        onSendProgress: onProgress,
      );

      final data = response.data!;
      return (
        sessionId: data['session_id'] as String,
        audioId: data['audio_id'] as String,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<AnonymousSessionDto> getSession(String sessionId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ingest/audio/anonymous/$sessionId',
      );
      return AnonymousSessionDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // Returns raw bytes of the WAV fragment for playback.
  Future<List<int>> getFragment(String sessionId, String speakerId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/ingest/audio/anonymous/$sessionId/speakers/$speakerId/fragment',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<String> confirm({
    required String sessionId,
    required String? workspaceName,
    required List<SpeakerAssignment> speakers,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ingest/audio/anonymous/$sessionId/confirm',
        data: {
          if (workspaceName != null && workspaceName.isNotEmpty)
            'workspace_name': workspaceName,
          'speakers': speakers.map((s) => s.toJson()).toList(),
        },
      );
      return response.data!['workspace_id'] as String;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(DioException e) {
    final msg = (e.response?.data as Map?)?['error'] as String?;
    return switch (e.response?.statusCode) {
      400 => ValidationException(msg ?? 'Invalid request'),
      401 => const UnauthorizedException(),
      403 => ValidationException(msg ?? 'Access denied'),
      404 => NotFoundException(msg ?? 'Session not found'),
      _ => ServerException(msg ?? e.message ?? 'Request failed'),
    };
  }
}
