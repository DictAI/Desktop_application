import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';
import '../../record/data/dto/pending_upload.dart';
import '../../record/data/pending_upload_store.dart';
import '../data/dto/results_page_dto.dart';
import '../data/pending_job_store.dart';
import '../data/results_api.dart';
import 'processing_notifier.dart';

typedef ResultsDateFilter = ({DateTime start, DateTime end});

final class ResultsState {
  const ResultsState({
    this.page = const AsyncLoading(),
    this.uploads = const AsyncLoading(),
    this.pageNumber = 1,
    this.dates,
    this.sending = const {},
    this.deleting = const {},
    this.blockedReplays = const {},
    this.actionMessage,
    this.actionFailed = false,
  });

  final AsyncValue<ResultsPageDto> page;
  final AsyncValue<PendingUploadListing> uploads;
  final int pageNumber;
  final ResultsDateFilter? dates;
  final Set<String> sending;
  final Set<String> deleting;
  final Map<String, String> blockedReplays;
  final String? actionMessage;
  final bool actionFailed;

  ResultsState copyWith({
    AsyncValue<ResultsPageDto>? page,
    AsyncValue<PendingUploadListing>? uploads,
    int? pageNumber,
    ResultsDateFilter? dates,
    bool clearDates = false,
    Set<String>? sending,
    Set<String>? deleting,
    Map<String, String>? blockedReplays,
    String? actionMessage,
    bool actionFailed = false,
    bool clearAction = false,
  }) => ResultsState(
    page: page ?? this.page,
    uploads: uploads ?? this.uploads,
    pageNumber: pageNumber ?? this.pageNumber,
    dates: clearDates ? null : dates ?? this.dates,
    sending: sending ?? this.sending,
    deleting: deleting ?? this.deleting,
    blockedReplays: blockedReplays ?? this.blockedReplays,
    actionMessage: clearAction ? null : actionMessage ?? this.actionMessage,
    actionFailed: clearAction
        ? false
        : actionMessage == null
        ? this.actionFailed
        : actionFailed,
  );
}

final class ResultsNotifier extends StateNotifier<ResultsState> {
  ResultsNotifier(this._api, this._session, this._tracker)
    : super(const ResultsState()) {
    unawaited(_session.cancelToken.whenCancel.then((_) => _cancelRequests()));
    unawaited(refresh());
  }

  final ResultsApi _api;
  final BatchSession _session;
  final ProcessingNotifier _tracker;
  CancelToken? _pageRequest;
  final _deletions = <CancelToken>{};
  final _pruning = <String>{};
  int _journalRequest = 0;
  bool _hasOpened = false;
  static const _pageSize = 20;

  bool get _current => mounted && _session.isCurrent;

  Future<void> refresh() async {
    if (!_current) return;
    await Future.wait([_readPage(), _readJournal()]);
  }

  /// The first mount shares the constructor load. Subsequent visits see new
  /// uploads while retaining the current page and selected dates.
  Future<void> openLibrary() async {
    if (!_current) return;
    if (_hasOpened) {
      await refresh();
    } else {
      _hasOpened = true;
    }
  }

  Future<void> goToPage(int pageNumber) async {
    if (!_current) return;
    final pagination = state.page.asData?.value.pagination;
    if (pagination == null ||
        pageNumber < 1 ||
        pageNumber > pagination.totalPages ||
        pageNumber == state.pageNumber) {
      return;
    }
    state = state.copyWith(pageNumber: pageNumber);
    await _readPage();
  }

  Future<void> setDates(ResultsDateFilter? dates) async {
    if (!_current) return;
    if (dates != null && dates.end.isBefore(dates.start)) return;
    state = state.copyWith(
      dates: dates,
      clearDates: dates == null,
      pageNumber: 1,
    );
    await _readPage();
  }

  Future<void> _readPage() async {
    if (!_current) return;
    _pageRequest?.cancel();
    final request = CancelToken();
    _pageRequest = request;
    final dates = state.dates;
    var pageNumber = state.pageNumber;
    state = state.copyWith(page: const AsyncLoading());

    bool current() => _current && identical(_pageRequest, request);
    // R01 uses inclusive RFC3339 bounds. Local calendar midnight (including
    // DST) is converted to UTC by ResultsApi, without date-only truncation.
    final start = dates == null
        ? null
        : DateTime(dates.start.year, dates.start.month, dates.start.day);
    final end = dates == null
        ? null
        : DateTime(
            dates.end.year,
            dates.end.month,
            dates.end.day + 1,
          ).subtract(const Duration(microseconds: 1));
    Future<ResultsPageDto> fetch(int page) => _api.getResultsPage(
      startDate: start,
      endDate: end,
      page: page,
      limit: _pageSize,
      cancelToken: request,
    );

    try {
      var page = await fetch(pageNumber);
      if (!current()) return;
      final last = page.pagination.totalPages;
      // A deletion can shrink the page count. Clamp only when the requested
      // page is no longer valid, and perform at most one corrective read.
      if (pageNumber > last && pageNumber > 1) {
        pageNumber = last == 0 ? 1 : last;
        page = await fetch(pageNumber);
        if (!current()) return;
      }
      state = state.copyWith(
        pageNumber: pageNumber,
        page: AsyncData(
          ResultsPageDto(
            data: List.unmodifiable(
              page.data.where(
                (row) =>
                    row.uploadUserId == _session.ownerId &&
                    !_session.jobs.isDeleted((
                      audioId: row.audioId,
                      jobId: row.resultId,
                    )),
              ),
            ),
            pagination: page.pagination,
          ),
        ),
      );
      await _reconcileJobs();
    } on AppException catch (error, stack) {
      if (current()) {
        state = state.copyWith(page: AsyncError(error, stack));
      }
    }
  }

  Future<void> _readJournal() async {
    final request = ++_journalRequest;
    bool current() => _current && request == _journalRequest;
    try {
      final listing = await _session.uploads.list();
      if (!current()) return;
      state = state.copyWith(uploads: AsyncData(listing));
      await _reconcileJobs();
    } on AppException catch (error, stack) {
      if (current()) {
        state = state.copyWith(uploads: AsyncError(error, stack));
        await _reconcileJobs();
      }
    }
  }

  Future<void> _reconcileJobs() async {
    if (!_current) return;
    if (state.uploads.isLoading) return;
    final entries =
        state.uploads.asData?.value.entries ?? const <PendingUpload>[];
    // Start richer receipts before R01 fallback. In particular, R01 cannot
    // reconstruct an anonymous upload's U03 session ID.
    for (final upload in entries) {
      final accepted = upload.accepted;
      if (accepted != null &&
          !_session.jobs.isDeleted((
            audioId: accepted.audioId,
            jobId: accepted.jobId,
          ))) {
        _tracker.track(_session.jobs.fromAccepted(upload));
      }
    }
    final page = state.page.asData?.value;
    if (page == null) return;
    final confirmed = {
      for (final row in page.data)
        (audioId: row.audioId, jobId: row.resultId): row.status,
    };
    // Server-only pending jobs survive receipt pruning and app restart. Ready
    // rows don't need to prefetch a potentially large transcript in the list.
    for (final row in page.data.where((row) => row.status == 'pending')) {
      _tracker.track(
        ProcessingJob(
          ownerId: _session.ownerId,
          audioId: row.audioId,
          jobId: row.resultId,
        ),
      );
    }
    for (final entry in entries) {
      if (!_current) return;
      final receipt = entry.accepted;
      final status = receipt == null
          ? null
          : confirmed[(audioId: receipt.audioId, jobId: receipt.jobId)];
      if (entry.state != PendingUploadState.accepted ||
          receipt == null ||
          entry.ownerId != _session.ownerId ||
          status == null ||
          (receipt.sessionId != null &&
              status != 'done' &&
              status != 'failed') ||
          !_pruning.add(entry.localId)) {
        continue;
      }
      try {
        await _session.uploads.forgetAccepted(entry.localId);
        if (!_current) return;
        final current = state.uploads.asData?.value;
        if (current != null) {
          state = state.copyWith(
            uploads: AsyncData(
              PendingUploadListing(
                current.entries
                    .where((upload) => upload.localId != entry.localId)
                    .toList(),
                current.damagedEntries,
              ),
            ),
          );
        }
      } on AppException {
        // R01 already supplied the result. An unavailable journal must not
        // erase the server page or offer a new POST for this receipt.
        if (_current && state.actionMessage == null) {
          state = state.copyWith(
            actionMessage: 'Не удалось освободить место в журнале отправок.',
            actionFailed: true,
          );
        }
      } finally {
        _pruning.remove(entry.localId);
      }
    }
  }

  Future<void> replay(String localId) async {
    if (!_current ||
        state.sending.contains(localId) ||
        state.blockedReplays.containsKey(localId)) {
      return;
    }
    final listing = state.uploads.asData?.value;
    if (listing == null ||
        !listing.entries.any(
          (entry) =>
              entry.localId == localId &&
              entry.state == PendingUploadState.pending,
        )) {
      return;
    }
    state = state.copyWith(
      sending: Set.unmodifiable({...state.sending, localId}),
      clearAction: true,
    );
    try {
      // submit re-reads the durable receipt and verifies the owned WAV and
      // original key. An already accepted receipt returns without a new POST.
      await _session.submit(localId);
      if (!_current) return;
      state = state.copyWith(actionMessage: 'Отправка принята сервером.');
      await refresh();
    } on AppException catch (error) {
      if (!_current) return;
      state = state.copyWith(
        actionMessage: error.message,
        actionFailed: true,
        blockedReplays: PendingUploadStore.isUnrecoverableReplayError(error)
            ? Map.unmodifiable({
                ...state.blockedReplays,
                localId: error.message,
              })
            : null,
      );
      await _readJournal();
    } finally {
      if (_current) {
        state = state.copyWith(
          sending: Set.unmodifiable(state.sending.where((id) => id != localId)),
        );
      }
    }
  }

  Future<void> delete(String audioId) async {
    if (!_current || state.deleting.contains(audioId)) return;
    final request = CancelToken();
    _deletions.add(request);
    state = state.copyWith(
      deleting: Set.unmodifiable({...state.deleting, audioId}),
      clearAction: true,
    );
    try {
      await _api.deleteResult(audioId, cancelToken: request);
      if (!_current) return;
      _tracker.removeAudio(audioId);
      await _readPage();
    } on AppException catch (error) {
      if (_current) {
        state = state.copyWith(
          actionMessage: error.message,
          actionFailed: true,
        );
      }
    } finally {
      _deletions.remove(request);
      if (_current) {
        state = state.copyWith(
          deleting: Set.unmodifiable(
            state.deleting.where((id) => id != audioId),
          ),
        );
      }
    }
  }

  void clearAction() {
    if (_current) state = state.copyWith(clearAction: true);
  }

  void _cancelRequests() {
    _pageRequest?.cancel();
    for (final request in _deletions) {
      request.cancel();
    }
  }

  @override
  void dispose() {
    _cancelRequests();
    super.dispose();
  }
}

// Filters survive navigation within this account. Replacing the batch session
// disposes the library and fences old reads and mutations.
final resultsNotifierProvider = StateNotifierProvider.autoDispose
    .family<ResultsNotifier, ResultsState, BatchSession>((ref, session) {
      final keepAlive = ref.keepAlive();
      ref.listen(batchSessionProvider, (_, next) {
        if (!identical(next.asData?.value, session)) keepAlive.close();
      });
      return ResultsNotifier(
        ref.read(resultsApiProvider),
        session,
        ref.read(
          processingNotifierProvider(session.processingSession).notifier,
        ),
      );
    });
