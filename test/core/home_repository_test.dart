import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Client extends BaseClient {
  final Map<String, Object? Function(Map<String, dynamic>? q)> routes;
  final requests = <String>[];
  Map<String, dynamic>? lastQuery;
  _Client(this.routes);

  @override
  Future<Response> get(String url,
      {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    requests.add(path);
    lastQuery = queryParameters;
    final h = routes[path];
    if (h == null) throw StateError('unexpected $path');
    final ro = RequestOptions(path: url);
    final body = h(queryParameters);
    if (body is int) {
      throw DioException(
          requestOptions: ro,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: ro, statusCode: body, data: {'statusCode': body, 'message': 'boom $body'}));
    }
    return Response(requestOptions: ro, statusCode: 200, data: body);
  }
}

dynamic fx(String n) => jsonDecode(File('test/fixtures/home/$n.json').readAsStringSync());

void main() {
  const staff = '64a0000000000000000000a1';

  test('timetable is requested with the staffId path param and parsed', () async {
    final c = _Client({'/teaching/timetable/teacher/$staff': (_) => fx('timetable')});
    final docs = await HomeRepository(c).fetchTeacherTimetable(staff);
    expect(docs, hasLength(2));
  });

  test('every teacher-scoped list sends the staffId explicitly', () async {
    final c = _Client({
      '/teaching/assignments': (_) => fx('assignments'),
      '/teaching/lesson-plans': (_) => fx('lesson_plans'),
      '/teaching/ptm/upcoming/mine': (_) => fx('ptm_upcoming'),
      '/teaching/fixtures': (_) => fx('fixtures_covering'),
    });
    final r = HomeRepository(c);
    await r.fetchAssignments(staff);
    expect(c.lastQuery, {'teacherId': staff});
    await r.fetchLessonPlans(staff, 'rejected');
    expect(c.lastQuery, {'teacherId': staff, 'status': 'rejected'});
    await r.fetchUpcomingPtms(staff);
    expect(c.lastQuery, {'teacherId': staff});
    final from = DateTime.utc(2026, 10, 5), to = DateTime.utc(2026, 10, 5, 23, 59, 59, 999);
    await r.fetchSubstitutions(staff, from: from, to: to);
    expect(c.lastQuery!['teacherId'], staff);
    expect(c.lastQuery!['from'], '2026-10-05T00:00:00.000Z');
    expect(c.lastQuery!['to'], '2026-10-05T23:59:59.999Z');
  });

  test('attendance count asks limit=1 with a whole-day range and reads meta.total', () async {
    final c = _Client({'/students/attendance/list': (_) => fx('attendance_list')});
    final n = await HomeRepository(c).fetchAttendanceCount(
        grade: 'Grade 5', section: 'A', from: DateTime.utc(2026, 10, 5), to: DateTime.utc(2026, 10, 5, 23, 59, 59));
    expect(n, 27);
    expect(c.lastQuery!['limit'], 1);
    expect(c.lastQuery!['grade'], 'Grade 5');
  });

  test('threads + unread-count', () async {
    final c = _Client({
      '/staff-portal/threads': (_) => fx('threads'),
      '/staff-portal/notifications/unread-count': (_) => fx('unread_count'),
    });
    final r = HomeRepository(c);
    expect((await r.fetchOpenThreads()).unreadCount, 2);
    expect(await r.fetchNotificationUnreadCount(), 3);
  });

  test('wrapped {data: [...]} lists are tolerated', () async {
    final c = _Client({'/teaching/ptm/upcoming/mine': (_) => {'data': fx('ptm_upcoming')}});
    expect(await HomeRepository(c).fetchUpcomingPtms(staff), hasLength(2));
  });

  test('HTTP errors map to ApiException with the status code', () async {
    for (final code in [403, 404, 500]) {
      final c = _Client({'/staff-portal/threads': (_) => code});
      await expectLater(
          HomeRepository(c).fetchOpenThreads(),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code)));
    }
  });
}
