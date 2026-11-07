import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../record/data/dto/v2_session_dto.dart';
import '../data/canonical_api.dart';
import '../data/dto/canonical_transcript_dto.dart';
import '../data/dto/result_dto.dart';
import '../data/dto/speech_status_dto.dart';
import '../data/pending_job_store.dart';
import '../data/speech_status_api.dart';

enum ProcessingPhase {
  waiting,
  ready,
  failed,
  cancelled,
  expired,
  unavailable,
  unsupported,
}

/// Keep one instance for a logical owner/session. Invalidate that instance
/// synchronously on logout before opening a tracker for another account.
final class ProcessingSession {
  const ProcessingSession({
    required this.store,
    required this.isCurrentSession,
  });
  final PendingJobStore store;
  final bool Function() isCurrentSession;
}

final class JobProgress {
  const JobProgress({
    required this.job,
    this.phase = ProcessingPhase.waiting,
    this.status,
    this.canonical,
    this.error,
    this.retryIn,
  });
  final ProcessingJob job;
  final ProcessingPhase phase;
  final SpeechStatusDto? status;
  final CanonicalTranscriptDto? canonical;
  final AppException? error;
  final Duration? retryIn;
  bool get canonicalReady => canonical != null;
}

/// Session-bound tracker. Timers are scheduled after a read finishes, never
/// periodic or in widget build. Navigation belongs to .48.
final class ProcessingNotifier
    extends StateNotifier<Map<ProcessingKey, JobProgress>> {
  ProcessingNotifier({
    required this.store,
    required SpeechStatusApi statusApi,
    required CanonicalApi canonicalApi,
    required bool Function() isCurrentSession,
    this.pollInterval = const Duration(seconds: 3),
    this.maxBackoff = const Duration(seconds: 60),
    this.maxConcurrent = 4,
  }) : _statusApi = statusApi,
       _canonicalApi = canonicalApi,
       _isCurrentSession = isCurrentSession,
       super(const {}) {
    if (pollInterval <= Duration.zero ||
        maxBackoff < pollInterval ||
        maxConcurrent < 1) {
      throw ArgumentError('Invalid polling limits');
    }
  }

  final PendingJobStore store;
  final SpeechStatusApi _statusApi;
  final CanonicalApi _canonicalApi;
  final bool Function() _isCurrentSession;
  final Duration pollInterval, maxBackoff;
  final int maxConcurrent;
  final _timers = <ProcessingKey, Timer>{};
  final _tokens = <ProcessingKey, CancelToken>{};
  final _failures = <ProcessingKey, int>{};
  int _generation = 0;
  bool _stopped = false;

  bool _current(int generation, ProcessingKey key) =>
      mounted &&
      !_stopped &&
      _generation == generation &&
      _isCurrentSession() &&
      !store.isDeleted(key) &&
      state.containsKey(key);

  bool _active(int generation, ProcessingKey key, CancelToken token) =>
      _current(generation, key) && identical(_tokens[key], token);

  void track(ProcessingJob job) {
    if (!mounted ||
        _stopped ||
        !_isCurrentSession() ||
        job.ownerId != store.ownerId ||
        store.isDeleted(job.key) ||
        state.containsKey(job.key)) {
      return;
    }
    state = Map.unmodifiable({...state, job.key: JobProgress(job: job)});
    unawaited(refresh(job.key));
  }

  Future<void> restore({Iterable<ResultDto> results = const []}) async {
    final generation = _generation;
    final jobs = await store.recover(results: results);
    if (!mounted || generation != _generation || !_isCurrentSession()) return;
    for (final job in jobs) {
      track(job);
    }
  }

  void _publish(int generation, JobProgress progress, CancelToken token) {
    if (_active(generation, progress.job.key, token)) {
      state = Map.unmodifiable({...state, progress.job.key: progress});
    }
  }

  void _schedule(int generation, ProcessingKey key, Duration delay) {
    if (!_current(generation, key)) return;
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(delay, () {
      _timers.remove(key);
      unawaited(refresh(key));
    });
  }

  Future<void> refresh(ProcessingKey key) async {
    final generation = _generation;
    if (!_current(generation, key) || _tokens.containsKey(key)) return;
    if (_tokens.length >= maxConcurrent) {
      _schedule(generation, key, pollInterval);
      return;
    }
    _timers.remove(key)?.cancel();
    final token = CancelToken();
    _tokens[key] = token;
    final previous = state[key]!;
    var job = previous.job;
    Duration? next;
    try {
      var status = await _statusApi.getSpeechStatus(
        job.audioId,
        jobId: job.jobId,
        cancelToken: token,
      );
      if (!_active(generation, key, token)) return;
      if (job.processingVersion != null &&
          status.processingVersion != job.processingVersion) {
        throw _invalid;
      }
      job = ProcessingJob(
        ownerId: job.ownerId,
        audioId: job.audioId,
        jobId: job.jobId,
        processingVersion: status.processingVersion,
        sessionId: job.sessionId,
      );
      var phase = _phase(status);
      var canonical = previous.canonical;
      if (status.transcriptStatus == TranscriptStatus.ready &&
          canonical == null) {
        final response = await _canonicalApi.getTranscript(
          job.audioId,
          jobId: job.jobId,
          cancelToken: token,
        );
        if (!_active(generation, key, token)) return;
        switch (response) {
          case CanonicalReady(:final transcript):
            if (transcript.access.ownerUserId != job.ownerId ||
                transcript.processingVersion != status.processingVersion) {
              throw _invalid;
            }
            canonical = transcript;
            phase = ProcessingPhase.ready;
          case CanonicalStatus(status: final canonicalStatus):
            if (canonicalStatus.processingVersion != status.processingVersion) {
              throw _invalid;
            }
            status = canonicalStatus;
            phase = _phase(status);
          case CanonicalUnavailable(:final failure):
            throw failure;
        }
      }
      // Anonymous session TTL can expire while an owner-authorized canonical
      // remains readable. U03 only controls waiting for a still-pending result.
      if (job.sessionId != null &&
          canonical == null &&
          phase == ProcessingPhase.waiting) {
        final session = await _statusApi.getAnonymousSession(
          job.sessionId!,
          cancelToken: token,
        );
        if (!_active(generation, key, token)) return;
        if (session.audioId != job.audioId ||
            session.jobId != job.jobId ||
            job.processingVersion != null &&
                session.processingVersion != job.processingVersion) {
          throw _invalid;
        }
        final phase = switch (session.status) {
          V2SessionStatus.failed => ProcessingPhase.failed,
          V2SessionStatus.cancelled => ProcessingPhase.cancelled,
          V2SessionStatus.expired => ProcessingPhase.expired,
          V2SessionStatus.unknown => ProcessingPhase.unsupported,
          _ => null,
        };
        if (phase != null) {
          _publish(
            generation,
            JobProgress(job: job, phase: phase, status: status),
            token,
          );
          return;
        }
      }
      if (canonical != null && !status.isTerminalFailure) {
        phase = ProcessingPhase.ready;
      }
      final shouldPoll =
          !status.isTerminalFailure &&
          status.jobStatus != SpeechJobStatus.unknown &&
          status.transcriptStatus != TranscriptStatus.unknown &&
          (canonical == null && phase == ProcessingPhase.waiting ||
              canonical != null &&
                  status.summaryStatus == SummaryStatus.pending);
      if (shouldPoll) next = pollInterval;
      _failures.remove(key);
      _publish(
        generation,
        JobProgress(
          job: job,
          phase: phase,
          status: status,
          canonical: canonical,
          retryIn: next,
        ),
        token,
      );
    } on AppException catch (error) {
      if (!_active(generation, key, token)) return;
      // A delayed 401 may belong to a credential replaced by renewal. The
      // shared auth layer decides whether the current session was revoked.
      // This read has no automatic retry; real invalidation calls stopSession.
      if (_retryable(error)) {
        final failures = (_failures[key] ?? 0) + 1;
        _failures[key] = failures;
        final factor = 1 << (failures > 5 ? 5 : failures);
        var milliseconds = pollInterval.inMilliseconds * factor;
        if (error is ApiFailure && error.retryAfter != null) {
          if (error.retryAfter!.inMilliseconds > milliseconds) {
            milliseconds = error.retryAfter!.inMilliseconds;
          }
        }
        next = Duration(
          milliseconds: milliseconds.clamp(
            pollInterval.inMilliseconds,
            maxBackoff.inMilliseconds,
          ),
        );
      }
      final lostAccess =
          error is NotFoundException ||
          error is ApiFailure &&
              (error.kind == ApiFailureKind.notFound ||
                  error.kind == ApiFailureKind.forbidden);
      final canonical = lostAccess ? null : previous.canonical;
      _publish(
        generation,
        JobProgress(
          job: job,
          phase: canonical != null
              ? ProcessingPhase.ready
              : ProcessingPhase.unavailable,
          status: lostAccess ? null : previous.status,
          canonical: canonical,
          error: error,
          retryIn: next,
        ),
        token,
      );
    } finally {
      if (identical(_tokens[key], token)) {
        _tokens.remove(key);
        if (next != null) _schedule(generation, key, next);
      }
    }
  }

  static final _invalid = ApiFailure(
    'Сервер вернул несогласованные данные задачи.',
    kind: ApiFailureKind.invalidResponse,
  );

  static bool _retryable(AppException error) =>
      error is NetworkException ||
      error is ApiFailure &&
          const {
            ApiFailureKind.timeout,
            ApiFailureKind.networkUnavailable,
            ApiFailureKind.rateLimited,
            ApiFailureKind.badGateway,
            ApiFailureKind.serviceUnavailable,
            ApiFailureKind.artifactUnavailable,
          }.contains(error.kind);

  static ProcessingPhase _phase(SpeechStatusDto status) {
    if (status.jobStatus == SpeechJobStatus.cancelled ||
        status.transcriptStatus == TranscriptStatus.cancelled) {
      return ProcessingPhase.cancelled;
    }
    if (status.isTerminalFailure) return ProcessingPhase.failed;
    if (status.jobStatus == SpeechJobStatus.unknown ||
        status.transcriptStatus == TranscriptStatus.unknown) {
      return ProcessingPhase.unsupported;
    }
    return ProcessingPhase.waiting;
  }

  void removeAudio(String audioId) {
    store.markDeleted(audioId);
    for (final key in state.keys.where((k) => k.audioId == audioId).toList()) {
      _timers.remove(key)?.cancel();
      _tokens.remove(key)?.cancel();
      _failures.remove(key);
    }
    state = Map.unmodifiable(
      Map.of(state)..removeWhere((key, _) => key.audioId == audioId),
    );
  }

  /// Call synchronously before publishing another account/credential.
  void stopSession() {
    _stopped = true;
    _generation++;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    for (final token in _tokens.values) {
      token.cancel();
    }
    _timers.clear();
    _tokens.clear();
    _failures.clear();
    if (mounted) state = const {};
  }

  @override
  void dispose() {
    stopSession();
    super.dispose();
  }
}
