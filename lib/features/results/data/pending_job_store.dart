import '../../../core/error/app_exception.dart';
import '../../record/data/dto/pending_upload.dart';
import '../../record/data/pending_upload_store.dart';
import 'dto/result_dto.dart';

typedef ProcessingKey = ({String audioId, String jobId});

/// A reference to an existing job, never a new processing command.
final class ProcessingJob {
  const ProcessingJob({
    required this.ownerId,
    required this.audioId,
    required this.jobId,
    this.processingVersion,
    this.sessionId,
  });
  final String ownerId, audioId, jobId;
  final String? processingVersion, sessionId;
  ProcessingKey get key => (audioId: audioId, jobId: jobId);
}

/// Reuses the durable acceptance receipts from .20. No second journal, token,
/// transcript cache or invented processing version is stored here.
final class PendingJobStore {
  PendingJobStore({
    required this.uploads,
    required bool Function() isCurrentSession,
  }) : _isCurrentSession = isCurrentSession;

  final PendingUploadStore uploads;
  final bool Function() _isCurrentSession;
  final _deleted = <ProcessingKey>{};
  final _deletedAudio = <String>{};
  String get ownerId => uploads.ownerId;

  void _check() {
    if (!_isCurrentSession()) throw const UnauthorizedException();
  }

  bool isDeleted(ProcessingKey key) =>
      _deleted.contains(key) || _deletedAudio.contains(key.audioId);

  void markDeleted(String audioId) {
    _check();
    _deletedAudio.add(audioId);
  }

  ProcessingJob fromAccepted(PendingUpload entry) {
    _check();
    final accepted = entry.accepted;
    if (entry.ownerId != ownerId ||
        entry.state != PendingUploadState.accepted ||
        accepted == null) {
      throw const ValidationException('Отправка ещё не принята сервером.');
    }
    final job = ProcessingJob(
      ownerId: ownerId,
      audioId: accepted.audioId,
      jobId: accepted.jobId,
      processingVersion: accepted.processingVersion,
      sessionId: accepted.sessionId,
    );
    if (isDeleted(job.key)) {
      throw const NotFoundException('Результат удалён.');
    }
    return job;
  }

  /// R01 is supplied by Results with its current page/filters. Missing rows in
  /// a page are not evidence of deletion. R03 resolves its unknown version.
  Future<List<ProcessingJob>> recover({
    Iterable<ResultDto> results = const [],
  }) async {
    _check();
    final listing = await uploads.list();
    _check();
    final jobs = <ProcessingKey, ProcessingJob>{};
    for (final entry in listing.entries) {
      if (entry.state == PendingUploadState.accepted) {
        final receipt = entry.accepted!;
        final key = (audioId: receipt.audioId, jobId: receipt.jobId);
        if (!isDeleted(key)) jobs[key] = fromAccepted(entry);
      }
    }
    for (final result in results) {
      if (result.uploadUserId != ownerId ||
          result.audioId.isEmpty ||
          result.resultId.isEmpty) {
        continue;
      }
      final key = (audioId: result.audioId, jobId: result.resultId);
      if (!isDeleted(key)) {
        jobs.putIfAbsent(
          key,
          () => ProcessingJob(
            ownerId: ownerId,
            audioId: result.audioId,
            jobId: result.resultId,
          ),
        );
      }
    }
    _check();
    return List.unmodifiable(jobs.values);
  }

  /// Called after confirmed R02 deletion, before awaiting local cleanup. All
  /// jobs of that audio are fenced so stale Results pages cannot restore them.
  Future<void> forgetAudio(
    String audioId, {
    Iterable<ProcessingKey> known = const [],
  }) async {
    _check();
    markDeleted(audioId);
    _deleted.addAll(known.where((key) => key.audioId == audioId));
    final listing = await uploads.list();
    _check();
    for (final entry in listing.entries) {
      final receipt = entry.accepted;
      if (receipt != null && receipt.audioId == audioId) {
        _deleted.add((audioId: audioId, jobId: receipt.jobId));
        await uploads.forgetAccepted(entry.localId);
        _check();
      }
    }
  }
}
