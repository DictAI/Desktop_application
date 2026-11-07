import 'result_dto.dart';

/// The R01 envelope. Counts are server values, never inferred from this page.
final class ResultsPageDto {
  const ResultsPageDto({required this.data, required this.pagination});
  final List<ResultDto> data;
  final ResultsPaginationDto pagination;

  factory ResultsPageDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final pagination = json['pagination'];
    if (data is! List || pagination is! Map<String, dynamic>) {
      throw const FormatException('Invalid results page');
    }
    return ResultsPageDto(
      data: List.unmodifiable(
        data.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid results item');
          }
          return ResultDto.fromJson(item);
        }),
      ),
      pagination: ResultsPaginationDto.fromJson(pagination),
    );
  }
}

final class ResultsPaginationDto {
  const ResultsPaginationDto({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory ResultsPaginationDto.fromJson(Map<String, dynamic> json) {
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
      throw const FormatException('Invalid results pagination');
    }
    return ResultsPaginationDto(
      page: page,
      limit: limit,
      total: total,
      totalPages: pages,
    );
  }
}
