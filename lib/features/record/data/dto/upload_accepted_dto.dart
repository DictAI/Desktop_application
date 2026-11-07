import 'dart:convert';

/// U01/U02 HTTP 202: a durable job reference, never a ready transcript/progress.
final class UploadAcceptedDto {
  const UploadAcceptedDto._({
    required this.audioId,
    required this.sessionId,
    required this.jobId,
    required this.processingVersion,
    required this.statusUrl,
  });

  final String audioId;
  final String? sessionId;
  final String jobId;
  final String processingVersion;
  final String statusUrl;

  factory UploadAcceptedDto.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('Invalid upload acceptance field');
      }
      return value;
    }

    String uuid(String key) {
      final value = text(key);
      if (_uuid.firstMatch(value)?.group(0) != value) {
        throw const FormatException('Invalid upload acceptance identifier');
      }
      return value;
    }

    if (!json.containsKey('session_id')) {
      throw const FormatException('Missing nullable upload session');
    }
    final audioId = uuid('audio_id');
    final sessionId = json['session_id'] == null ? null : uuid('session_id');
    final jobId = uuid('job_id');
    final version = text('processing_version');
    if (utf8.encode(version).length > 128 ||
        version.contains(RegExp(r'[\x00\r\n]'))) {
      throw const FormatException('Invalid upload processing version');
    }
    final statusUrl = text('status_url');
    // Backend returns this exact relative route. Do not retain a foreign URL or
    // a reference to a different recording as a trusted job polling target.
    if (statusUrl != '/meetings/results/$audioId/speech-status') {
      throw const FormatException('Invalid upload status reference');
    }
    return UploadAcceptedDto._(
      audioId: audioId,
      sessionId: sessionId,
      jobId: jobId,
      processingVersion: version,
      statusUrl: statusUrl,
    );
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
}
