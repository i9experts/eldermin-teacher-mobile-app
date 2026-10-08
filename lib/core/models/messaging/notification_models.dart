import '../json_helpers.dart';

/// A row of `GET /staff-portal/notifications` (raw `Notification` document, notification-and-message.schema.ts:15-29 = NM):
/// `_id, recipientUserId, type, title, body, relatedEntityId?, isRead, readAt?, schoolSlug, createdAt, updatedAt`.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String relatedEntityId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    this.type = 'other',
    this.title = '',
    this.body = '',
    this.relatedEntityId = '',
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: readId(j['_id'] ?? j['id']) ?? '',
        type: readString(j['type']) ?? 'other',
        title: readText(j['title']),
        body: readText(j['body']),
        relatedEntityId: readText(j['relatedEntityId']),
        isRead: readBool(j['isRead']),
        createdAt: readDate(j['createdAt']),
      );

  AppNotification asRead() => AppNotification(
      id: id, type: type, title: title, body: body, relatedEntityId: relatedEntityId, isRead: true, createdAt: createdAt);
}

/// `{ items, nextCursor, unreadCount }` (staff-portal.service.ts:172-189). `nextCursor` = the `createdAt` of the last item when more
/// exist (SPS:186), passed back as `before` (strictly older, SPS:177-180); null = end of the list.
class NotificationsPage {
  final List<AppNotification> items;
  final String? nextCursor;
  final int? unreadCount;
  const NotificationsPage({this.items = const [], this.nextCursor, this.unreadCount});

  factory NotificationsPage.fromJson(Map<String, dynamic> j, List<Map<String, dynamic>> rows) => NotificationsPage(
        items: rows.map(AppNotification.fromJson).where((n) => n.id.isNotEmpty).toList(),
        nextCursor: _cursor(j['nextCursor']),
        unreadCount: readInt(j['unreadCount']),
      );

  static String? _cursor(Object? v) {
    if (v == null) return null;
    final d = readDate(v);
    // A Date arrives as ISO text; keep the original text when parseable (the server parses it with `new Date`, SPS:178).
    if (d == null) return null;
    return v is String ? v : d.toUtc().toIso8601String();
  }
}
