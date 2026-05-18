// Result DTO — маппинг ответа backend → Dart-объект.
// Поля соответствуют JSON из POST /meetings/results.
//
// ⚠️ Поля summary_url / transcript_url и created_at будут заполнены
// только после реализации GET /meetings/results (см. MISSING_ENDPOINTS.md п.2).
// До тех пор объекты ResultDto создаются только через Upload-ответ.
class ResultDto {
  final String resultId;
  final String audioId;
  final String workspaceId;
  final String? workspaceName;
  final String uploadUserId;
  final String summaryUrl;
  final String transcriptUrl;
  final DateTime? createdAt; // nullable — не всегда возвращается backend

  const ResultDto({
    required this.resultId,
    required this.audioId,
    required this.workspaceId,
    this.workspaceName,
    required this.uploadUserId,
    required this.summaryUrl,
    required this.transcriptUrl,
    this.createdAt,
  });

  factory ResultDto.fromJson(Map<String, dynamic> json) => ResultDto(
        resultId: json['result_id'] as String,
        audioId: json['audio_id'] as String,
        workspaceId: json['workspace_id'] as String,
        workspaceName: (json['workspace_name'] as String?)?.trim(),
        uploadUserId: json['upload_user_id'] as String,
        summaryUrl: json['summary_url'] as String,
        transcriptUrl: json['transcript_url'] as String,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'result_id': resultId,
        'audio_id': audioId,
        'workspace_id': workspaceId,
        if (workspaceName != null) 'workspace_name': workspaceName,
        'upload_user_id': uploadUserId,
        'summary_url': summaryUrl,
        'transcript_url': transcriptUrl,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
