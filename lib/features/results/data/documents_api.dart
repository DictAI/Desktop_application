import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../record/data/wav_validator.dart';
import 'dto/document_kind.dart';

/// A complete file in a unique directory owned by this download. The caller
/// owns this result and deletes it after export/player use or session cleanup.
final class DownloadedFile {
  const DownloadedFile._(this.file, this.byteLength, this._directory);
  final File file;
  final int byteLength;
  final Directory _directory;

  Future<void> delete() async {
    try {
      if (await _directory.exists()) await _directory.delete(recursive: true);
    } on FileSystemException {
      throw const ServerException('Не удалось удалить временный файл.');
    }
  }
}

/// R05/U04 only. Inject the common Dio so gateway policy runs before JWT.
/// Files are never published to a consumer until EOF and validation succeed.
final class DocumentsApi {
  DocumentsApi(this._dio);
  final Dio _dio;

  Future<DownloadedFile> getDocument(
    String audioId,
    DocumentKind kind, {
    required Directory temporaryDirectory,
    String? jobId,
    CancelToken? cancelToken,
  }) {
    _requireId(audioId, pathSegment: true);
    if (jobId != null) _requireId(jobId);
    return _download(
      '/meetings/results/${Uri.encodeComponent(audioId)}/documents/${kind.fileName}',
      fileName: kind.fileName,
      contentType: kind.contentType,
      temporaryDirectory: temporaryDirectory,
      query: jobId == null ? null : {'job_id': jobId},
      cancelToken: cancelToken,
    );
  }

  /// U04 has no job_id or Range contract. Always downloads the complete source.
  Future<DownloadedFile> getOriginal(
    String audioId, {
    required Directory temporaryDirectory,
    CancelToken? cancelToken,
  }) {
    _requireId(audioId, pathSegment: true);
    return _download(
      '/ingest/v2/audio/${Uri.encodeComponent(audioId)}/original',
      fileName: 'original.wav',
      contentType: 'audio/wav',
      temporaryDirectory: temporaryDirectory,
      original: true,
      cancelToken: cancelToken,
    );
  }

  Future<DownloadedFile> _download(
    String path, {
    required String fileName,
    required String contentType,
    required Directory temporaryDirectory,
    Map<String, dynamic>? query,
    bool original = false,
    CancelToken? cancelToken,
  }) async {
    // An internal token lets this request stop an oversized/error stream without
    // cancelling other requests that happen to share a caller's token.
    final transfer = CancelToken();
    var active = true;
    if (cancelToken?.isCancelled == true) transfer.cancel();
    unawaited(
      cancelToken?.whenCancel.then((_) {
        if (active && !transfer.isCancelled) transfer.cancel();
      }),
    );
    Directory? owned;
    RandomAccessFile? handle;
    var success = false;
    var receiving = false;
    try {
      if (transfer.isCancelled) throw transfer.cancelError!;
      owned = await temporaryDirectory.createTemp('dictai-download-');
      final partial = File('${owned.path}/payload.part');
      handle = partial.openSync(mode: FileMode.write);
      final response = await _dio.get<ResponseBody>(
        path,
        queryParameters: query,
        cancelToken: transfer,
        options: Options(
          responseType: ResponseType.stream,
          // Error bodies must not queue behind asynchronous 401 cleanup.
          receiveDataWhenStatusError: false,
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 || !original && status == 404),
          headers: {'Accept': contentType, 'Accept-Encoding': 'identity'},
        ),
      );
      if (!original && response.statusCode == 404) {
        // R05 distinguishes missing records from an unavailable document.
        // Consume its small marker here, without the async onError pipeline.
        throw DioException.badResponse(
          statusCode: 404,
          requestOptions: response.requestOptions,
          response: response,
        );
      }
      final body = response.data;
      if (response.statusCode != 200 || body == null) throw _invalidResponse();
      final mediaType = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final encoding = response.headers.value(Headers.contentEncodingHeader);
      if (mediaType != contentType ||
          encoding != null && encoding.toLowerCase() != 'identity') {
        throw _invalidResponse();
      }
      final declared = _contentLength(response.headers);
      if (original &&
          declared != null &&
          declared > WavValidator.maxFileBytes) {
        throw _invalidResponse();
      }
      final prefix = <int>[];
      var received = 0;
      int? riffLength;
      receiving = true;
      final completed = Completer<void>();
      late StreamSubscription<Uint8List> subscription;
      void fail(Object error, StackTrace stack) {
        if (!completed.isCompleted) completed.completeError(error, stack);
      }

      subscription = _bodyStream(body, response.requestOptions).listen(
        (chunk) {
          if (completed.isCompleted) return;
          try {
            if (transfer.isCancelled) throw transfer.cancelError!;
            received += chunk.length;
            if (declared != null && received > declared ||
                original && received > WavValidator.maxFileBytes) {
              throw _invalidResponse();
            }
            final needed = original
                ? 12
                : contentType == 'application/pdf'
                ? 5
                : 0;
            if (prefix.length < needed) {
              final count = (needed - prefix.length).clamp(0, chunk.length);
              prefix.addAll(chunk.getRange(0, count));
            }
            if (original && prefix.length == 12 && riffLength == null) {
              if (!_tag(prefix, 0, 'RIFF') || !_tag(prefix, 8, 'WAVE')) {
                throw _invalidResponse();
              }
              riffLength =
                  ByteData.sublistView(
                    Uint8List.fromList(prefix),
                  ).getUint32(4, Endian.little) +
                  8;
              if (riffLength! > WavValidator.maxFileBytes) {
                throw _invalidResponse();
              }
            }
            if (riffLength != null && received > riffLength!) {
              throw _invalidResponse();
            }
            // Dio 5.9.2's response controller does not forward pause to its
            // source. Sync writes avoid an async disk wait that could queue the
            // whole source in that controller. Each write is at most 64 KiB.
            for (var offset = 0; offset < chunk.length; offset += 65536) {
              handle!.writeFromSync(
                chunk,
                offset,
                (offset + 65536).clamp(0, chunk.length),
              );
            }
          } catch (error, stack) {
            fail(error, stack);
            if (!transfer.isCancelled) transfer.cancel();
          }
        },
        onError: fail,
        onDone: () {
          if (!completed.isCompleted) completed.complete();
        },
        cancelOnError: true,
      );
      try {
        await completed.future;
      } finally {
        await subscription.cancel();
      }
      if (transfer.isCancelled) throw transfer.cancelError!;
      if (received == 0 || declared != null && received != declared) {
        throw _incomplete();
      }
      if (original) {
        if (riffLength == null || received < riffLength!) throw _incomplete();
      } else if (contentType == 'application/pdf' &&
          !_tag(prefix, 0, '%PDF-')) {
        throw _invalidResponse();
      }
      handle.flushSync();
      handle.closeSync();
      handle = null;
      if (original) {
        try {
          await const WavValidator().validate(partial);
        } on ValidationException {
          throw _invalidResponse();
        }
      }
      if (transfer.isCancelled) throw transfer.cancelError!;
      final complete = await partial.rename('${owned.path}/$fileName');
      if (transfer.isCancelled) throw transfer.cancelError!;
      success = true;
      return DownloadedFile._(complete, received, owned);
    } on DioException catch (error) {
      final local = error.error;
      if (local is AppException) throw local;
      final mapped = await _readError(error);
      throw ApiErrorMapper.fromDio(
            mapped,
            context: ApiErrorContext(
              resource: original ? ApiResource.general : ApiResource.document,
              incompleteTransfer:
                  receiving &&
                  error.type != DioExceptionType.cancel &&
                  error.type != DioExceptionType.receiveTimeout,
            ),
          ) ??
          _invalidResponse();
    } on FileSystemException {
      throw const ServerException(
        'Не удалось сохранить файл в выбранном каталоге.',
      );
    } on AppException {
      rethrow;
    } catch (_) {
      if (receiving) throw _incomplete();
      throw _invalidResponse();
    } finally {
      active = false;
      if (!transfer.isCancelled) transfer.cancel();
      var cleanupFailed = false;
      try {
        handle?.closeSync();
      } on FileSystemException {
        cleanupFailed = true;
      }
      try {
        if (!success && owned != null && await owned.exists()) {
          await owned.delete(recursive: true);
        }
      } on FileSystemException {
        cleanupFailed = true;
      }
      if (cleanupFailed) {
        throw const ServerException(
          'Не удалось удалить незавершённый временный файл.',
        );
      }
    }
  }

  /// HTTP error streams are bytes too. Read at most 16 KiB for documented JSON
  /// markers; never drain a potentially unbounded HTML/private response body.
  static Future<DioException> _readError(DioException error) async {
    final body = error.response?.data;
    if (body is! ResponseBody) return error;
    final bytes = <int>[];
    final iterator = StreamIterator<Uint8List>(
      _bodyStream(body, error.requestOptions),
    );
    Object? data;
    try {
      var overflow = false;
      while (await iterator.moveNext()) {
        final chunk = iterator.current;
        if (bytes.length + chunk.length > 16384) {
          overflow = true;
          break;
        }
        bytes.addAll(chunk);
      }
      if (!overflow) data = bytes;
    } catch (_) {
      // Preserve the HTTP fact when its optional diagnostic body is unreadable.
    } finally {
      try {
        await iterator.cancel();
      } catch (_) {
        // The request's internal token closes the upstream in outer finally.
      }
    }
    return error.copyWith(
      response: Response<dynamic>(
        requestOptions: error.requestOptions,
        statusCode: error.response?.statusCode,
        headers: error.response?.headers,
        data: data,
      ),
    );
  }

  static int? _contentLength(Headers headers) {
    final values = headers[Headers.contentLengthHeader];
    if (values == null) return null;
    if (values.length != 1 ||
        RegExp(r'^\d+$').firstMatch(values.single)?.end !=
            values.single.length) {
      throw _invalidResponse();
    }
    final value = int.tryParse(values.single);
    if (value == null) throw _invalidResponse();
    return value;
  }

  // Dio's stream receive timer starts on its first chunk. Cover a server that
  // sends headers then stalls, while allowing an actively flowing long file.
  static Stream<Uint8List> _bodyStream(
    ResponseBody body,
    RequestOptions options,
  ) {
    final timeout = options.receiveTimeout;
    if (timeout == null || timeout <= Duration.zero) return body.stream;
    return body.stream.timeout(
      timeout,
      onTimeout: (sink) {
        sink.addError(
          DioException.receiveTimeout(
            timeout: timeout,
            requestOptions: options,
          ),
        );
        sink.close();
      },
    );
  }

  static bool _tag(List<int> data, int offset, String value) {
    if (data.length < offset + value.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (data[offset + i] != value.codeUnitAt(i)) return false;
    }
    return true;
  }

  static void _requireId(String id, {bool pathSegment = false}) {
    if (id.isEmpty ||
        id.trim() != id ||
        pathSegment && (id == '.' || id == '..')) {
      throw const ValidationException(
        'Не указан идентификатор записи или задачи.',
      );
    }
  }

  static ApiFailure _invalidResponse() => ApiFailure(
    'Сервер вернул некорректный файл или ответ загрузки.',
    kind: ApiFailureKind.invalidResponse,
  );
  static ApiFailure _incomplete() => ApiFailure(
    'Файл получен не полностью. Повторите загрузку.',
    kind: ApiFailureKind.incompleteTransfer,
    actions: const [ApiRecoveryAction.retryRead],
  );
}
