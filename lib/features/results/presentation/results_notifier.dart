import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/results_api.dart';
import '../data/dto/result_dto.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum ResultsStatus { idle, loading, loaded, error }

class ResultsState {
  final ResultsStatus status;
  final List<ResultDto> results;
  final String? errorMessage;
  final bool isStubError;
  // PDF download states: audioId → true/false (loading)
  final Map<String, bool> downloadingPdf;

  const ResultsState({
    this.status = ResultsStatus.idle,
    this.results = const [],
    this.errorMessage,
    this.isStubError = false,
    this.downloadingPdf = const {},
  });

  ResultsState copyWith({
    ResultsStatus? status,
    List<ResultDto>? results,
    String? errorMessage,
    bool? isStubError,
    Map<String, bool>? downloadingPdf,
  }) =>
      ResultsState(
        status: status ?? this.status,
        results: results ?? this.results,
        errorMessage: errorMessage,
        isStubError: isStubError ?? this.isStubError,
        downloadingPdf: downloadingPdf ?? this.downloadingPdf,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ResultsNotifier extends StateNotifier<ResultsState> {
  final ResultsApi _api;

  ResultsNotifier(this._api) : super(const ResultsState()) {
    load();
  }

  Future<void> load({
    DateTime? from,
    DateTime? to,
  }) async {
    state = state.copyWith(
      status: ResultsStatus.loading,
      errorMessage: null,
    );
    try {
      final list = await _api.getResults(
        startDate: from,
        endDate: to,
      );
      state = state.copyWith(
        status: ResultsStatus.loaded,
        results: list,
      );
    } on StubException catch (e) {
      state = state.copyWith(
        status: ResultsStatus.error,
        errorMessage: e.message,
        isStubError: true,
      );
    } on AppException catch (e) {
      state = state.copyWith(
        status: ResultsStatus.error,
        errorMessage: e.message,
        isStubError: false,
      );
    }
  }

  Future<bool> delete(String audioId) async {
    try {
      await _api.deleteResult(audioId);
      state = state.copyWith(
        results:
            state.results.where((r) => r.audioId != audioId).toList(),
      );
      return true;
    } on StubException catch (e) {
      state = state.copyWith(
        errorMessage: e.message,
        isStubError: true,
      );
      return false;
    } on AppException catch (e) {
      state = state.copyWith(
        errorMessage: e.message,
        isStubError: false,
      );
      return false;
    }
  }

  Future<void> downloadSummary(String audioId, String fileName) async {
    _setDownloading(audioId, true);
    try {
      final bytes = await _api.getSummaryPdf(audioId);
      await _saveBytes(bytes, '${fileName}_summary.pdf');
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } finally {
      _setDownloading(audioId, false);
    }
  }

  Future<void> downloadTranscript(String audioId, String fileName) async {
    _setDownloading(audioId, true);
    try {
      final bytes = await _api.getTranscriptPdf(audioId);
      await _saveBytes(bytes, '${fileName}_transcript.pdf');
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message);
    } finally {
      _setDownloading(audioId, false);
    }
  }

  void _setDownloading(String audioId, bool value) {
    final map = Map<String, bool>.from(state.downloadingPdf);
    map[audioId] = value;
    state = state.copyWith(downloadingPdf: map);
  }

  /// Сохраняет байты во временный файл Downloads и открывает его.
  Future<void> _saveBytes(List<int> bytes, String fileName) async {
    final dir = Platform.isWindows
        ? '${Platform.environment['USERPROFILE']}\\Downloads'
        : Platform.isMacOS
            ? '${Platform.environment['HOME']}/Downloads'
            : '/tmp';
    final file = File('$dir/$fileName');
    await file.writeAsBytes(bytes);
    final uri = Uri.file(file.path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void clearError() => state = state.copyWith(
        errorMessage: null,
        isStubError: false,
      );
}

final resultsNotifierProvider =
    StateNotifierProvider<ResultsNotifier, ResultsState>((ref) {
  return ResultsNotifier(ref.read(resultsApiProvider));
});
