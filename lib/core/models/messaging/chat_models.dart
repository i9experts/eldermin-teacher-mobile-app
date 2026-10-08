import '../home/messaging.dart';
import '../json_helpers.dart';

/// One message of a thread. `GET /staff-portal/threads/:id/messages` rows and the `POST .../messages` answer are the raw
/// `Message` document (notification-and-message.schema.ts:67-74 = NM): `_id, threadId, senderRole('guardian'|'staff'),
/// senderName, body, schoolSlug, createdAt, updatedAt`.
///
/// Local (not yet confirmed) messages have [clientId] set and [state] != sent; they never come from the server.
enum SendState { sent, sending, failed }

class ChatMessage {
  final String id;
  final String clientId;
  final String body;
  final String senderName;
  final bool fromMe; // senderRole == 'staff' (the thread belongs to this staff member, SPS:228)
  final DateTime? createdAt;
  final SendState state;

  /// Why a failed send failed (shown under the bubble) and whether Retry makes sense.
  final String failureText;
  final bool canRetry;

  const ChatMessage({
    this.id = '',
    this.clientId = '',
    required this.body,
    this.senderName = '',
    required this.fromMe,
    this.createdAt,
    this.state = SendState.sent,
    this.failureText = '',
    this.canRetry = true,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: readId(j['_id'] ?? j['id']) ?? '',
        body: readText(j['body']),
        senderName: readText(j['senderName']),
        fromMe: readString(j['senderRole']) == 'staff',
        createdAt: readDate(j['createdAt']),
      );

  bool get isLocal => clientId.isNotEmpty && id.isEmpty;

  /// Stable key for list diffing: the server id, or the client id for a local message.
  String get key => id.isNotEmpty ? id : 'local:$clientId';

  ChatMessage copyWith({SendState? state, String? failureText, bool? canRetry}) => ChatMessage(
        id: id,
        clientId: clientId,
        body: body,
        senderName: senderName,
        fromMe: fromMe,
        createdAt: createdAt,
        state: state ?? this.state,
        failureText: failureText ?? this.failureText,
        canRetry: canRetry ?? this.canRetry,
      );
}

/// `GET /staff-portal/threads/:id/messages` -> `{ thread, messages }` (SPS:240-251, backend 265fcfa). `messages` is oldest -> newest and holds
/// the NEWEST 500 of the thread (earlier ones are cut off, not the latest). `?after=<createdAt>` returns only strictly newer messages.
class ThreadMessages {
  static const int serverLimit = 500;
  final MessageThread thread;
  final List<ChatMessage> messages;
  const ThreadMessages({required this.thread, this.messages = const []});

  /// True when the list reached the server limit, so EARLIER messages may exist that are not shown (the newest 500 are always returned).
  bool get possiblyTruncated => messages.length >= serverLimit;
}

/// `GET /staff-portal/students/:studentId/guardians` -> `[ { userId, name } ]` (SPS:274-284). Names only: the server never sends phone or
/// email (owner rule); the teacher contacts guardians only through in-app messages.
class GuardianName {
  final String userId;
  final String name;
  const GuardianName({required this.userId, required this.name});

  factory GuardianName.fromJson(Map<String, dynamic> j) =>
      GuardianName(userId: readId(j['userId'] ?? j['_id'] ?? j['id']) ?? '', name: readText(j['name']));

  String get display => name.trim().isEmpty ? 'Guardian' : name.trim();
}

/// Body of `POST /staff-portal/threads` (CreateStaffThreadDto, staff-portal.dto.ts:7-12).
class NewThreadRequest {
  static const int subjectMax = 200;
  static const int messageMax = 4000;
  final String studentId;
  final String guardianUserId;
  final String subject;
  final String firstMessage;
  const NewThreadRequest({required this.studentId, required this.guardianUserId, required this.subject, required this.firstMessage});

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'guardianUserId': guardianUserId,
        'subject': subject.trim(),
        'firstMessage': firstMessage.trim(),
      };
}
