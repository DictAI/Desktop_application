import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';

/// Voice profile endpoints.
/// STUB: GET /voice-profile/{userId} — not yet implemented in backend
///       POST /voice-profile/enroll  — not yet implemented in backend
/// See MISSING_ENDPOINTS.md п.4
class VoiceProfileApi {
  // ignore: unused_field
  final Dio _dio;
  VoiceProfileApi(this._dio);

  /// STUB — GET /voice-profile/{userId}
  /// Returns the voice profile for the given user.
  Future<Map<String, dynamic>> getVoiceProfile(String userId) async {
    // TODO: uncomment when backend implements GET /voice-profile/{userId}
    // try {
    //   final response = await _dio.get<Map<String, dynamic>>(
    //     '/voice-profile/$userId',
    //   );
    //   return response.data!;
    // } on DioException catch (e) {
    //   throw _mapError(e);
    // }
    throw StubException(
      'GET /voice-profile/{userId} is not yet implemented in the backend. '
      'See MISSING_ENDPOINTS.md п.4',
    );
  }

  /// STUB — POST /voice-profile/enroll
  /// Enrolls audio samples for voice profile creation.
  Future<void> enrollVoiceProfile({
    required String userId,
    required List<String> audioPaths,
  }) async {
    // TODO: uncomment when backend implements POST /voice-profile/enroll
    // try {
    //   final files = await Future.wait(
    //     audioPaths.map((p) => MultipartFile.fromFile(p)),
    //   );
    //   final formData = FormData.fromMap({
    //     'user_id': userId,
    //     'samples': files,
    //   });
    //   await _dio.post('/voice-profile/enroll', data: formData);
    // } on DioException catch (e) {
    //   throw _mapError(e);
    // }
    throw StubException(
      'POST /voice-profile/enroll is not yet implemented in the backend. '
      'See MISSING_ENDPOINTS.md п.4',
    );
  }

  // ignore: unused_element
  AppException _mapError(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      401 => UnauthorizedException(),
      404 => NotFoundException('Voice profile not found'),
      _   => ServerException(
          e.response?.data?['error']?.toString() ?? e.message ?? 'Unknown error',
        ),
    };
  }
}
