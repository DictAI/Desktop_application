import 'package:dio/dio.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import 'dto/results_page_dto.dart';
import 'dto/result_dto.dart';

final class ResultsApi {
  final Dio _dio;
  ResultsApi(this._dio);

  /// Compatibility for existing UI; new callers retain the full server page.
  Future<List<ResultDto>> getResults({
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async => (await getResultsPage(
    startDate: startDate,
    endDate: endDate,
    page: page,
    limit: limit,
  )).data;

  Future<ResultsPageDto> getResultsPage({
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) => _perform(() async {
    if (page < 1 || limit < 1) {
      throw const ValidationException(
        'Номер страницы и размер должны быть положительными.',
      );
    }
    final response = await _dio.get<Object?>(
      '/meetings/results',
      queryParameters: {
        'page': page,
        // R01 resets limits above 100 to 20, rather than clamping to 100.
        'limit': limit > 100 ? 20 : limit,
        if (startDate != null)
          'start_date': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
      },
      cancelToken: cancelToken,
    );
    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid results response');
    }
    return ResultsPageDto.fromJson(response.data! as Map<String, dynamic>);
  });

  Future<void> deleteResult(String audioId, {CancelToken? cancelToken}) =>
      _perform(() async {
        if (audioId.isEmpty) {
          throw const ValidationException('Не указан идентификатор аудио.');
        }
        final response = await _dio.delete<Object?>(
          '/meetings/results/${Uri.encodeComponent(audioId)}',
          cancelToken: cancelToken,
        );
        if (response.statusCode != 204) {
          throw const FormatException('Invalid delete response');
        }
      });

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

  /// Скачать исходное аудио.
  Future<List<int>> getAudio(String audioId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/meetings/results/$audioId/audio',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // Legacy download consumers retire in .33; no alternate backend routes added.
  AppException _mapError(DioException error) => error.error is AppException
      ? error.error! as AppException
      : ApiErrorMapper.fromDio(error) ?? _invalid;

  static final _invalid = ApiFailure(
    'Не удалось прочитать ответ сервера.',
    kind: ApiFailureKind.invalidResponse,
  );

  Future<T> _perform<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw _invalid;
    } on TypeError {
      throw _invalid;
    }
  }
}
