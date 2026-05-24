import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/results_api.dart';
import '../data/dto/result_dto.dart';
import '../../../core/error/app_exception.dart';
import '../../../shared/providers/providers.dart';

enum ResultsStatus { idle, loading, loaded, error }

class ResultsState {
  final ResultsStatus status;
  final List<ResultDto> results;
  final String? errorMessage;
  final bool isStubError;
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

class ResultsNotifier extends StateNotifier<ResultsState> {
  final ResultsApi _api;
  Timer? _pollTimer;

  ResultsNotifier(this._api) : super(const ResultsState()) {
    load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> load({DateTime? from, DateTime? to}) async {
    state = state.copyWith(status: ResultsStatus.loading, errorMessage: null);
    try {
      final list = await _api.getResults(startDate: from, endDate: to);
      state = state.copyWith(status: ResultsStatus.loaded, results: list);
      _schedulePollIfNeeded();
    } on StubException catch (e) {
      state = state.copyWith(status: ResultsStatus.error, errorMessage: e.message, isStubError: true);
    } on AppException catch (e) {
      state = state.copyWith(status: ResultsStatus.error, errorMessage: e.message, isStubError: false);
    }
  }

  void _schedulePollIfNeeded() {
    final hasPending = state.results.any((r) => r.status == 'pending');
    if (hasPending && _pollTimer == null) {
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    } else if (!hasPending) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _poll() async {
    try {
      final list = await _api.getResults();
      state = state.copyWith(results: list);
      _schedulePollIfNeeded();
    } catch (_) {}
  }

  Future<bool> delete(String audioId) async {
    try {
      await _api.deleteResult(audioId);
      state = state.copyWith(results: state.results.where((r) => r.audioId != audioId).toList());
      return true;
    } on StubException catch (e) {
      state = state.copyWith(errorMessage: e.message, isStubError: true);
      return false;
    } on AppException catch (e) {
      state = state.copyWith(errorMessage: e.message, isStubError: false);
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

  Future<void> downloadAudio(String audioId) async {
    _setDownloading(audioId, true);
    try {
      final bytes = await _api.getAudio(audioId);
      await _saveBytes(bytes, '${audioId.substring(0, 8)}_audio.mp3');
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

  Future<void> _saveBytes(List<int> bytes, String fileName) async {
    final dir = Platform.isWindows
        ? '${Platform.environment['USERPROFILE']}\\Downloads'
        : Platform.isMacOS
            ? '${Platform.environment['HOME']}/Downloads'
            : '/tmp';
    final file = File('$dir/$fileName');
    await file.writeAsBytes(bytes);
    if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    } else {
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null, isStubError: false);
}

final resultsNotifierProvider =
    StateNotifierProvider<ResultsNotifier, ResultsState>((ref) {
  return ResultsNotifier(ref.read(resultsApiProvider));
});
