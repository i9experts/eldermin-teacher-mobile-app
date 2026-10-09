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
  final String studentId;
  final DateTime? createdAt;

  const MessageThread({
    required this.id,
    this.studentId = '',
    this.createdAt,
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
        studentId: readId(j['studentId']) ?? '',
        createdAt: readDate(j['createdAt']),
      );

  /// `closed` is the only terminal value (schema enum open|closed, NM:58); anything else is treated as open.
  bool get isClosed => status == 'closed';

  MessageThread copyWith({String? status, bool? staffHasUnread, String? lastMessagePreview, DateTime? lastMessageAt}) => MessageThread(
        id: id,
        studentId: studentId,
        createdAt: createdAt,
        subject: subject,
        studentName: studentName,
        guardianName: guardianName,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        staffHasUnread: staffHasUnread ?? this.staffHasUnread,
        status: status ?? this.status,
      );
}

/// `{ items, unreadCount }` (staff-portal.service.ts:217-223). Backend 265fcfa (b069872) counts ALL matching unread threads, not just the
/// returned rows (max 100): while the list is complete the app derives the count from `staffHasUnread` (it also reacts to local mark-read at once);
/// when the list was cut at the limit it takes the server's accurate count (verified locally: 122 unread open threads, list 100, server 122) and
/// moves it by the same delta as the local edits. Older servers (count only over the returned rows) give a value <= the derived one, which is ignored.
class ThreadsResult {
  /// The server hard-limits the list to 100 rows (SPS:221-222).
  static const int serverLimit = 100;

  final List<MessageThread> items;
  final int? serverUnreadCount;
  const ThreadsResult({this.items = const [], this.serverUnreadCount});

  ThreadsResult withItems(List<MessageThread> next) {
    final r = ThreadsResult(items: next, serverUnreadCount: serverUnreadCount);
    final s = serverUnreadCount;
    if (s == null) return r;
    final shifted = s + (r.unreadThreads.length - unreadThreads.length);
    return ThreadsResult(items: next, serverUnreadCount: shifted < 0 ? 0 : shifted);
  }

  factory ThreadsResult.fromJson(Map<String, dynamic> j) => ThreadsResult(
        items: asJsonMapList(j['items']).map(MessageThread.fromJson).toList(),
        serverUnreadCount: readInt(j['unreadCount']),
      );

  /// Unread among OPEN threads only (owner decision): the request already sends `status=open`,
  /// and a `closed` row is dropped here too, so a server that ignored the filter cannot inflate it.
  List<MessageThread> get unreadThreads =>
      items.where((t) => t.staffHasUnread && t.status != 'closed').toList();
  int get unreadCount {
    final derived = unreadThreads.length;
    final s = serverUnreadCount;
    return mayUndercount && s != null && s > derived ? s : derived;
  }

  /// True when the list was cut at the server limit, so more unread threads may exist.
  bool get mayUndercount => items.length >= serverLimit;
}
