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

  factory ResultDto.fromJson(Map<String, dynamic> json) => ResultDto(
        resultId: json['result_id'] as String,
        audioId: json['audio_id'] as String,
        workspaceId: json['workspace_id'] as String,
        workspaceName: (json['workspace_name'] as String?)?.trim(),
        uploadUserId: json['upload_user_id'] as String,
        summaryUrl: (json['summary_url'] as String?) ?? '',
        transcriptUrl: (json['transcript_url'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}
