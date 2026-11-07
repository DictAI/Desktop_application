import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import 'dto/upload_accepted_dto.dart';
import 'dto/upload_options.dart';
import 'wav_validator.dart';

/// Inject the shared authenticated Dio. One invocation sends at most one POST;
/// no retries, key generation, polling, storage or UI/provider wiring live here.
final class V2UploadApi {
  V2UploadApi(this._dio);
  final Dio _dio;

  /// [hasRecoverableUpload] is true only when the caller has durably retained
  /// these SAME bytes/options/key. It adds a recovery hint, never a retry.
  /// [onSendProgress] reports multipart bytes sent, not processing progress.
  Future<UploadAcceptedDto> upload({
    required File audioFile,
    required UploadOptions options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    bool hasRecoverableUpload = false,
  }) async {
    try {
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      final key = options.idempotencyKey;
      if (key.codeUnits.any(
        (unit) => unit != 0x09 && (unit < 0x20 || unit > 0x7e),
      )) {
        throw const ValidationException(
          'Ключ загрузки содержит символы, недопустимые в HTTP-заголовке.',
        );
      }
      await const WavValidator().validate(audioFile);
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      final audio = await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.uri.pathSegments.last,
        contentType: DioMediaType('audio', 'wav'),
      );
      final form = FormData.fromMap({
        ...options.toMultipartFields(),
        'audio': audio,
      });
      final response = await _dio.post<List<int>>(
        options.anonymous
            ? '/ingest/v2/audio/upload/anonymous'
            : '/ingest/v2/audio/upload',
        data: form,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
          // Decode 202 from the original bytes. The shared error mapper handles
          // other HTTP statuses and their raw response bodies.
          responseType: ResponseType.bytes,
          headers: {'Idempotency-Key': key},
        ),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      if (response.statusCode != 202 || response.data == null) {
        throw _invalidResponse(response.statusCode);
      }
      final json = jsonDecode(
        utf8.decode(response.data!, allowMalformed: false),
      );
      if (json is! Map<String, dynamic>) throw const FormatException();
      final accepted = UploadAcceptedDto.fromJson(json);
      if (options.anonymous != (accepted.sessionId != null)) {
        throw const FormatException('Mismatched upload session mode');
      }
      return accepted;
    } on DioException catch (error) {
      final local = error.error;
      if (local is AppException) throw local;
      if (local is FileSystemException) throw _unreadable;
      throw ApiErrorMapper.fromDio(
            error,
            context: ApiErrorContext(
              hasRecoverableUpload: hasRecoverableUpload,
            ),
          ) ??
          _invalidResponse(error.response?.statusCode);
    } on FileSystemException {
      throw _unreadable;
    } on FormatException {
      throw _invalidResponse(202);
    } on TypeError {
      throw _invalidResponse(202);
    }
  }

  static const _unreadable = ValidationException(
    'The WAV file could not be read. Choose an available local file.',
  );

  static ApiFailure _invalidResponse(int? status) => ApiFailure(
    'Сервер не вернул корректное подтверждение загрузки. '
    'Сохраните исходный файл и параметры отправки.',
    kind: ApiFailureKind.invalidResponse,
    statusCode: status,
  );
}
