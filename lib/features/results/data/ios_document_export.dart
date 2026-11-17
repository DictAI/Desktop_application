import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/error/app_exception.dart';
import 'documents_api.dart';
import 'dto/document_kind.dart';
import 'dto/speech_status_dto.dart';

enum IosExportKind {
  transcriptTxt('Транскрипт TXT', DocumentKind.transcriptTxt),
  transcriptPdf('Транскрипт PDF', DocumentKind.transcriptPdf),
  summaryTxt('Краткое содержание TXT', DocumentKind.summaryTxt),
  summaryPdf('Краткое содержание PDF', DocumentKind.summaryPdf),
  original('Исходная запись WAV', null);

  const IosExportKind(this.label, this.document);
  final String label;
  final DocumentKind? document;
  String get contentType => document?.contentType ?? 'audio/wav';

  /// Status permits trying the download. Each individual document must still
  /// return a validated 200 before it can reach the system activity sheet.
  bool canRequest(SpeechStatusDto? status) => switch (this) {
    transcriptTxt ||
    transcriptPdf => status?.transcriptStatus == TranscriptStatus.ready,
    summaryTxt || summaryPdf => status?.summaryStatus == SummaryStatus.ready,
    original => status != null && status.jobStatus != SpeechJobStatus.unknown,
  };
}

enum IosShareOutcome { completed, cancelled }

abstract interface class IosShareSheet {
  Future<IosShareOutcome> present({
    required String id,
    required File file,
    required String contentType,
    VoidCallback? onPresented,
  });
  Future<void> cancel(String id);
}

/// One application-wide channel owner. Native code rejects overlapping sheets;
/// a cancellation always carries the identity of the sheet it belongs to.
final class NativeIosShareSheet implements IosShareSheet {
  NativeIosShareSheet({
    MethodChannel channel = const MethodChannel(
      'com.dictai/ios_document_export',
    ),
  }) : _channel = channel {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'presented' && call.arguments is String) {
        _presented[call.arguments]?.call();
      }
    });
  }
  final MethodChannel _channel;
  final _presented = <String, VoidCallback>{};

  @override
  Future<IosShareOutcome> present({
    required String id,
    required File file,
    required String contentType,
    VoidCallback? onPresented,
  }) async {
    if (onPresented != null) _presented[id] = onPresented;
    try {
      final value = await _channel.invokeMethod<String>('share', {
        'id': id,
        'path': file.path,
        'contentType': contentType,
      });
      return switch (value) {
        'completed' => IosShareOutcome.completed,
        'cancelled' => IosShareOutcome.cancelled,
        _ => throw const ServerException('Не удалось завершить экспорт файла.'),
      };
    } on PlatformException {
      throw const ServerException(
        'Не удалось открыть системный экспорт файла.',
      );
    } on MissingPluginException {
      throw const ServerException('Системный экспорт файла недоступен.');
    } finally {
      _presented.remove(id);
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on PlatformException {
      throw const ServerException(
        'Не удалось закрыть системный экспорт файла.',
      );
    } on MissingPluginException {
      throw const ServerException('Системный экспорт файла недоступен.');
    }
  }
}

/// Owns only staging bytes. The file stays alive until UIKit's activity has
/// completed, including when its Flutter screen or login session disappears.
final class IosDocumentExporter extends ChangeNotifier {
  IosDocumentExporter({
    required DocumentsApi api,
    required IosShareSheet sheet,
    required Future<Directory> Function() temporaryDirectory,
    required bool Function() isCurrentSession,
    Future<void> Function(Directory)? prepareDirectory,
    Future<void> Function(DownloadedFile)? deleteDownloaded,
  }) : _api = api,
       _sheet = sheet,
       _temporaryDirectory = temporaryDirectory,
       _isCurrentSession = isCurrentSession,
       _prepareDirectory = prepareDirectory,
       _deleteDownloaded = deleteDownloaded ?? _delete;

  final DocumentsApi _api;
  final IosShareSheet _sheet;
  final Future<Directory> Function() _temporaryDirectory;
  final bool Function() _isCurrentSession;
  final Future<void> Function(Directory)? _prepareDirectory;
  final Future<void> Function(DownloadedFile) _deleteDownloaded;
  static Future<void> _delete(DownloadedFile file) => file.delete();
  static int _nextId = 0;
  Future<IosShareOutcome>? _operation;
  Future<void>? _closing;
  Future<void>? _cleaning;
  CancelToken? _transfer;
  Directory? _directory;
  DownloadedFile? _download;
  String? _sheetId;
  bool _cancelled = false;
  bool _closed = false;
  bool _disposed = false;
  bool get busy => _operation != null;
  bool get needsCleanup => !busy && _directory != null;
  bool get _current => !_closed && !_cancelled && _isCurrentSession();
  String? errorMessage;
  String? message;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<IosShareOutcome> share({
    required String audioId,
    required String jobId,
    required IosExportKind kind,
    required SpeechStatusDto status,
    VoidCallback? onPresented,
  }) {
    if (busy || _directory != null) {
      return Future.error(
        const ValidationException('Сначала завершите текущий экспорт файла.'),
      );
    }
    if (_closed || !_isCurrentSession()) {
      return Future.error(const UnauthorizedException());
    }
    if (status.jobId != jobId || !kind.canRequest(status)) {
      return Future.error(const ValidationException('Документ ещё не готов.'));
    }
    _cancelled = false;
    errorMessage = message = null;
    final operation = _perform(
      audioId: audioId,
      jobId: jobId,
      kind: kind,
      onPresented: onPresented,
    );
    _operation = operation;
    _publish();
    return operation;
  }

  Future<IosShareOutcome> _perform({
    required String audioId,
    required String jobId,
    required IosExportKind kind,
    VoidCallback? onPresented,
  }) async {
    var outcome = IosShareOutcome.cancelled;
    Object? failure;
    final token = CancelToken();
    _transfer = token;
    try {
      final temporary = await _temporaryDirectory();
      if (!_current) throw const UnauthorizedException();
      final directory = await temporary.createTemp('dictai-export-');
      _directory = directory;
      await _prepareDirectory?.call(directory);
      if (!_current) throw const UnauthorizedException();
      final document = kind.document;
      _download = document != null
          ? await _api.getDocument(
              audioId,
              document,
              jobId: jobId,
              temporaryDirectory: directory,
              cancelToken: token,
            )
          : await _api.getOriginal(
              audioId,
              temporaryDirectory: directory,
              cancelToken: token,
            );
      if (!_current) throw const UnauthorizedException();
      final id = 'export-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
      _sheetId = id;
      try {
        outcome = await _sheet.present(
          id: id,
          file: _download!.file,
          contentType: kind.contentType,
          onPresented: onPresented,
        );
      } finally {
        _sheetId = null;
      }
      if (!_current) outcome = IosShareOutcome.cancelled;
    } catch (error) {
      if (!_cancelled && !_closed && _isCurrentSession()) failure = error;
    } finally {
      _transfer = null;
      try {
        await _cleanup();
      } on AppException catch (error) {
        failure = error;
      }
      if (failure != null) {
        errorMessage = failure is AppException
            ? failure.message
            : 'Не удалось экспортировать файл.';
      } else if (!_closed) {
        message = outcome == IosShareOutcome.completed
            ? 'Файл передан выбранному приложению.'
            : 'Экспорт отменён.';
      }
      _operation = null;
      _publish();
    }
    if (failure != null) {
      throw failure is AppException
          ? failure
          : const ServerException('Не удалось экспортировать файл.');
    }
    return outcome;
  }

  Future<void> cancel() async {
    _cancelled = true;
    _transfer?.cancel();
    final id = _sheetId;
    if (id != null) {
      try {
        await _sheet.cancel(id);
      } on AppException catch (error) {
        errorMessage = error.message;
        _publish();
        rethrow;
      }
    }
  }

  Future<void> _cleanup() => _cleaning ??= () async {
    try {
      await _cleanupOwned();
    } finally {
      _cleaning = null;
    }
  }();

  Future<void> _cleanupOwned() async {
    try {
      if (_download case final downloaded?) {
        await _deleteDownloaded(downloaded);
        _download = null;
      }
      if (_directory case final directory?) {
        if (await directory.exists()) await directory.delete(recursive: true);
        _directory = null;
      }
    } on FileSystemException {
      throw const ServerException(
        'Не удалось удалить временный файл экспорта.',
      );
    }
  }

  Future<void> retryCleanup() async {
    if (busy) return;
    try {
      await _cleanup();
      errorMessage = null;
    } on AppException catch (error) {
      errorMessage = error.message;
    }
    _publish();
  }

  Future<void> close() => _closing ??= () async {
    _closed = true;
    try {
      await cancel();
    } on AppException {
      // A failed cancellation does not prove the system has released its file.
      // Continue waiting for the original activity completion before cleanup.
    }
    try {
      await _operation;
    } on AppException {
      // The original operation already recorded a safe error.
    }
    try {
      await _cleanup();
    } finally {
      _closing = null;
    }
  }();

  @override
  void dispose() {
    _disposed = true;
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
