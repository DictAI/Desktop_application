import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../record/data/dto/v2_session_dto.dart';
import 'dto/speech_status_dto.dart';

/// Inject the common authenticated Dio; no polling, retries or provider wiring.
final class SpeechStatusApi {
  SpeechStatusApi(this._dio);
  final Dio _dio;

  /// Omitting jobId selects latest, not a list/history of processing versions.
  Future<SpeechStatusDto> getSpeechStatus(
    String audioId, {
    String? jobId,
    CancelToken? cancelToken,
  }) {
    _requireId(audioId);
    if (jobId != null) _requireId(jobId);
    return _get(
      '/meetings/results/${Uri.encodeComponent(audioId)}/speech-status',
      (json) {
        final status = SpeechStatusDto.fromJson(json);
        if (jobId != null && status.jobId != jobId) {
          throw const FormatException('Mismatched speech job');
        }
        return status;
      },
      query: jobId == null ? null : {'job_id': jobId},
      cancelToken: cancelToken,
    );
  }

  Future<V2SessionDto> getAnonymousSession(
    String sessionId, {
    CancelToken? cancelToken,
  }) {
    _requireId(sessionId);
    return _get(
      '/ingest/v2/audio/anonymous/${Uri.encodeComponent(sessionId)}',
      (json) {
        final session = V2SessionDto.fromJson(json);
        if (session.sessionId != sessionId) {
          throw const FormatException('Mismatched V2 session');
        }
        return session;
      },
      cancelToken: cancelToken,
    );
  }

  static void _requireId(String value) {
    if (value.isEmpty || value.trim() != value) {
      throw const ValidationException(
        'Не указан идентификатор записи или задачи.',
      );
    }
  }

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) decode, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      if (response.statusCode != 200 ||
          response.data is! Map<String, dynamic>) {
        throw const FormatException('Invalid status response');
      }
      return decode(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
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
    'Сервер вернул некорректные данные состояния обработки.',
    kind: ApiFailureKind.invalidResponse,
  );
}
