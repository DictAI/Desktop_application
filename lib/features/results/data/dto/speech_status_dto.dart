/// These are three independent backend states, not a combined progress enum.
enum SpeechJobStatus { queued, running, completed, failed, cancelled, unknown }

enum TranscriptStatus { pending, ready, failed, cancelled, unknown }

enum SummaryStatus { pending, ready, failed, unknown }

final class SpeechStatusDto {
  const SpeechStatusDto._({
    required this.jobId,
    required this.processingVersion,
    required this.workspaceId,
    required this.rawJobStatus,
    required this.rawTranscriptStatus,
    required this.rawSummaryStatus,
    required this.summaryError,
  });

  final String jobId;
  final String processingVersion;
  final String? workspaceId;
  final String rawJobStatus;
  final String rawTranscriptStatus;
  final String rawSummaryStatus;

  /// Open backend code. Use ApiErrorMapper.summaryFailureMessage for display;
  /// this value is neither an ASR failure nor safe UI text.
  final String? summaryError;

  SpeechJobStatus get jobStatus => switch (rawJobStatus) {
    'queued' => SpeechJobStatus.queued,
    'running' => SpeechJobStatus.running,
    'completed' => SpeechJobStatus.completed,
    'failed' => SpeechJobStatus.failed,
    'cancelled' => SpeechJobStatus.cancelled,
    _ => SpeechJobStatus.unknown,
  };

  TranscriptStatus get transcriptStatus => switch (rawTranscriptStatus) {
    'pending' => TranscriptStatus.pending,
    'ready' => TranscriptStatus.ready,
    'failed' => TranscriptStatus.failed,
    'cancelled' => TranscriptStatus.cancelled,
    _ => TranscriptStatus.unknown,
  };

  SummaryStatus get summaryStatus => switch (rawSummaryStatus) {
    'pending' => SummaryStatus.pending,
    'ready' => SummaryStatus.ready,
    'failed' => SummaryStatus.failed,
    _ => SummaryStatus.unknown,
  };

  bool get hasUnknownStatus =>
      jobStatus == SpeechJobStatus.unknown ||
      transcriptStatus == TranscriptStatus.unknown ||
      summaryStatus == SummaryStatus.unknown;

  bool get isTerminalFailure =>
      jobStatus == SpeechJobStatus.failed ||
      jobStatus == SpeechJobStatus.cancelled ||
      transcriptStatus == TranscriptStatus.failed ||
      transcriptStatus == TranscriptStatus.cancelled;

  /// A completed job can still await the results projection. Summary is
  /// independent; transcript ready only permits requesting canonical JSON.
  bool get shouldPollTranscript =>
      jobStatus != SpeechJobStatus.unknown &&
      transcriptStatus != TranscriptStatus.unknown &&
      !isTerminalFailure &&
      transcriptStatus == TranscriptStatus.pending;

  factory SpeechStatusDto.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('Invalid speech status field');
      }
      return value;
    }

    String? nullable(String key) {
      if (!json.containsKey(key) ||
          (json[key] != null && json[key] is! String)) {
        throw const FormatException('Invalid nullable speech status field');
      }
      return json[key] as String?;
    }

    return SpeechStatusDto._(
      jobId: text('job_id'),
      processingVersion: text('processing_version'),
      workspaceId: nullable('workspace_id'),
      rawJobStatus: text('job_status'),
      rawTranscriptStatus: text('transcript_status'),
      rawSummaryStatus: text('summary_status'),
      summaryError: nullable('summary_error'),
    );
  }
}
