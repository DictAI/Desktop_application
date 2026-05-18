import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';

/// POST /audio/upload
/// Multipart: workspace_id (field) + audio (file)
/// Response: { "audio_id": "..." }
class AudioIngestApi {
  final Dio _dio;
  AudioIngestApi(this._dio);

  Future<String> uploadAudio({
    required String workspaceId,
    required File audioFile,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final fileName = audioFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'workspace_id': workspaceId,
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/ingest/audio/upload',
        data: formData,
        onSendProgress: onProgress,
      );

      final audioId = response.data?['audio_id'] as String?;
      if (audioId == null) throw ServerException('audio_id missing in response');
      return audioId;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => ValidationException('Invalid audio file or workspace_id'),
      401 => UnauthorizedException(),
      404 => NotFoundException('Workspace not found'),
      _   => ServerException(
          e.response?.data?['error']?.toString() ?? e.message ?? 'Upload failed',
        ),
    };
  }
}
