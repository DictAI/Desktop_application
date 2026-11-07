enum V2SessionStatus {
  queued,
  running,
  ready,
  failed,
  cancelled,
  expired,
  unknown,
}

/// U03 is a status response. It carries no speakers, fragments or confirmation.
final class V2SessionDto {
  const V2SessionDto._({
    required this.sessionId,
    required this.audioId,
    required this.jobId,
    required this.processingVersion,
    required this.rawStatus,
    required this.statusUrl,
  });

  final String sessionId;
  final String audioId;
  final String jobId;
  final String processingVersion;
  final String rawStatus;
  final String statusUrl;
  bool get confirmRequired => false;

  V2SessionStatus get status => switch (rawStatus) {
    'queued' => V2SessionStatus.queued,
    'running' => V2SessionStatus.running,
    'ready' => V2SessionStatus.ready,
    'failed' => V2SessionStatus.failed,
    'cancelled' => V2SessionStatus.cancelled,
    'expired' => V2SessionStatus.expired,
    _ => V2SessionStatus.unknown,
  };

  /// Ready is not evidence that the canonical artifact can be read.
  bool get shouldPoll =>
      status == V2SessionStatus.queued || status == V2SessionStatus.running;

  factory V2SessionDto.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('Invalid V2 session field');
      }
      return value;
    }

    if (json['confirm_required'] != false) {
      throw const FormatException('Unsupported V2 confirmation contract');
    }
    return V2SessionDto._(
      sessionId: text('session_id'),
      audioId: text('audio_id'),
      jobId: text('job_id'),
      processingVersion: text('processing_version'),
      rawStatus: text('status'),
      statusUrl: text('status_url'),
    );
  }
}
