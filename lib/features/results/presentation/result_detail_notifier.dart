import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/lifecycle/ios_lifecycle_observer.dart';
import '../../../shared/providers/providers.dart';
import '../data/documents_api.dart';
import '../data/dto/document_kind.dart';
import '../data/dto/speech_status_dto.dart';
import '../data/pending_job_store.dart';
import '../data/speech_status_api.dart';
import 'processing_notifier.dart';

typedef ResultDetailKey = ({
  BatchSession session,
  String audioId,
  String? jobId,
});

final class ResultDetailState {
  const ResultDetailState({
    this.resolving = true,
    this.jobId,
    this.progress,
    this.error,
    this.summary = const AsyncData(null),
    this.summaryAttempted = false,
  });

  final bool resolving;
  final String? jobId;
  final JobProgress? progress;
  final AppException? error;
  final AsyncValue<String?> summary;
  final bool summaryAttempted;

  ResultDetailState copyWith({
    bool? resolving,
    String? jobId,
    JobProgress? progress,
    AppException? error,
    bool clearError = false,
    AsyncValue<String?>? summary,
    bool? summaryAttempted,
  }) => ResultDetailState(
    resolving: resolving ?? this.resolving,
    jobId: jobId ?? this.jobId,
    progress: progress ?? this.progress,
    error: clearError ? null : error ?? this.error,
    summary: summary ?? this.summary,
    summaryAttempted: summaryAttempted ?? this.summaryAttempted,
  );
}

/// A view of the shared session tracker, not another polling loop. A URL without
/// job_id resolves the latest job once, then all reads stay pinned to that job.
final class ResultDetailNotifier extends StateNotifier<ResultDetailState> {
  ResultDetailNotifier({
    required this.key,
    required ProcessingNotifier tracker,
    required SpeechStatusApi statusApi,
    required DocumentsApi documentsApi,
    required Future<Directory> Function() temporaryDirectory,
    IosLifecycleObserver? lifecycle,
  }) : _tracker = tracker,
       _statusApi = statusApi,
       _documentsApi = documentsApi,
       _temporaryDirectory = temporaryDirectory,
       _lifecycle = lifecycle,
       super(const ResultDetailState()) {
    _removeTrackerListener = _tracker.addListener(
      _progressChanged,
      fireImmediately: false,
    );
    _lifecycle?.addListener(_lifecycleChanged);
    // Never mutate the shared tracker while Riverpod builds this provider.
    unawaited(Future<void>.microtask(open));
  }

  final ResultDetailKey key;
  final ProcessingNotifier _tracker;
  final SpeechStatusApi _statusApi;
  final DocumentsApi _documentsApi;
  final Future<Directory> Function() _temporaryDirectory;
  final IosLifecycleObserver? _lifecycle;
  late final void Function() _removeTrackerListener;
  CancelToken? _resolution;
  CancelToken? _summaryRequest;
  bool _closed = false;

  // This is a local preview bound, not a restriction on server documents or
  // their later streamed export. Avoid loading an unbounded TXT into a widget.
  static const maxSummaryPreviewBytes = 2 * 1024 * 1024;

  bool get _current => mounted && !_closed && key.session.isCurrent;
  bool get _foreground => _lifecycle?.isForeground ?? true;
  ProcessingKey? get _processingKey =>
      state.jobId == null ? null : (audioId: key.audioId, jobId: state.jobId!);

  static bool _validId(String value) =>
      value.isNotEmpty &&
      value.trim() == value &&
      value != '.' &&
      value != '..';

  Future<void> open() async {
    if (!_current || !_foreground || _resolution != null) return;
    if (!_validId(key.audioId) || key.jobId != null && !_validId(key.jobId!)) {
      state = const ResultDetailState(
        resolving: false,
        error: ValidationException('Некорректный идентификатор результата.'),
      );
      return;
    }
    if (state.jobId != null) return;
    if (key.jobId case final requested?) {
      _pin(requested);
      return;
    }
    final token = CancelToken();
    _resolution = token;
    state = state.copyWith(resolving: true, clearError: true);
    try {
      final status = await _statusApi.getSpeechStatus(
        key.audioId,
        cancelToken: token,
      );
      if (!_current || !identical(_resolution, token)) return;
      _pin(status.jobId, processingVersion: status.processingVersion);
    } on AppException catch (error) {
      if (_current && identical(_resolution, token)) {
        state = state.copyWith(resolving: false, error: error);
      }
    } finally {
      if (identical(_resolution, token)) _resolution = null;
    }
  }

  void _pin(String jobId, {String? processingVersion}) {
    if (!_current) return;
    final processingKey = (audioId: key.audioId, jobId: jobId);
    if (key.session.jobs.isDeleted(processingKey)) {
      _audioRemoved();
      return;
    }
    state = state.copyWith(resolving: false, jobId: jobId, clearError: true);
    _tracker.track(
      ProcessingJob(
        ownerId: key.session.ownerId,
        audioId: key.audioId,
        jobId: jobId,
        processingVersion: processingVersion,
      ),
    );
    _progressChanged(_tracker.state);
  }

  void _progressChanged(Map<ProcessingKey, JobProgress> jobs) {
    if (!_current) {
      if (mounted && !_closed) stopSession();
      return;
    }
    final processingKey = _processingKey;
    if (processingKey == null) return;
    if (key.session.jobs.isDeleted(processingKey)) {
      _audioRemoved();
      return;
    }
    final progress = jobs[processingKey];
    if (progress == null || identical(progress, state.progress)) return;
    final error = progress.error;
    final lostAccess =
        error is NotFoundException ||
        error is ApiFailure &&
            (error.kind == ApiFailureKind.notFound ||
                error.kind == ApiFailureKind.forbidden);
    if (lostAccess) {
      _summaryRequest?.cancel();
      _summaryRequest = null;
    }
    state = state.copyWith(
      progress: progress,
      clearError: true,
      summary: lostAccess ? const AsyncData(null) : null,
      summaryAttempted: lostAccess ? false : null,
    );
    unawaited(_loadSummary());
  }

  void _audioRemoved() {
    _resolution?.cancel();
    _summaryRequest?.cancel();
    _resolution = _summaryRequest = null;
    state = const ResultDetailState(
      resolving: false,
      error: NotFoundException('Результат удалён или недоступен.'),
    );
  }

  Future<void> refresh() async {
    if (!_current || !_foreground) return;
    final processingKey = _processingKey;
    if (processingKey == null) {
      await open();
    } else {
      await _tracker.refresh(processingKey);
    }
  }

  Future<void> retrySummary() async {
    if (!_current || !_foreground || _summaryRequest != null) return;
    state = state.copyWith(summaryAttempted: false);
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (!_current ||
        !_foreground ||
        state.summaryAttempted ||
        _summaryRequest != null ||
        state.progress?.status?.summaryStatus != SummaryStatus.ready) {
      return;
    }
    final jobId = state.jobId;
    if (jobId == null) return;
    final token = CancelToken();
    _summaryRequest = token;
    state = state.copyWith(
      summary: const AsyncLoading(),
      summaryAttempted: true,
    );
    DownloadedFile? downloaded;
    String? text;
    Object? failure;
    StackTrace? failureStack;
    try {
      final directory = await _temporaryDirectory();
      if (!_current || !identical(_summaryRequest, token)) return;
      downloaded = await _documentsApi.getDocument(
        key.audioId,
        DocumentKind.summaryTxt,
        jobId: jobId,
        temporaryDirectory: directory,
        cancelToken: token,
      );
      if (!_current || !identical(_summaryRequest, token)) return;
      if (downloaded.byteLength > maxSummaryPreviewBytes) {
        throw const ValidationException(
          'Документ слишком большой для просмотра в приложении.',
        );
      }
      text = await downloaded.file.readAsString(encoding: utf8);
    } on AppException catch (error, stack) {
      failure = error;
      failureStack = stack;
    } on FormatException catch (_, stack) {
      failure = const ServerException(
        'Сервер вернул некорректный текст документа.',
      );
      failureStack = stack;
    } on FileSystemException catch (_, stack) {
      failure = const ServerException(
        'Не удалось прочитать временный документ.',
      );
      failureStack = stack;
    } catch (_, stack) {
      failure = const ServerException('Не удалось открыть временный документ.');
      failureStack = stack;
    } finally {
      try {
        await downloaded?.delete();
      } on AppException catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
      if (_current && identical(_summaryRequest, token)) {
        _summaryRequest = null;
        state = state.copyWith(
          summary: failure == null
              ? AsyncData(text)
              : AsyncError(failure, failureStack ?? StackTrace.current),
        );
      }
    }
  }

  void _lifecycleChanged() {
    if (!_current) return;
    if (!_foreground) {
      _resolution?.cancel();
      _resolution = null;
      if (_summaryRequest != null) {
        _summaryRequest!.cancel();
        _summaryRequest = null;
        state = state.copyWith(
          summary: const AsyncData(null),
          summaryAttempted: false,
        );
      }
      return;
    }
    unawaited(open());
    unawaited(_loadSummary());
  }

  void stopSession() {
    _closed = true;
    _resolution?.cancel();
    _summaryRequest?.cancel();
    _resolution = _summaryRequest = null;
    if (mounted) {
      state = const ResultDetailState(
        resolving: false,
        error: UnauthorizedException(),
      );
    }
  }

  @override
  void dispose() {
    _removeTrackerListener();
    _lifecycle?.removeListener(_lifecycleChanged);
    stopSession();
    super.dispose();
  }
}

final resultDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<ResultDetailNotifier, ResultDetailState, ResultDetailKey>((
      ref,
      key,
    ) {
      final notifier = ResultDetailNotifier(
        key: key,
        tracker: ref.watch(
          processingNotifierProvider(key.session.processingSession).notifier,
        ),
        statusApi: ref.read(speechStatusApiProvider),
        documentsApi: ref.read(documentsApiProvider),
        temporaryDirectory: ref.read(resultTemporaryDirectoryProvider),
        lifecycle: ref.read(iosLifecycleObserverProvider),
      );
      ref.listen(batchSessionProvider, (_, __) {
        if (!key.session.isCurrent) notifier.stopSession();
      });
      return notifier;
    });
