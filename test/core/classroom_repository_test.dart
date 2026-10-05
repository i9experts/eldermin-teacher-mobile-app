import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/classroom/attendance_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/attendance_repository.dart';
import 'package:eldermin_teacher_app/core/services/students_repository.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic fx(String n) => jsonDecode(File('test/fixtures/classroom/$n.json').readAsStringSync());

class _Client extends BaseClient {
  final Object? Function(String method, String path, Map<String, dynamic>? q, dynamic body) handler;
  final calls = <({String method, String path, Map<String, dynamic>? q, dynamic body, Map<String, String>? headers})>[];
  _Client(this.handler);

  Response _respond(String method, String url, Map<String, dynamic>? q, dynamic body, Map<String, String>? headers) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, q: q, body: body, headers: headers));
    final ro = RequestOptions(path: url);
    final r = handler(method, path, q, body);
    if (r is int) {
      throw DioException(
          requestOptions: ro,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: ro, statusCode: r, data: {'statusCode': r, 'message': 'msg $r'}));
    }
    return Response(requestOptions: ro, statusCode: method == 'POST' ? 201 : 200, data: r);
  }

  @override
  Future<Response> get(String url,
          {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('GET', url, queryParameters, null, headers);

  @override
  Future<Response> post(String url,
          {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('POST', url, queryParameters, data, headers);
}

void main() {
  const cls = ClassRef(grade: 'Grade 5', section: 'A', isClassTeacherClass: true);

  group('StudentsRepository', () {
    test('roster asks for raw grade/section variants, active only, limit 200, and re-scopes client-side', () async {
      final polluted = (fx('students_list') as Map<String, dynamic>);
      final data = [...(polluted['data'] as List), {'_id': 'zzz', 'firstName': 'Other', 'currentGrade': 'Grade 5', 'currentSection': 'B', 'status': 'active'}];
      final c = _Client((m, p, q, b) => p == '/students'
          ? {'data': data, 'meta': {'total': data.length, 'page': 1, 'limit': 200, 'pages': 1}}
          : throw StateError(p));
      final known = (await StudentsRepository(_Client((m, p, q, b) => fx('grades_sections'))).fetchGradesSections());
      final roster = await StudentsRepository(c).fetchClassRoster(cls, known: known);
      final q = c.calls.single.q!;
      expect((q['grade'] as List).toSet(), {'Grade 5', '5'});
      expect((q['section'] as List).toSet(), {'A', 'a'});
      expect(q['status'], 'active');
      expect(q['limit'], 200);
      expect(roster, hasLength(30)); // the foreign-section row is dropped client-side
      expect(roster.any((s) => s.id == 'zzz'), isFalse);
    });

    test('roster pages until meta.pages', () async {
      var n = 0;
      final c = _Client((m, p, q, b) {
        n++;
        return {
          'data': [
            {'_id': 'p$n', 'firstName': 'S$n', 'currentGrade': 'Grade 5', 'currentSection': 'A', 'status': 'active'}
          ],
          'meta': {'total': 3, 'page': n, 'limit': 1, 'pages': 3}
        };
      });
      final roster = await StudentsRepository(c).fetchClassRoster(cls);
      expect(roster.map((s) => s.id), ['p1', 'p2', 'p3']);
      expect(c.calls.map((e) => e.q!['page']), [1, 2, 3]);
    });

    test('repeated params are serialised as grade=a&grade=b by Dio', () {
      final uri = RequestOptions(path: 'http://h/api/v1/students', queryParameters: {
        'grade': ['Grade 5', '5'],
        'section': ['A']
      }).uri;
      expect(uri.query, contains('grade=Grade+5&grade=5'));
    });

    test('360 is parsed through the whitelist; summary asks for the month', () async {
      final c = _Client((m, p, q, b) => p.endsWith('/360') ? fx('student_360') : fx('attendance_summary'));
      final repo = StudentsRepository(c);
      final d = await repo.fetchStudent360('sid');
      expect(d.debugDump(), isNot(contains('monthlyIncome')));
      expect(d.debugDump(), isNot(contains('18500')));
      final s = await repo.fetchAttendanceSummary('sid', year: 2026, month: 3);
      expect(c.calls.last.q, {'month': '2026-03'});
      expect(s.total, greaterThan(0));
    });

    test('403 and 404 surface as ApiException with the status code', () async {
      final c = _Client((m, p, q, b) => 403);
      await expectLater(StudentsRepository(c).fetchStudent360('x'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      await expectLater(StudentsRepository(_Client((m, p, q, b) => 404)).fetchClassRoster(cls),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    });
  });

  group('AttendanceRepository', () {
    test('range uses from/to (never date), the noon-bracketing window, grade/section, limit 1000', () async {
      final c = _Client((m, p, q, b) => fx('attendance_list'));
      final recs = await AttendanceRepository(c).fetchRange(
          grade: 'Grade 5', section: 'A', firstDay: DateTime(2026, 10, 5), lastDay: DateTime(2026, 10, 5));
      expect(recs, isNotEmpty);
      final q = c.calls.first.q!;
      expect(q.containsKey('date'), isFalse);
      expect(q['from'], '2026-10-04T12:00:00.000Z');
      expect(q['to'], '2026-10-05T12:00:00.000Z');
      expect(q['grade'], 'Grade 5');
      expect(q['section'], 'A');
      expect(q['limit'], 1000);
    });

    test('range follows meta.pages', () async {
      var n = 0;
      final c = _Client((m, p, q, b) {
        n++;
        return {
          'data': [
            {'studentId': 's$n', 'status': 'present', 'date': '2026-10-02T00:00:00.000Z'}
          ],
          'meta': {'total': 2, 'page': n, 'limit': 1000, 'pages': 2}
        };
      });
      final recs = await AttendanceRepository(c).fetchRange(grade: 'g', firstDay: DateTime(2026, 10, 1), lastDay: DateTime(2026, 10, 31));
      expect(recs, hasLength(2));
      expect(c.calls, hasLength(2));
      expect(c.calls.first.q!.containsKey('section'), isFalse);
    });

    test('bulk body matches MarkAttendanceDto, header carries the academic year, response body ignored', () async {
      final c = _Client((m, p, q, b) => fx('bulk_result'));
      await AttendanceRepository(c).submit([
        AttendanceWrite(studentId: 'a' * 24, studentName: 'A B', grade: 'Grade 5', section: 'A', day: DateTime(2026, 10, 5), status: AttendanceStatus.halfDay),
        AttendanceWrite(studentId: 'b' * 24, studentName: 'C D', grade: 'Grade 5', day: DateTime(2026, 10, 5), status: AttendanceStatus.excused),
      ], academicYear: '2026-27');
      final call = c.calls.single;
      expect(call.path, '/students/attendance/bulk');
      expect(call.headers, {'x-academic-year': '2026-27'});
      final recs = (call.body as Map)['records'] as List;
      expect((call.body as Map).keys, ['records']); // no schoolSlug/academicYear in the body
      expect(recs.first, {
        'studentId': 'a' * 24, 'studentName': 'A B', 'grade': 'Grade 5', 'section': 'A',
        'date': '2026-10-05T12:00:00.000Z', 'status': 'half_day'
      });
      expect((recs[1] as Map).containsKey('section'), isFalse);
      expect((recs[1] as Map)['status'], 'excused');
    });

    test('no academic-year header when unknown; 403/409/400/500 keep status and message', () async {
      for (final code in [400, 403, 409, 500]) {
        final c = _Client((m, p, q, b) => code);
        await expectLater(
            AttendanceRepository(c).submit([
              AttendanceWrite(studentId: 'a' * 24, studentName: 'x', grade: 'g', day: DateTime(2026, 10, 5), status: AttendanceStatus.present)
            ]),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code).having((e) => e.message, 'message', 'msg $code')));
        expect(c.calls.single.headers, isEmpty);
      }
    });
  });
}
