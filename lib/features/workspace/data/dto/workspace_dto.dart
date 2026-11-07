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

/// Pagination returned by W01. No inferred counts or invented fallback fields.
final class WorkspacePage {
  const WorkspacePage({required this.data, required this.pagination});
  final List<WorkspaceDto> data;
  final WorkspacePagination pagination;

  factory WorkspacePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = json['pagination'];
    if (data is! List || pagination is! Map<String, dynamic>) {
      throw const FormatException('Invalid workspace page');
    }
    return WorkspacePage(
      data: List.unmodifiable(
        data.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid workspace item');
          }
          return WorkspaceDto.fromJson(item);
        }),
      ),
      pagination: WorkspacePagination.fromJson(pagination),
    );
  }
}

final class WorkspacePagination {
  const WorkspacePagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory WorkspacePagination.fromJson(Map<String, dynamic> json) {
    final page = json['page'];
    final limit = json['limit'];
    final total = json['total'];
    final pages = json['total_pages'];
    if (page is! int ||
        page < 1 ||
        limit is! int ||
        limit < 1 ||
        total is! int ||
        total < 0 ||
        pages is! int ||
        pages < 0) {
      throw const FormatException('Invalid workspace pagination');
    }
    return WorkspacePagination(
      page: page,
      limit: limit,
      total: total,
      totalPages: pages,
    );
  }
}
