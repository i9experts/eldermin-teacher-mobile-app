import '../network/response_shape.dart';
import 'json_helpers.dart';

/// A page of results. Understands the backend's two list shapes:
///  * offset pages: `{ data: [...], meta: { total, page, limit, pages } }`
///  * cursor pages (staff-portal): `{ items: [...], nextCursor, unreadCount? }`
class Paginated<T> {
  final List<T> items;
  final int? total;
  final int page;
  final int? limit;
  final int? pages;
  final String? nextCursor;
  final int? unreadCount;

  const Paginated({
    this.items = const [],
    this.total,
    this.page = 1,
    this.limit,
    this.pages,
    this.nextCursor,
    this.unreadCount,
  });

  bool get hasMore => nextCursor != null || (pages != null && page < pages!);

  factory Paginated.fromJson(
    Object? body,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (body is List) {
      return Paginated<T>(items: asJsonMapList(body).map(parse).toList());
    }
    final map = asJsonMap(body);
    final raw = map['data'] ?? map['items'];
    final meta = asJsonMap(map['meta']);
    return Paginated<T>(
      items: asJsonMapList(raw).map(parse).toList(),
      total: readInt(meta['total']),
      page: readInt(meta['page']) ?? 1,
      limit: readInt(meta['limit']),
      pages: readInt(meta['pages']),
      nextCursor: readString(map['nextCursor']),
      unreadCount: readInt(map['unreadCount']),
    );
  }

  /// Like [fromJson] but the container shape is checked: a body that is not a list / `{data|items: [...]}` of objects throws
  /// [UnexpectedResponseShape] (error state) instead of becoming an empty page. A valid empty page stays empty.
  factory Paginated.parse(Object? body, T Function(Map<String, dynamic> json) parse, {required String what}) {
    final rows = expectRows(body, what: what, keys: const ['data', 'items']);
    final map = body is Map ? asJsonMap(body) : const <String, dynamic>{};
    final meta = asJsonMap(map['meta']);
    return Paginated<T>(
      items: rows.map(parse).toList(),
      total: readInt(meta['total']),
      page: readInt(meta['page']) ?? 1,
      limit: readInt(meta['limit']),
      pages: readInt(meta['pages']),
      nextCursor: readString(map['nextCursor']),
      unreadCount: readInt(map['unreadCount']),
    );
  }
}
