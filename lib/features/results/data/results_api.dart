import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import 'dto/result_dto.dart';

final class ResultsApi {
  final Dio _dio;
  ResultsApi(this._dio);

  Future<List<ResultDto>> getResults({
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (startDate != null) {
        queryParams['start_date'] = startDate.toUtc().toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toUtc().toIso8601String();
      }

      final response = await _dio.get(
        '/meetings/results',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>;
      return list
          .map((e) => ResultDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // No DELETE endpoint exists in backend — kept as no-op stub.
  Future<void> deleteResult(String audioId) async {
    throw const StubException(
      'DELETE /meetings/results/:audio_id не реализован в backend.',
    );
  }

  /// Скачать PDF с summary.
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

  /// Скачать PDF с транскриптом.
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
