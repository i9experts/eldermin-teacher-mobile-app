import '../json_helpers.dart';

/// `GET /staff-portal/threads` item (notification-and-message.schema.ts:41-59,
/// verified; endpoint NOT deployed to production yet).
class MessageThread {
  final String id;
  final String subject;
  final String studentName;
  final String guardianName;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final bool staffHasUnread;
  final String status; // open|closed

  const MessageThread({
    required this.id,
    this.subject = '',
    this.studentName = '',
    this.guardianName = '',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.staffHasUnread = false,
    this.status = '',
  });

  factory MessageThread.fromJson(Map<String, dynamic> j) => MessageThread(
        id: readId(j['_id'] ?? j['id']) ?? '',
        subject: readText(j['subject']),
        studentName: readText(j['studentName']),
        guardianName: readText(j['guardianName']),
        lastMessagePreview: readText(j['lastMessagePreview']),
        lastMessageAt: readDate(j['lastMessageAt']),
        staffHasUnread: readBool(j['staffHasUnread']),
        status: readText(j['status']),
      );
}

/// `{ items, unreadCount }` (staff-portal.service.ts:217-223). The server's
/// `unreadCount` only covers the returned rows (max 100) so the app derives its
/// own count from `staffHasUnread` and flags a possible under-count.
class ThreadsResult {
  /// The server hard-limits the list to 100 rows (SPS:221-222).
  static const int serverLimit = 100;

  final List<MessageThread> items;
  final int? serverUnreadCount;
  const ThreadsResult({this.items = const [], this.serverUnreadCount});

  factory ThreadsResult.fromJson(Map<String, dynamic> j) => ThreadsResult(
        items: asJsonMapList(j['items']).map(MessageThread.fromJson).toList(),
        serverUnreadCount: readInt(j['unreadCount']),
      );

  List<MessageThread> get unreadThreads => items.where((t) => t.staffHasUnread).toList();
  int get unreadCount => unreadThreads.length;

  /// True when the list was cut at the server limit, so more unread threads may exist.
  bool get mayUndercount => items.length >= serverLimit;
}
