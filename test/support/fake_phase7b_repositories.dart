import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/home/teaching.dart';
import 'package:eldermin_teacher_app/core/models/leave/leave_models.dart';
import 'package:eldermin_teacher_app/core/models/ptm/ptm_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/fixtures_repository.dart';
import 'package:eldermin_teacher_app/core/services/leave_repository.dart';
import 'package:eldermin_teacher_app/core/services/ptm_repository.dart';

/// The staff id of the signed-in teacher in `test/support/auth_harness.dart`.
const myStaff = '64a0000000000000000000a1';
const otherStaff = '64a0000000000000000000a9';

dynamic fx7b(String n) => jsonDecode(File('test/fixtures/phase7b/$n.json').readAsStringSync());

Never fail7b(int? status, [String message = 'error']) => throw ApiException(message, statusCode: status);

String oid(int n) => '64d${n.toRadixString(16).padLeft(21, '0')}';

/// A meeting built the way the server sends it (guardian phone/email deliberately ABSENT: the teacher projection removes them).
ParentMeeting meeting(String id,
        {String status = 'requested',
        String teacherId = myStaff,
        String day = '2026-10-12',
        String start = '10:00',
        String end = '10:20',
        String student = 'Zara Malik',
        List<Map<String, Object?>> items = const [],
        List<String> points = const ['Maths progress'],
        String notes = '',
        String cancelledReason = '',
        bool attended = false}) =>
    ParentMeeting.fromJson({
      '_id': id,
      'studentId': oid(0x200),
      'studentName': student,
      'gradeLevel': 'Grade 5',
      'sectionName': 'A',
      'teacherId': teacherId,
      'teacherName': teacherId == myStaff ? 'Tess Teacher' : 'Other Teacher',
      'scheduledDate': '${day}T00:00:00.000Z',
      'startTime': start,
      'endTime': end,
      'guardianName': 'Mr Malik',
      'status': status,
      'academicYear': '2026-27',
      'discussionPoints': points,
      'meetingNotes': notes,
      'actionItems': items,
      'parentAttended': attended,
      if (cancelledReason.isNotEmpty) 'cancelledReason': cancelledReason,
    });

Map<String, Object?> item(String id, {String text = 'Read daily', String status = 'pending'}) => {'_id': id, 'description': text, 'assignedTo': 'Parent', 'status': status};

Substitution fixture(String id,
        {String status = 'assigned',
        String? original = otherStaff,
        String? substitute = myStaff,
        String day = '2026-10-08',
        int period = 3,
        String subject = 'Mathematics'}) =>
    Substitution.fromJson({
      '_id': id,
      'date': '${day}T00:00:00.000Z',
      'periodNo': period,
      'startTime': '09:20',
      'endTime': '10:00',
      'gradeLevel': 'Grade 4',
      'sectionName': 'B',
      'subject': subject,
      'roomNo': '101',
      'originalTeacherId': original,
      'originalTeacherName': original == myStaff ? 'Tess Teacher' : 'Other Teacher',
      'substituteTeacherId': substitute,
      'substituteTeacherName': substitute == null ? null : (substitute == myStaff ? 'Tess Teacher' : 'Other Teacher'),
      'reason': 'leave',
      'status': status,
    });

StaffLeaveRequest leaveRow(String id, {String status = 'pending', String type = 'annual', String from = '2026-11-02', String to = '2026-11-04', num days = 3, String reason = 'Family wedding out of town', String by = '', String note = ''}) =>
    StaffLeaveRequest.fromJson({
      '_id': id,
      'leaveType': type,
      'fromDate': '${from}T00:00:00.000Z',
      'toDate': '${to}T00:00:00.000Z',
      'totalDays': days,
      'reason': reason,
      'status': status,
      if (by.isNotEmpty) 'approverName': by,
      if (note.isNotEmpty) 'approverNote': note,
      'createdAt': '2026-10-01T06:00:00.000Z',
    });

LeaveBalanceSummary balanceOf({bool hasPolicy = true, int annualUsed = 4}) => LeaveBalanceSummary.fromJson({
      'annual': {'entitled': 21, 'used': annualUsed, 'remaining': 21 - annualUsed},
      'sick': {'entitled': 10, 'used': 2, 'remaining': 8},
      'casual': {'entitled': 10, 'used': 0, 'remaining': 10},
      'maternity': {'entitled': 90, 'used': 0, 'remaining': 90},
      'paternity': {'entitled': 10, 'used': 0, 'remaining': 10},
      'hajj': {'entitled': 0, 'used': 0, 'remaining': 0},
      'hasPolicy': hasPolicy,
    });

/// Records every request and answers [body] (or throws the HTTP error [failStatus]). Used by the three repository tests.
typedef Call = ({String method, String url, Object? data, Map<String, dynamic>? query});

class RecordingClient extends BaseClient {
  Object? body;
  int? failStatus;
  String failMessage = 'boom';
  final calls = <Call>[];
  RecordingClient([this.body]);

  Future<Response> _answer(String method, String url, Object? data, Map<String, dynamic>? q) async {
    calls.add((method: method, url: url, data: data, query: q));
    final ro = RequestOptions(path: url);
    final s = failStatus;
    if (s != null) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: s, data: {'statusCode': s, 'message': failMessage}));
    }
    return Response(requestOptions: ro, statusCode: 200, data: body);
  }

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) => _answer('GET', url, null, queryParameters);
  @override
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) => _answer('POST', url, data, queryParameters);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) => _answer('PATCH', url, data, queryParameters);
}

class FakePtmRepository extends PtmRepository {
  Future<List<ParentMeeting>> Function(String staffId, DateTime? from, DateTime? to) list = (_, __, ___) async => [];
  Future<ParentMeeting> Function(String id) one = (id) async => meeting(id);
  Future<List<ParentMeeting>> Function(String studentId) history = (_) async => [];
  Future<ParentMeeting> Function(PtmCreateRequest r) create0 = (r) async => meeting('64d000000000000000009001');
  Future<ParentMeeting> Function(String id) confirm0 = (id) async => meeting(id, status: 'confirmed');
  Future<ParentMeeting> Function(String id, DateTime day, String? start, String? end) reschedule0 = (id, d, s, e) async => meeting(id, status: 'requested');
  Future<ParentMeeting> Function(String id, PtmOutcomeRequest r) outcome0 = (id, r) async => meeting(id, status: r.parentAttended ? 'completed' : 'no_show');
  Future<ParentMeeting> Function(String id, String item, bool done) item0 = (id, i, d) async => meeting(id, status: 'completed');
  Future<ParentMeeting> Function(String id, String reason) cancel0 = (id, r) async => meeting(id, status: 'cancelled', cancelledReason: r);

  final calls = <String>[];
  PtmCreateRequest? lastCreate;
  PtmOutcomeRequest? lastOutcome;
  ({DateTime day, String? start, String? end})? lastReschedule;

  @override
  Future<List<ParentMeeting>> fetchMeetings({required String staffId, DateTime? from, DateTime? to, String? status}) {
    calls.add('list:${from != null ? 'from' : ''}${to != null ? 'to' : ''}');
    return list(staffId, from, to);
  }

  @override
  Future<ParentMeeting> fetchMeeting(String id) {
    calls.add('one:$id');
    return one(id);
  }

  @override
  Future<List<ParentMeeting>> fetchStudentHistory(String studentId) {
    calls.add('history:$studentId');
    return history(studentId);
  }

  @override
  Future<ParentMeeting> create(PtmCreateRequest r) {
    calls.add('create');
    lastCreate = r;
    return create0(r);
  }

  @override
  Future<ParentMeeting> confirm(String id) {
    calls.add('confirm:$id');
    return confirm0(id);
  }

  @override
  Future<ParentMeeting> reschedule(String id, {required DateTime day, String? startTime, String? endTime}) {
    calls.add('reschedule:$id');
    lastReschedule = (day: day, start: startTime, end: endTime);
    return reschedule0(id, day, startTime, endTime);
  }

  @override
  Future<ParentMeeting> recordOutcome(String id, PtmOutcomeRequest r) {
    calls.add('outcome:$id');
    lastOutcome = r;
    return outcome0(id, r);
  }

  @override
  Future<ParentMeeting> setActionItem(String id, String itemId, {required bool done}) {
    calls.add('item:$id:$itemId:${done ? 'done' : 'pending'}');
    return item0(id, itemId, done);
  }

  @override
  Future<ParentMeeting> cancel(String id, String reason) {
    calls.add('cancel:$id');
    return cancel0(id, reason);
  }
}

class FakeFixturesRepository extends FixturesRepository {
  Future<List<Substitution>> Function(String staffId, DateTime? from) list = (_, __) async => [];
  Future<Substitution> Function(String id) complete0 = (id) async => fixture(id, status: 'completed');
  final calls = <String>[];

  @override
  Future<List<Substitution>> fetchFixtures({required String staffId, DateTime? from, DateTime? to, String? status}) {
    calls.add('list');
    return list(staffId, from);
  }

  @override
  Future<Substitution> complete(String id) {
    calls.add('complete:$id');
    return complete0(id);
  }
}

class FakeLeaveRepository extends LeaveRepository {
  Future<LeaveBalanceSummary> Function() balance = () async => balanceOf();
  Future<List<StaffLeaveRequest>> Function() history = () async => [];
  Future<StaffLeaveRequest> Function(StaffLeaveRequestBody b) apply0 = (b) async => leaveRow('64d00000000000000000a001', type: b.type.wire);
  final calls = <String>[];
  StaffLeaveRequestBody? lastApply;

  @override
  Future<LeaveBalanceSummary> fetchBalance() {
    calls.add('balance');
    return balance();
  }

  @override
  Future<List<StaffLeaveRequest>> fetchHistory() {
    calls.add('history');
    return history();
  }

  @override
  Future<StaffLeaveRequest> apply(StaffLeaveRequestBody body) {
    calls.add('apply');
    lastApply = body;
    return apply0(body);
  }
}
