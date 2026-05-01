import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/result_dto.dart';

final class ResultsApi {
  final Dio _dio;
  ResultsApi(this._dio);

  // ────────────────────────────────────────────────────────────────────────────
  // ЗАГЛУШКА: эндпоинт GET /meetings/results отсутствует в backend.
  // См. MISSING_ENDPOINTS.md — пункт 2.
  //
  // После реализации в results-service — заменить тело метода на:
  //
  //   final queryParams = <String, dynamic>{};
  //   if (workspaceId != null) queryParams['workspace_id'] = workspaceId;
  //   if (from != null) queryParams['from'] = from.toIso8601String();
  //   if (to != null)   queryParams['to']   = to.toIso8601String();
  //
  //   final response = await _dio.get(
  //     '/meetings/results',
  //     queryParameters: queryParams,
  //   );
  //   final list = response.data as List<dynamic>;
  //   return list
  //       .map((e) => ResultDto.fromJson(e as Map<String, dynamic>))
  //       .toList();
  // ────────────────────────────────────────────────────────────────────────────
  Future<List<ResultDto>> getResults({
    String? workspaceId,
    DateTime? from,
    DateTime? to,
  }) async {
    // TODO(backend): реализовать GET /meetings/results в results-service
    throw const StubException(
      'GET /meetings/results не реализован в backend. '
      'См. MISSING_ENDPOINTS.md п.2',
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ЗАГЛУШКА: эндпоинт DELETE /meetings/results/:audio_id отсутствует в backend.
  // См. MISSING_ENDPOINTS.md — пункт 3.
  //
  // После реализации — заменить тело на:
  //
  //   await _dio.delete('/meetings/results/$audioId');
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> deleteResult(String audioId) async {
    // TODO(backend): реализовать DELETE /meetings/results/:audio_id в results-service
    throw const StubException(
      'DELETE /meetings/results/:audio_id не реализован в backend. '
      'См. MISSING_ENDPOINTS.md п.3',
    );
  }

  /// Скачать PDF с summary. Эндпоинт существует в backend.
  Future<List<int>> getSummaryPdf(String audioId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/meetings/results/$audioId/summary',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Скачать PDF с транскриптом. Эндпоинт существует в backend.
  Future<List<int>> getTranscriptPdf(String audioId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/meetings/results/$audioId/transcript',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(DioException e) => switch (e.response?.statusCode) {
        401 => const UnauthorizedException(),
        404 => const NotFoundException('Result not found'),
        _ => ServerException(
            (e.response?.data as Map?)?['error'] as String? ?? 'Server error',
          ),
      };
}

