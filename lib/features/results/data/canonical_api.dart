import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import 'dto/canonical_transcript_dto.dart';
import 'dto/speech_status_dto.dart';

/// The three documented R04 outcomes. Other HTTP/transport/invalid responses
/// throw the shared AppException, consistent with the other feature clients.
sealed class CanonicalResult {
  const CanonicalResult();
}

final class CanonicalReady extends CanonicalResult {
  const CanonicalReady(this.transcript);
  final CanonicalTranscriptDto transcript;
}

/// 202 includes failed/cancelled jobs. Inspect status; it is not always pending.
final class CanonicalStatus extends CanonicalResult {
  const CanonicalStatus(this.status);
  final SpeechStatusDto status;
}

/// Projection may be ready while the immutable artifact is unavailable.
final class CanonicalUnavailable extends CanonicalResult {
  const CanonicalUnavailable(this.failure);
  final ApiFailure failure;
}

final class CanonicalApi {
  CanonicalApi(this._dio);
  final Dio _dio;

  Future<CanonicalResult> getTranscript(
    String audioId, {
    String? jobId,
    CancelToken? cancelToken,
  }) async {
    for (final id in [audioId, if (jobId != null) jobId]) {
      if (id.isEmpty || id.trim() != id) {
        throw const ValidationException(
          'Не указан идентификатор записи или задачи.',
        );
      }
    }
    try {
      final response = await _dio.get<dynamic>(
        '/meetings/results/${Uri.encodeComponent(audioId)}/structured',
        queryParameters: jobId == null ? null : {'job_id': jobId},
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const FormatException();
      switch (response.statusCode) {
        case 200:
          final transcript = CanonicalTranscriptDto.fromJson(data);
          if (transcript.recordingId != audioId ||
              jobId != null && transcript.jobId != jobId) {
            throw const FormatException();
          }
          return CanonicalReady(transcript);
        case 202:
          final status = SpeechStatusDto.fromJson(data);
          if (jobId != null && status.jobId != jobId ||
              status.transcriptStatus == TranscriptStatus.ready) {
            throw const FormatException();
          }
          return CanonicalStatus(status);
        default:
          throw const FormatException();
      }
    } on DioException catch (error) {
      final local = error.error;
      if (local is AppException) throw local;
      final failure =
          ApiErrorMapper.fromDio(
            error,
            context: const ApiErrorContext(
              resource: ApiResource.structuredTranscript,
            ),
          ) ??
          _invalidResponse();
      if (failure.kind == ApiFailureKind.artifactUnavailable) {
        return CanonicalUnavailable(failure);
      }
      throw failure;
    } on FormatException {
      throw _invalidResponse();
    } on TypeError {
      throw _invalidResponse();
    }
  }

  static ApiFailure _invalidResponse() => ApiFailure(
    'Сервер вернул некорректный или неподдерживаемый транскрипт.',
    kind: ApiFailureKind.invalidResponse,
  );
}
