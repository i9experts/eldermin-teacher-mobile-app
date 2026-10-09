import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/auth_me.dart';
import 'package:eldermin_teacher_app/core/models/calendar/calendar_models.dart';
import 'package:eldermin_teacher_app/core/models/help/kb_models.dart';
import 'package:eldermin_teacher_app/core/models/safeguarding/safeguarding_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/account_repository.dart';
import 'package:eldermin_teacher_app/core/services/avatar_picker.dart';
import 'package:eldermin_teacher_app/core/services/circular_local_state.dart';
import 'package:eldermin_teacher_app/core/services/events_repository.dart';
import 'package:eldermin_teacher_app/core/services/kb_repository.dart';
import 'package:eldermin_teacher_app/core/services/profile_repository.dart';
import 'package:eldermin_teacher_app/core/services/safeguarding_repository.dart';
import 'package:eldermin_teacher_app/core/services/school_calendar_repository.dart';

Never fail7c(int? status, [String message = 'error']) => throw ApiException(message, statusCode: status);

/// A calendar row as the server sends it (SCS:155-156 manual entry).
Map<String, Object?> calRow(String id, String title, {String type = 'event', String start = '2026-10-12T00:00:00.000Z', String? end, bool allDay = true, String? color, String? description, String source = 'manual', List<String> grades = const []}) => {
      '_id': id,
      'title': title,
      'description': description ?? '',
      'type': type,
      'color': color ?? '#1D9E75',
      'startDate': start,
      'endDate': end ?? start,
      'allDay': allDay,
      'gradeLevels': grades,
      'campusId': null,
      'source': source,
      'createdBy': 'Admin',
      'schoolSlug': 'stub-school',
    };

/// The leaking fee row exactly as SCS:91-103 builds it.
Map<String, Object?> feeRow([String day = '2026-10-12']) => {
      '_id': 'fee-due-$day',
      'title': 'Fee Due (3 invoices)',
      'description': 'Total outstanding: 845000.50',
      'type': 'fee_due',
      'color': '#EF9F27',
      'startDate': day,
      'endDate': day,
      'allDay': true,
      'campusId': null,
      'gradeLevels': <String>[],
      'source': 'finance',
    };

Map<String, Object?> circRow(String id, String title, {String status = 'published', List<String> roles = const ['staff'], String scope = 'school', String? campus, List<String> staffIds = const [], bool ack = false, bool urgent = false, String body = '<p>Hello</p>', List<String> attachments = const [], String category = 'administrative', String published = '2026-10-08T06:00:00.000Z'}) => {
      '_id': id,
      'title': title,
      'body': body,
      'attachmentUrls': attachments,
      'category': category,
      'priority': urgent ? 'urgent' : 'normal',
      'audience': {'roles': roles, 'scope': scope, 'campusId': campus, 'gradeLevels': <String>[], 'individualStudentIds': ['64d0000000000000000000aa'], 'individualStaffIds': staffIds, 'userIds': <String>[]},
      'requiresAcknowledgment': ack,
      'status': status,
      'publishedAt': status == 'published' ? published : null,
      'recipientCount': 120,
      'createdBy': 'Admin',
      'schoolSlug': 'stub-school',
      'createdAt': published,
    };

Map<String, Object?> eventRow(String id, String title, {String status = 'published', String visibility = 'public', List<Map<String, Object?>>? sessions, String category = 'annual_day', String description = '', String venue = 'Main Hall'}) => {
      '_id': id,
      'title': title,
      'description': description,
      'category': category,
      'campusId': null,
      'venueName': venue,
      'venueAddress': '1 School Road',
      'sessions': sessions ?? [session('Day 1', '2026-10-20T09:00:00.000Z', '2026-10-20T12:00:00.000Z')],
      'theme': {'primaryColor': '#0C447C'},
      'sponsors': [
        {'name': 'Sponsor', 'tier': 'gold'}
      ],
      'slug': 'e-$id',
      'visibility': visibility,
      'status': status,
      'createdBy': 'Admin',
      'schoolSlug': 'stub-school',
    };

Map<String, Object?> session(String label, String start, String end) => {'_id': 's$start', 'label': label, 'startAt': start, 'endAt': end, 'capacity': 200};

class FakeSchoolCalendarRepository extends SchoolCalendarRepository {
  Future<List<CalendarEntry>> Function(DateTime from, DateTime to) events = (_, __) async => [];
  Future<List<Circular>> Function() circulars = () async => [];
  Future<CircularAck> Function(String id) ack0 = (id) async => CircularAck(DateTime.utc(2026, 10, 9));
  final calls = <String>[];
  final windows = <({DateTime from, DateTime to})>[];

  @override
  Future<List<CalendarEntry>> fetchEvents({required DateTime fromDay, required DateTime toDay}) {
    calls.add('events');
    windows.add((from: fromDay, to: toDay));
    return events(fromDay, toDay);
  }

  @override
  Future<List<Circular>> fetchCirculars() {
    calls.add('circulars');
    return circulars();
  }

  @override
  Future<CircularAck> acknowledge(String id) {
    calls.add('ack:$id');
    return ack0(id);
  }
}

class FakeEventsRepository extends EventsRepository {
  Future<List<SchoolEvent>> Function() list = () async => [];
  Future<SchoolEvent> Function(String id) one = (id) async => SchoolEvent.tryParse(eventRow(id, 'Event'))!;
  final calls = <String>[];

  @override
  Future<List<SchoolEvent>> fetchEvents() {
    calls.add('list');
    return list();
  }

  @override
  Future<SchoolEvent> fetchEvent(String id) {
    calls.add('one:$id');
    return one(id);
  }
}

class FakeSafeguardingRepository extends SafeguardingRepository {
  Future<SafeguardingReceipt> Function(SafeguardingReport r) submit0 = (_) async => const SafeguardingReceipt('SC-2026-123');
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<SafeguardingReceipt> submit(SafeguardingReport report) {
    bodies.add(report.toRequestBody());
    return submit0(report);
  }
}

class FakeProfileRepository extends ProfileRepository {
  Future<AuthMe> Function() account = () async => const AuthMe(id: 'u', name: 'Tess Teacher', email: 't@s.test', role: 'teacher');
  Future<String> Function(String path, String name, String mime) upload = (p, n, m) async => 'https://files.test/avatars/new.png';
  final uploads = <({String path, String name, String mime})>[];

  @override
  Future<AuthMe> fetchAccount() => account();

  @override
  Future<String> uploadAvatar({required String path, required String fileName, required String mime}) {
    uploads.add((path: path, name: fileName, mime: mime));
    return upload(path, fileName, mime);
  }
}

class FakeAvatarPicker implements AvatarPicker {
  Future<PickedAvatar?> Function(AvatarSource s) result = (_) async => const PickedAvatar(path: '/tmp/me.jpg', name: 'me.jpg', size: 120000);
  final sources = <AvatarSource>[];
  @override
  Future<PickedAvatar?> pick(AvatarSource source) {
    sources.add(source);
    return result(source);
  }
}

class FakeKbRepository extends KbRepository {
  Future<List<KbArticle>> Function() listRows = () async => [];
  Future<List<KbArticle>> Function(String q) search0 = (_) async => [];
  Future<KbArticle> Function(String m, String t) one = (m, t) async => const KbArticle(module: 'hr', tabKey: 'x', title: 'X');
  final calls = <String>[];

  @override
  Future<List<KbArticle>> list({String? module}) {
    calls.add('list');
    return listRows();
  }

  @override
  Future<List<KbArticle>> search(String q) {
    calls.add('search:$q');
    return search0(q);
  }

  @override
  Future<KbArticle> article(String module, String tabKey) {
    calls.add('article:$module/$tabKey');
    return one(module, tabKey);
  }
}

class FakeAccountRepository extends AccountRepository {
  Future<DeletionRequestResult> Function(String? reason) request0 = (_) async => const DeletionRequestResult(requestId: 'r1', status: 'pending', alreadyRequested: false, message: 'Your request was sent to the school administration. Your records are retained until they process it.');
  final reasons = <String?>[];

  @override
  Future<DeletionRequestResult> request({String? reason}) {
    reasons.add(reason);
    return request0(reason);
  }
}

/// A BaseClient that also records multipart uploads.
class RecordingMultipartClient extends BaseClient {
  Object? body;
  int? failStatus;
  String failMessage = 'boom';
  Map<String, List<MultipartFile>>? lastFiles;
  String? lastUrl;
  RecordingMultipartClient([this.body]);

  @override
  Future<Response> multipart(String url, {required Map<String, List<MultipartFile>> files, Map<String, dynamic>? fields, String method = 'POST', void Function(int sent, int total)? onSendProgress, bool requiresAuth = true}) async {
    lastFiles = files;
    lastUrl = url;
    final ro = RequestOptions(path: url);
    final s = failStatus;
    if (s != null) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: s, data: {'statusCode': s, 'message': failMessage}));
    }
    return Response(requestOptions: ro, statusCode: 201, data: body);
  }
}

CircularLocalState memoryLocal() => CircularLocalState.memory();
