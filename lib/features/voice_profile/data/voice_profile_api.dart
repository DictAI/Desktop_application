import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';

class VoiceProfileApi {
  final Dio _dio;
  VoiceProfileApi(this._dio);

  /// POST /voice-profiles/profiles
  /// Multipart: workspace_id, participant_id, audio (file)
  /// Response: { voice_profile_id, participant_id, embedding }
  Future<Map<String, dynamic>> createVoiceProfile({
    required String workspaceId,
    required String participantId,
    required String audioPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'workspace_id': workspaceId,
        'participant_id': participantId,
        'audio': await MultipartFile.fromFile(audioPath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/voice-profiles/profiles',
        data: formData,
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// GET /voice-profiles/profiles/:participant_id
  /// Response: { participant_id, embedding }
  Future<Map<String, dynamic>> getVoiceProfile(String participantId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/voice-profiles/profiles/$participantId',
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => ValidationException(
          (e.response?.data as Map?)?['error'] as String? ?? 'Bad request',
        ),
      401 => const UnauthorizedException(),
      404 => const NotFoundException('Voice profile not found'),
      _ => ServerException(
          (e.response?.data as Map?)?['error'] as String? ??
              e.message ??
              'Unknown error',
        ),
    };
  }
}
