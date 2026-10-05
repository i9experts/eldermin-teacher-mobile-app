import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/behaviour/behaviour_models.dart';
import 'package:eldermin_teacher_app/core/models/homework/homework_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/behaviour_repository.dart';
import 'package:eldermin_teacher_app/core/services/homework_repository.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic fx(String n) => jsonDecode(File('test/fixtures/phase5b/$n.json').readAsStringSync());

typedef Call = ({String method, String path, Map<String, dynamic>? q, dynamic body});

class _Client extends BaseClient {
  final Object? Function(String method, String path, Map<String, dynamic>? q, dynamic body) handler;
  final calls = <Call>[];
  final multipartFiles = <Map<String, List<MultipartFile>>>[];
  _Client(this.handler);

  Response _respond(String method, String url, Map<String, dynamic>? q, dynamic body) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, q: q, body: body));
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
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('GET', url, queryParameters, null);
  @override
  Future<Response> post(String url,
          {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('POST', url, queryParameters, data);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) async =>
      _respond('PATCH', url, queryParameters, data);
  @override
  Future<Response> delete(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) async =>
      _respond('DELETE', url, queryParameters, data);
  @override
  Future<Response> multipart(String url,
      {required Map<String, List<MultipartFile>> files,
      Map<String, dynamic>? fields,
      String method = 'POST',
      void Function(int sent, int total)? onSendProgress,
      bool requiresAuth = true}) async {
    multipartFiles.add(files);
    onSendProgress?.call(5, 10);
    onSendProgress?.call(10, 10);
    return _respond(method, url, null, files);
  }
}

void main() {
  const staff = '64a0000000000000000000a1';

  group('HomeworkRepository', () {
    test('fetchMine sends teacherId and drops other teachers\' rows defensively', () async {
      final all = [...(fx('assignments') as List), {'_id': 'zz', 'teacherId': '64a0000000000000000000a9', 'title': 'Colleague'}];
      final c = _Client((m, p, q, b) => all);
      final list = await HomeworkRepository(c).fetchMine(staff);
      expect(c.calls.single.path, '/teaching/assignments');
      expect(c.calls.single.q, {'teacherId': staff});
      expect(list, hasLength(4));
      expect(list.any((a) => a.id == 'zz'), isFalse);
    });

    test('create posts the DTO body with my staff id and returns the created row', () async {
      final input = AssignmentInput(title: 'T', subject: 'S', gradeLevel: 'Grade 5', sectionName: 'A', assignedDay: DateTime(2026, 10, 5), dueDay: DateTime(2026, 10, 9));
      final c = _Client((m, p, q, b) => {'_id': 'new1', 'title': 'T', 'status': 'assigned', 'teacherId': staff});
      final a = await HomeworkRepository(c).create(input, teacherId: staff, assign: true);
      expect(a.id, 'new1');
      final call = c.calls.single;
      expect((call.method, call.path), ('POST', '/teaching/assignments'));
      expect(call.body, input.toCreateJson(teacherId: staff, assign: true));
      expect((call.body as Map)['teacherId'], staff);
    });

    test('update patches and delete deletes by id', () async {
      final c = _Client((m, p, q, b) => m == 'DELETE' ? {'deleted': true} : {'_id': 'a1', 'title': 'N'});
      final r = HomeworkRepository(c);
      expect((await r.update('a1', {'title': 'N'})).title, 'N');
      await r.delete('a1');
      expect(c.calls.map((x) => '${x.method} ${x.path}'), ['PATCH /teaching/assignments/a1', 'DELETE /teaching/assignments/a1']);
    });

    test('submissions result carries the assignment and the rows', () async {
      final c = _Client((m, p, q, b) => fx('submissions'));
      final res = await HomeworkRepository(c).fetchSubmissions('a1');
      expect(c.calls.single.path, '/teaching/assignments/a1/submissions');
      expect(res.submissions, isNotEmpty);
    });

    test('grade sends integer grades as ints, drops blank feedback and returns the row', () async {
      final c = _Client((m, p, q, b) => {'_id': 's1', 'status': 'graded', 'grade': 18, 'maxGrade': 20});
      final r = HomeworkRepository(c);
      final s = await r.grade('a1', 's1', grade: 18.0, feedback: '  ');
      expect(s.isGraded, isTrue);
      expect(c.calls.single.path, '/teaching/assignments/a1/submissions/s1');
      expect(c.calls.single.body, {'grade': 18});
      await r.grade('a1', 's1', grade: 17.5, feedback: ' Nice ');
      expect(c.calls.last.body, {'grade': 17.5, 'feedback': 'Nice'});
    });

    test('server rejection surfaces the server message and status', () async {
      final c = _Client((m, p, q, b) => 400);
      expect(
          () => HomeworkRepository(c).grade('a1', 's1', grade: 5),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400).having((e) => e.message, 'message', 'msg 400')));
    });

    test('upload: field is "file", folder is homework-attachments, progress is forwarded, key parsed', () async {
      final f = File('${Directory.systemTemp.path}/hw_upload_test.pdf')..writeAsBytesSync([37, 80, 68, 70]);
      final c = _Client((m, p, q, b) => fx('upload_single'));
      final progress = <(int, int)>[];
      final up = await HomeworkRepository(c).upload(path: f.path, fileName: 'Worksheet.pdf', onProgress: (s, t) => progress.add((s, t)));
      expect(c.calls.single.path, '/upload/single/homework-attachments');
      expect(c.multipartFiles.single.keys, ['file']);
      final mf = c.multipartFiles.single['file']!.single;
      expect(mf.filename, 'Worksheet.pdf');
      expect(mf.contentType.toString(), 'application/pdf');
      expect(progress, [(5, 10), (10, 10)]);
      expect(up.key, startsWith('demo-school/homework-attachments/'));
    });

    test('upload: a 2xx without a key is an error, a 413 keeps its status', () async {
      final f = File('${Directory.systemTemp.path}/hw_upload_test2.pdf')..writeAsBytesSync([1]);
      final noKey = _Client((m, p, q, b) => {'success': true, 'data': {}});
      expect(() => HomeworkRepository(noKey).upload(path: f.path, fileName: 'a.pdf'), throwsA(isA<ApiException>()));
      final big = _Client((m, p, q, b) => 413);
      expect(() => HomeworkRepository(big).upload(path: f.path, fileName: 'a.pdf'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 413)));
    });

    test('signedUrl reads { url }', () async {
      final c = _Client((m, p, q, b) => fx('signed_url'));
      final u = await HomeworkRepository(c).signedUrl('demo-school/homework-attachments/x.pdf');
      expect(u, contains('/__stub/files/'));
      expect(c.calls.single.q, {'key': 'demo-school/homework-attachments/x.pdf'});
      final empty = _Client((m, p, q, b) => {});
      expect(() => HomeworkRepository(empty).signedUrl('k'), throwsA(isA<ApiException>()));
    });
  });

  group('BehaviourRepository', () {
    const cls = ClassRef(grade: 'Grade 5', section: 'A');
    final recs = fx('behaviour_records') as Map<String, dynamic>;

    test('class records: one request per raw grade variant, scoped client-side, de-duplicated, newest first', () async {
      final c = _Client((m, p, q, b) => recs);
      final out = await BehaviourRepository(c).fetchClassRecords(cls, grades: const ['Grade 5', '5']);
      expect(c.calls.map((x) => x.q!['grade']).toSet(), {'Grade 5', '5'});
      expect(c.calls.every((x) => x.q!['limit'] == 100 && x.path == '/behaviour/records'), isTrue);
      expect(out.every(cls.containsRecord), isTrue);
      expect(out.map((r) => r.id).toSet().length, out.length);
      expect(out.any((r) => r.studentName.contains('') && r.section == 'B'), isFalse);
      final days = out.map((r) => r.day!).toList();
      expect([...days]..sort((a, b) => b.compareTo(a)), days);
    });

    test('pages until meta.pages (bounded)', () async {
      var n = 0;
      final c = _Client((m, p, q, b) {
        n++;
        return {'data': [], 'meta': {'total': 500, 'page': '$n', 'limit': '100', 'pages': 5}};
      });
      await BehaviourRepository(c).fetchClassRecords(cls, grades: const ['Grade 5']);
      expect(n, BehaviourRepository.maxPagesPerGrade);
    });

    test('student records are filtered to that student', () async {
      final sid = (recs['data'] as List).first['studentId'] as String;
      final c = _Client((m, p, q, b) => recs);
      final out = await BehaviourRepository(c).fetchStudentRecords(sid);
      expect(c.calls.single.q!['studentId'], sid);
      expect(out.every((r) => r.studentId == sid), isTrue);
      expect(out, isNotEmpty);
    });

    test('create posts the draft body verbatim', () async {
      final c = _Client((m, p, q, b) => {'_id': 'n1', 'type': 'positive', 'category': 'leadership', 'title': 'T'});
      final body = <String, Object?>{'studentId': 'x', 'type': 'positive'};
      final r = await BehaviourRepository(c).create(body);
      expect(r.id, 'n1');
      expect((c.calls.single.method, c.calls.single.path, c.calls.single.body), ('POST', '/behaviour/records', body));
    });

    test('tarbiyah is read-only history for one student', () async {
      final c = _Client((m, p, q, b) => fx('tarbiyah'));
      final sid = ((fx('tarbiyah') as Map)['data'] as List).first['studentId'] as String;
      final out = await BehaviourRepository(c).fetchTarbiyah(sid);
      expect(out, hasLength(1));
      expect(c.calls.single.path, '/behaviour/tarbiyah');
    });

    test('403 keeps its status', () async {
      final c = _Client((m, p, q, b) => 403);
      expect(() => BehaviourRepository(c).fetchStudentRecords('x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 403)));
    });
  });
}
