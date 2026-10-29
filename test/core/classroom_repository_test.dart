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

    test('results come from the marks collection: marks/list?studentId, newest first, max 5, unentered rows dropped', () async {
      Map<String, Object?> row(String title, String at, {Object? obtained = 40, bool absent = false}) => {
            'assessmentTitle': title,
            'subject': 'Maths',
            'totalMarks': 50,
            'obtainedMarks': obtained,
            'isAbsent': absent,
            'isExempt': false,
            'percentage': 80,
            'grade_result': 'A',
            'updatedAt': at,
          };
      final c = _Client((m, p, q, b) => {
            'data': [
              for (var i = 1; i <= 6; i++) row('T$i', '2026-0$i-01T00:00:00.000Z'),
              row('Not yet entered', '2026-09-01T00:00:00.000Z', obtained: null),
              row('Away', '2026-08-15T00:00:00.000Z', obtained: null, absent: true),
            ],
            'meta': {'total': 8, 'page': 1, 'limit': 200, 'pages': 1},
          });
      final r = await StudentsRepository(c).fetchStudentResults('sid1');
      expect(c.calls.single.path, '/assessments/marks/list');
      expect(c.calls.single.q, containsPair('studentId', 'sid1'));
      expect(r.map((e) => e.title), ['Away', 'T6', 'T5', 'T4', 'T3']);
      expect(r.first.type, 'Absent');
      expect(r[1].percentage, 80);
      expect(r[1].overallGrade, 'A');
      expect(r[1].max, 50);
    });

    test('results: 403 surfaces as ApiException 403, a non-list body is an unexpected-shape error', () async {
      await expectLater(StudentsRepository(_Client((m, p, q, b) => 403)).fetchStudentResults('x'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      await expectLater(StudentsRepository(_Client((m, p, q, b) => {'oops': true})).fetchStudentResults('x'), throwsA(isA<Object>()));
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

    test('subject-wise: fetchRange sends `subject` only when given; the write body carries `subject` only when given', () async {
      final c = _Client((m, p, q, b) => {'data': [], 'meta': {'total': 0, 'page': 1, 'limit': 1000, 'pages': 0}});
      await AttendanceRepository(c).fetchRange(grade: 'g', firstDay: DateTime(2026, 10, 1), lastDay: DateTime(2026, 10, 1), subject: 'Maths');
      await AttendanceRepository(c).fetchRange(grade: 'g', firstDay: DateTime(2026, 10, 1), lastDay: DateTime(2026, 10, 1));
      await AttendanceRepository(c).fetchRange(grade: 'g', firstDay: DateTime(2026, 10, 1), lastDay: DateTime(2026, 10, 1), subject: '');
      expect(c.calls[0].q!['subject'], 'Maths');
      expect(c.calls[1].q!.containsKey('subject'), isFalse);
      expect(c.calls[2].q!.containsKey('subject'), isFalse);
      final w = AttendanceWrite(studentId: 'a' * 24, studentName: 'A', grade: 'G', day: DateTime(2026, 10, 5), status: AttendanceStatus.present, subject: 'Maths');
      final daily = AttendanceWrite(studentId: 'a' * 24, studentName: 'A', grade: 'G', day: DateTime(2026, 10, 5), status: AttendanceStatus.present);
      expect(w.toJson(), {'studentId': 'a' * 24, 'studentName': 'A', 'grade': 'G', 'date': '2026-10-05T12:00:00.000Z', 'status': 'present', 'subject': 'Maths'});
      expect(daily.toJson().containsKey('subject'), isFalse);
    });

    test('fetchMode: GET /teaching/attendance-settings; subject_wise / daily / unknown -> daily; 404/501 -> daily; other errors rethrown', () async {
      Future<AttendanceMode> mode(Object? r) => AttendanceRepository(_Client((m, p, q, b) => r)).fetchMode();
      expect(await mode({'mode': 'subject_wise'}), AttendanceMode.subjectWise);
      expect(await mode({'mode': 'daily'}), AttendanceMode.daily);
      expect(await mode({'mode': 'period_wise'}), AttendanceMode.daily);
      expect(await mode({}), AttendanceMode.daily);
      expect(await mode(404), AttendanceMode.daily);
      expect(await mode(501), AttendanceMode.daily);
      for (final code in [401, 403, 500]) {
        await expectLater(mode(code), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code)));
      }
      // 403 (custom role without the attendance-settings grant) is the ONE distinct typed outcome; 401 / 500 stay plain errors (never a guess)
      await expectLater(mode(403), throwsA(isA<AttendanceModeForbidden>()));
      for (final code in [401, 500, 502]) {
        await expectLater(mode(code), throwsA(isNot(isA<AttendanceModeForbidden>())));
      }
      await expectLater(mode('not json'), throwsA(isA<ApiException>()));
      final c = _Client((m, p, q, b) => {'mode': 'daily'});
      await AttendanceRepository(c).fetchMode();
      expect(c.calls.single.path, '/teaching/attendance-settings');
    });

    test('fetchSubjectNames: GET /academics/subjects, names only, de-duplicated, bare array or {data}; wrong shape is an error not an empty list', () async {
      final rows = [
        {'_id': '1', 'name': 'English'}, {'_id': '2', 'name': ' Maths '}, {'_id': '3', 'name': 'English'}, {'_id': '4'}, {'_id': '5', 'name': ''}
      ];
      var c = _Client((m, p, q, b) => rows);
      expect(await AttendanceRepository(c).fetchSubjectNames(), ['English', 'Maths']);
      expect(c.calls.single.path, '/academics/subjects');
      expect(c.calls.single.q, isNull); // same call as the web picker: no assignedOnly
      expect(await AttendanceRepository(_Client((m, p, q, b) => {'data': rows})).fetchSubjectNames(), ['English', 'Maths']);
      expect(await AttendanceRepository(_Client((m, p, q, b) => [])).fetchSubjectNames(), isEmpty);
      await expectLater(AttendanceRepository(_Client((m, p, q, b) => 'oops')).fetchSubjectNames(), throwsA(isA<ApiException>()));
      await expectLater(AttendanceRepository(_Client((m, p, q, b) => 403)).fetchSubjectNames(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    });
  

    group('checkDay', () {
      Future<SchoolDayStatus> check(Object? r, {String? grade = 'Grade 5'}) =>
          AttendanceRepository(_Client((m, p, q, b) => r)).checkDay(day: DateTime(2026, 10, 25), grade: grade);

      test('GET /students/attendance/check-day with the noon-UTC date and the grade', () async {
        final c = _Client((m, p, q, b) => {'valid': true, 'configured': true});
        await AttendanceRepository(c).checkDay(day: DateTime(2026, 10, 25), grade: 'Grade 5');
        expect(c.calls.single.method, 'GET');
        expect(c.calls.single.path, '/students/attendance/check-day');
        expect(c.calls.single.q, {'date': '2026-10-25T12:00:00.000Z', 'grade': 'Grade 5'});
        final d = _Client((m, p, q, b) => {});
        await AttendanceRepository(d).checkDay(day: DateTime(2026, 10, 25));
        expect(d.calls.single.q!.containsKey('grade'), isFalse);
      });

      test('parsing: valid, not configured, invalid with reason, missing fields', () async {
        var s = await check({'valid': true, 'configured': true});
        expect((s.valid, s.configured, s.unknown), (true, true, false));
        s = await check({'valid': true, 'configured': false});
        expect((s.valid, s.configured), (true, false));
        s = await check({'valid': false, 'configured': true, 'reason': 'x is a holiday: Eid'});
        expect((s.valid, s.reason, s.unknown), (false, 'x is a holiday: Eid', false));
        s = await check({});
        expect((s.valid, s.configured, s.reason, s.unknown), (true, false, null, false));
        s = await check({'valid': 'maybe', 'reason': 5});
        expect(s.valid, isTrue);
      });

      test('404 (older server) = valid; 500, 401, network-ish and a wrong shape = unknown (never throws)', () async {
        final nf = await check(404);
        expect((nf.valid, nf.unknown), (true, false));
        for (final r in <Object?>[500, 401, 403, 'not json']) {
          final s = await check(r);
          expect((s.unknown, s.valid), (true, true), reason: '$r');
        }
        final offline = AttendanceRepository(_ThrowingClient());
        expect((await offline.checkDay(day: DateTime(2026, 10, 25), grade: 'g')).unknown, isTrue);
      });
    });
  });
}

class _ThrowingClient extends BaseClient {
  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      throw DioException(requestOptions: RequestOptions(path: url), type: DioExceptionType.connectionError);
}
