import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/voice_profile_dto.dart';

class VoiceProfileApi {
  final Dio _dio;
  VoiceProfileApi(this._dio);

  /// GET /voice-profiles/profiles
  /// Response: { data: [{ voice_profile_id, participant_id?, display_name, created_at }] }
  Future<List<VoiceProfileDto>> getVoiceProfiles() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/voice-profiles/profiles',
      );
      final list = (response.data?['data'] as List<dynamic>?) ?? [];
      return list
          .map((e) => VoiceProfileDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// POST /voice-profiles/profiles
  /// Multipart: workspace_id, participant_id, display_name?, audio (file)
  /// Response: { voice_profile_id, participant_id, embedding }
  Future<Map<String, dynamic>> createVoiceProfile({
    required String workspaceId,
    required String participantId,
    required String audioPath,
    String? displayName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'workspace_id': workspaceId,
        'participant_id': participantId,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
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

  /// POST /voice-profiles/profiles/:voice_profile_id/assign
  Future<void> assignVoiceProfile({
    required String workspaceId,
    required String participantId,
    required String voiceProfileId,
  }) async {
    try {
      await _dio.post<void>(
        '/voice-profiles/profiles/$voiceProfileId/assign',
        data: {
          'workspace_id': workspaceId,
          'participant_id': participantId,
        },
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// POST /voice-profiles/library
  /// Multipart: display_name?, audio (file)
  Future<Map<String, dynamic>> createLibraryProfile({
    required String audioPath,
    String? displayName,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
        'audio': await MultipartFile.fromFile(audioPath),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/voice-profiles/library',
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
      403 => const ValidationException('Access denied'),
      404 => const NotFoundException('Voice profile not found'),
      _ => ServerException(
          (e.response?.data as Map?)?['error'] as String? ??
              e.message ??
              'Unknown error',
        ),
    };
  }
}
