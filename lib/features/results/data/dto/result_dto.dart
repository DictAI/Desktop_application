class ResultDto {
  final String resultId;
  final String audioId;
  final String workspaceId;
  final String? workspaceName;
  final String uploadUserId;
  final String summaryUrl;
  final String transcriptUrl;
  final String status; // pending | done | failed
  final DateTime? createdAt;

  const ResultDto({
    required this.resultId,
    required this.audioId,
    required this.workspaceId,
    this.workspaceName,
    required this.uploadUserId,
    required this.summaryUrl,
    required this.transcriptUrl,
    this.status = 'pending',
    this.createdAt,
  });

  /// R01 returns the latest job_id as result_id. "done" is not summary readiness.
  /// Anonymous workspace fields and unavailable document URLs are empty strings.
  factory ResultDto.fromJson(Map<String, dynamic> json) {
    for (final key in const [
      'result_id',
      'audio_id',
      'workspace_id',
      'workspace_name',
      'upload_user_id',
      'summary_url',
      'transcript_url',
      'status',
      'created_at',
    ]) {
      if (json[key] is! String) {
        throw const FormatException('Invalid result field');
      }
    }
    for (final key in const [
      'result_id',
      'audio_id',
      'upload_user_id',
      'status',
    ]) {
      if ((json[key] as String).isEmpty) {
        throw const FormatException('Empty result identity/state');
      }
    }
    return ResultDto(
      resultId: json['result_id'] as String,
      audioId: json['audio_id'] as String,
      workspaceId: json['workspace_id'] as String,
      workspaceName: json['workspace_name'] as String,
      uploadUserId: json['upload_user_id'] as String,
      summaryUrl: json['summary_url'] as String,
      transcriptUrl: json['transcript_url'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
