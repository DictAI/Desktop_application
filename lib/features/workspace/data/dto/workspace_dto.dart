// Workspace DTO — маппинг ответа backend → Dart-объект.
// Поля соответствуют JSON из POST /workspaces/ и GET /workspaces/:workspace_id.
// Note: GET /workspaces/ returns "owner_user_id", GET/PUT /workspaces/:id returns "owner_id".
// fromJson accepts both keys.
class WorkspaceDto {
  final String workspaceId;
  final String ownerUserId;
  final String name;
  final DateTime createdAt;

  const WorkspaceDto({
    required this.workspaceId,
    required this.ownerUserId,
    required this.name,
    required this.createdAt,
  });

  factory WorkspaceDto.fromJson(Map<String, dynamic> json) => WorkspaceDto(
        workspaceId: json['workspace_id'] as String,
        ownerUserId: (json['owner_user_id'] ?? json['owner_id']) as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'workspace_id': workspaceId,
        'owner_user_id': ownerUserId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };
}
