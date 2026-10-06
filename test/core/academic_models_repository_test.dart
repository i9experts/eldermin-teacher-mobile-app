import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/academic/lesson_plan_models.dart';
import 'package:eldermin_teacher_app/core/models/academic/syllabus_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/lesson_plan_repository.dart';
import 'package:eldermin_teacher_app/core/services/syllabus_repository.dart';
import 'package:flutter_test/flutter_test.dart';

dynamic fx(String n) => jsonDecode(File('test/fixtures/phase6a/$n.json').readAsStringSync());

typedef Call = ({String method, String path, Map<String, dynamic>? q, dynamic body, Map<String, dynamic>? fields});

class _Client extends BaseClient {
  final Object? Function(String method, String path, Map<String, dynamic>? q, dynamic body) handler;
  final calls = <Call>[];
  final fileFields = <List<String>>[];
  _Client(this.handler);

  Response _respond(String method, String url, Map<String, dynamic>? q, dynamic body, {Map<String, dynamic>? fields}) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, q: q, body: body, fields: fields));
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
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async =>
      _respond('POST', url, queryParameters, data);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) async =>
      _respond('PATCH', url, queryParameters, data);
  @override
  Future<Response> multipart(String url,
      {required Map<String, List<MultipartFile>> files,
      Map<String, dynamic>? fields,
      String method = 'POST',
      void Function(int sent, int total)? onSendProgress,
      bool requiresAuth = true}) async {
    fileFields.add(files.keys.toList());
    return _respond(method, url, null, files, fields: fields);
  }
}

void main() {
  const staff = '64a0000000000000000000a1';
  const profile = '64a0000000000000000000b1';

  group('LessonPlanRecord (stub fixture = backend schema shape)', () {
    final plans = (fx('lesson_plans') as List).map((e) => LessonPlanRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    LessonPlanRecord byTopic(String t) => plans.firstWhere((p) => p.topic.startsWith(t));

    test('reads topic (not title), objectives, resources, class and status', () {
      final p = byTopic('Fractions');
      expect(p.topic, startsWith('Fractions'));
      expect(p.status, LessonPlanStatus.rejected);
      expect(p.learningObjectives, hasLength(2));
      expect(p.resources, ['Textbook', 'Whiteboard']);
      expect(p.classLabel, 'Grade 5 - A');
      expect(p.teachingMethodology, 'lecture');
      expect(p.teacherId, staff);
    });

    test('rejection reason is kept ONLY for a rejected plan (the server never clears it)', () {
      expect(byTopic('Fractions').rejectionReason, contains('assessment'));
      final stale = byTopic('Percentages');
      expect(stale.status, LessonPlanStatus.submitted);
      expect(stale.rejectionReason, isNull);
    });

    test('approver notes only on an approved plan', () {
      expect(byTopic('Ratios').approverNotes, contains('exit ticket'));
      expect(byTopic('Decimals').approverNotes, isNull);
    });

    test('edit / submit rules', () {
      expect(byTopic('Geometry').canEdit && byTopic('Geometry').canSubmit, isTrue);
      expect(byTopic('Fractions').canEdit, isTrue);
      expect(byTopic('Fractions').canSubmit, isFalse); // rejected: edit then resubmit
      expect(byTopic('Decimals').canEdit, isFalse); // under review
      expect(byTopic('Ratios').canEdit, isFalse); // approved
      expect(byTopic('Angles').canSubmit, isTrue); // overdue
    });

    test('plan day is the stored calendar day whatever the device zone', () {
      final p = LessonPlanRecord.fromJson({'_id': 'x', 'planDate': '2026-10-06T00:00:00.000Z'});
      expect(p.planDay, DateTime(2026, 10, 6));
    });

    test('unknown status is shown as unknown, not crashed on', () {
      expect(LessonPlanRecord.fromJson({'_id': 'x', 'status': 'weird'}).status, LessonPlanStatus.unknown);
      expect(LessonPlanRecord.fromJson({'_id': 'x'}).status, LessonPlanStatus.unknown);
    });

    test('sensitive / unused fields are not exposed by the model', () {
      final src = File('lib/core/models/academic/lesson_plan_models.dart').readAsStringSync();
      for (final k in ["'tenantId'", "'institutionId'", "'campusId'", "'approvedBy'"]) {
        expect(src.contains("j[$k]"), isFalse, reason: k);
      }
    });
  });

  group('LessonPlanInput wire bodies', () {
    final day = DateTime(2026, 10, 7);
    LessonPlanInput input({String topic = 'Fractions', List<String> objectives = const ['a'], String homework = '', DateTime? d, int? mins = 40, List<String> resources = const []}) =>
        LessonPlanInput(subject: 'Mathematics', gradeLevel: 'Grade 5', sectionName: 'A', topic: topic, planDay: d ?? day, durationMins: mins, objectives: objectives, homework: homework, resources: resources);

    test('create body: objectives (renamed by the server), YYYY-MM-DD, no campusId/tenantId, status', () {
      final body = input().toCreateJson(teacherId: staff, teacherName: 'Tess', status: LessonPlanStatus.submitted);
      expect(body['teacherId'], staff);
      expect(body['objectives'], ['a']);
      expect(body['planDate'], '2026-10-07');
      expect(body['status'], 'submitted');
      expect(body.keys, isNot(containsAll(['campusId'])));
      expect(body.containsKey('learningObjectives'), isFalse);
      expect(body.containsKey('description'), isFalse); // empty optionals omitted
    });

    final orig = LessonPlanRecord.fromJson({
      '_id': 'p1', 'topic': 'Fractions', 'subject': 'Mathematics', 'gradeLevel': 'Grade 5', 'sectionName': 'A', 'planDate': '2026-10-07T00:00:00.000Z',
      'durationMins': 40, 'learningObjectives': ['a'], 'resources': <String>[], 'homework': '', 'status': 'rejected', 'rejectionReason': 'r', 'teacherId': staff,
    });

    test('RAW \$SET SAFETY: no change -> empty patch', () {
      expect(input().toPatchJson(orig), isEmpty);
    });

    test('RAW \$SET SAFETY: only the edited fields are sent, objectives under learningObjectives, no server fields', () {
      final p = input(topic: 'Fractions 2', objectives: ['a', 'b'], homework: 'Ex 1', d: DateTime(2026, 10, 9)).toPatchJson(orig);
      expect(p.keys.toSet(), {'topic', 'learningObjectives', 'homework', 'planDate'});
      expect(p['learningObjectives'], ['a', 'b']);
      expect(p['planDate'], '2026-10-09');
      for (final k in ['status', 'approvedBy', 'rejectionReason', 'approverNotes', 'tenantId', 'teacherId', 'campusId', 'objectives', 'subject', 'gradeLevel']) {
        expect(p.containsKey(k), isFalse, reason: k);
      }
    });

    test('resubmit adds ONLY status:submitted on top of the edits', () {
      final p = input(topic: 'Fractions 2').toPatchJson(orig, status: LessonPlanStatus.submitted);
      expect(p, {'topic': 'Fractions 2', 'status': 'submitted'});
      expect(input().toPatchJson(orig, status: LessonPlanStatus.submitted), {'status': 'submitted'});
    });

    test('clearing a filled optional field sends an empty string; resources change is detected', () {
      final withHw = LessonPlanRecord.fromJson({'_id': 'p', 'topic': 'T', 'planDate': '2026-10-07T00:00:00.000Z', 'homework': 'x', 'resources': ['Textbook']});
      final p = LessonPlanInput(subject: 's', gradeLevel: 'g', topic: 'T', planDay: day, homework: '', resources: const ['Textbook', 'Video']).toPatchJson(withHw);
      expect(p, {'homework': '', 'resources': ['Textbook', 'Video']});
    });
  });

  group('LessonPlanDraft (parse-upload response)', () {
    test('parses the real response shape and drops unknown methodology / resources', () {
      final d = LessonPlanDraft.fromJson(Map<String, dynamic>.from(fx('parse_upload') as Map));
      expect(d.topic, contains('Equivalent fractions'));
      expect(d.objectives, hasLength(2));
      expect(d.resources, ['Textbook', 'Handouts']);
      expect(d.otherResource, 'Paper strips; coloured pencils');
      expect(d.methodology, 'activity');
      expect(d.durationMins, 45);
      expect(d.subjectGuess, 'Maths');
      expect(d.warnings, hasLength(2));
      expect(d.sourceFileName, 'plan.docx');
      expect(d.isEmpty, isFalse);
      final odd = LessonPlanDraft.fromJson({'teachingMethodology': 'lasers', 'resources': ['Laser', 'Video'], 'topic': '', 'durationMins': null, 'sourceFileName': null});
      expect(odd.methodology, isNull);
      expect(odd.resources, ['Video']);
      expect(odd.durationMins, isNull);
      expect(odd.isEmpty, isTrue);
    });
  });

  group('LessonPlanRepository', () {
    test('fetchMine asks once per id (staff + profile), merges, re-filters and sorts newest first', () async {
      final all = fx('lesson_plans') as List;
      final c = _Client((m, p, q, b) {
        final id = q!['teacherId'];
        return [
          ...all.where((e) => (e as Map)['teacherId'] == id),
          if (id == staff) {'_id': 'zz', 'teacherId': '64a0000000000000000000a9', 'topic': 'Colleague'},
        ];
      });
      final list = await LessonPlanRepository(c).fetchMine([staff, profile, staff, '']);
      expect(c.calls.map((e) => e.q!['teacherId']), [staff, profile]);
      expect(c.calls.every((e) => e.path == '/teaching/lesson-plans'), isTrue);
      expect(list.any((p) => p.topic == 'Colleague'), isFalse);
      expect(list.any((p) => p.topic.startsWith('Legacy')), isTrue);
      final dates = list.map((p) => p.planDate!).toList();
      expect(dates, [...dates]..sort((a, b) => b.compareTo(a)));
    });

    test('create posts to /teaching/lesson-plans and returns the document', () async {
      final c = _Client((m, p, q, b) => fx('lesson_plan_created'));
      final r = await LessonPlanRepository(c).create({'topic': 'New'});
      expect(c.calls.single.method, 'POST');
      expect(r.id, isNotEmpty);
      expect(r.status, LessonPlanStatus.draft);
    });

    test('update patches /teaching/lesson-plans/:id with exactly the given body', () async {
      final c = _Client((m, p, q, b) => {...Map<String, dynamic>.from(fx('lesson_plan_created') as Map), 'status': 'submitted'});
      final r = await LessonPlanRepository(c).update('p1', {'status': 'submitted'});
      expect(c.calls.single.path, '/teaching/lesson-plans/p1');
      expect(c.calls.single.body, {'status': 'submitted'});
      expect(r.status, LessonPlanStatus.submitted);
    });

    test('update with the empty 200 body (unknown id for a teacher) becomes a 404 ApiException', () async {
      final c = _Client((m, p, q, b) => '');
      await expectLater(LessonPlanRepository(c).update('nope', {'topic': 'x'}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    });

    test('403 surfaces as ApiException(403)', () async {
      final c = _Client((m, p, q, b) => 403);
      await expectLater(LessonPlanRepository(c).create({}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    });

    test('parseUpload: file goes under the field `file`, a link under sourceUrl (never both)', () async {
      final tmp = File('${Directory.systemTemp.path}/plan_test.txt')..writeAsStringSync('Lesson on fractions with a plan that is long enough');
      final c = _Client((m, p, q, b) => fx('parse_upload'));
      final d = await LessonPlanRepository(c).parseUpload(path: tmp.path, fileName: 'plan.txt', sourceUrl: 'https://docs.google.com/document/d/abc/edit');
      expect(c.fileFields.single, ['file']);
      expect(c.calls.single.fields, isEmpty);
      expect(c.calls.single.path, '/teaching/lesson-plans/parse-upload');
      expect(d.topic, isNotEmpty);
      final c2 = _Client((m, p, q, b) => fx('parse_upload'));
      await LessonPlanRepository(c2).parseUpload(sourceUrl: ' https://docs.google.com/document/d/abc/edit ');
      expect(c2.fileFields.single, isEmpty);
      expect(c2.calls.single.fields, {'sourceUrl': 'https://docs.google.com/document/d/abc/edit'});
    });
  });

  group('Syllabus models (stub fixture = backend schema shape)', () {
    final all = (fx('syllabi') as List).map((e) => Syllabus.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    Syllabus maths() => all.firstWhere((s) => s.subjectName == 'Mathematics' && s.sectionName == 'A');

    test('tree, class label, whole-grade section and behind flag', () {
      final s = maths();
      expect(s.units, hasLength(2));
      expect(s.units.first.topics.first.subTopics, hasLength(3));
      expect(s.classLabel, 'Grade 5 - A');
      expect(s.title, 'Mathematics · Grade 5 - A');
      expect(s.isBehind, isFalse);
      expect(all.firstWhere((x) => x.subjectName == 'Science').isBehind, isTrue);
      expect(Syllabus.fromJson({'_id': 'q', 'gradeLevel': 'Grade 5'}).classLabel, 'Grade 5');
    });

    test('progress follows the server rollup: sub-topic granularity where sub-topics exist (9 items, 3 covered)', () {
      final p = maths().progress;
      expect((p.total, p.covered, p.percent), (9, 3, 33));
      expect(maths().serverTotal, 9);
      expect(maths().units.first.progress.total, 6);
      expect(maths().units.first.topics.first.progress.percent, 67); // 2 of 3
      expect(const SyllabusProgress(0, 0).percent, 0);
    });

    test('lessons are read from the topic (read-only)', () {
      final lessons = maths().units.first.topics.first.lessons;
      expect(lessons.map((l) => l.type), ['video', 'document']);
      expect(lessons.first.link, startsWith('https://'));
      expect(lessons.last.link, endsWith('practice.pdf'));
    });

    test('optimistic helpers derive the parent topic and the totals', () {
      final s = maths();
      final done = s.withSubTopicCovered(1, 1, 3, true);
      expect(done.topicAt(1, 1)!.covered, isTrue);
      expect(done.progress.covered, 4);
      final undone = done.withSubTopicCovered(1, 1, 1, false);
      expect(undone.topicAt(1, 1)!.covered, isFalse);
      expect(undone.progress.covered, 3);
      final plain = s.withTopicCovered(2, 2, true);
      expect(plain.topicAt(2, 2)!.covered, isTrue);
      expect(plain.progress.covered, 4);
      expect(s.progress.covered, 3); // original untouched (immutable)
    });

    test('planned-week queries use real plannedWeek data', () {
      final s = maths();
      expect(s.plannedIn(5).map((e) => e.sub.name), ['Mixed numbers', 'Place value']);
      expect(s.uncoveredBefore(5), isEmpty); // weeks 3 and 4 are covered
      expect(s.uncoveredBefore(8).map((e) => e.sub.name), containsAll(['Mixed numbers', 'Place value', 'Rounding', 'Perimeter']));
    });

    test('hidden coordinator fields are not read', () {
      final src = File('lib/core/models/academic/syllabus_models.dart').readAsStringSync();
      for (final k in ['publishedToStudents', 'assessmentBreakdown', 'tenantId', 'approvedBy', 'createdBy']) {
        expect(src.contains("j['$k']"), isFalse, reason: k);
      }
    });
  });

  group('PlannerEntry', () {
    test('parses the planner shape (current week only)', () {
      final e = (fx('weekly_planner') as List).map((x) => PlannerEntry.fromJson(Map<String, dynamic>.from(x as Map))).toList();
      expect(e, hasLength(2));
      expect(e.every((x) => x.currentWeek == 5), isTrue);
      expect(e.first.items.first.subTopicName, isNotEmpty);
      expect(e.first.classLabel, isNotEmpty);
    });
  });

  group('SyllabusRepository', () {
    test('list sends exactly the given query', () async {
      final c = _Client((m, p, q, b) => fx('syllabi'));
      final l = await SyllabusRepository(c).list({'teacherId': staff});
      expect(c.calls.single.path, '/syllabus');
      expect(c.calls.single.q, {'teacherId': staff});
      expect(l, hasLength(4)); // teacherId=staff: maths, science, term 3, draft art
    });

    test('markSubTopic / markTopic bodies match MarkSubTopicDto / MarkTopicDto and coveredBy is optional', () async {
      final c = _Client((m, p, q, b) => fx('syllabus_marked'));
      final repo = SyllabusRepository(c);
      final s = await repo.markSubTopic('s1', unitNo: 1, topicNo: 1, subTopicNo: 3, covered: true, coveredBy: 'Tess Teacher');
      expect(c.calls.last.path, '/syllabus/s1/mark-sub-topic');
      expect(c.calls.last.body, {'unitNo': 1, 'topicNo': 1, 'subTopicNo': 3, 'isCovered': true, 'coveredBy': 'Tess Teacher'});
      expect(s.topicAt(1, 1)!.covered, isTrue);
      await repo.markTopic('s1', unitNo: 2, topicNo: 2, covered: false);
      expect(c.calls.last.path, '/syllabus/s1/mark-topic');
      expect(c.calls.last.body, {'unitNo': 2, 'topicNo': 2, 'isCovered': false});
    });

    test('errors surface with their status; an empty saved body is an error, not a silent success', () async {
      await expectLater(SyllabusRepository(_Client((m, p, q, b) => 404)).markTopic('s', unitNo: 1, topicNo: 1, covered: true), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)));
      await expectLater(SyllabusRepository(_Client((m, p, q, b) => '')).markTopic('s', unitNo: 1, topicNo: 1, covered: true), throwsA(isA<ApiException>()));
    });

    test('weeklyPlanner asks once per distinct id and merges by syllabus', () async {
      final all = fx('weekly_planner') as List;
      final c = _Client((m, p, q, b) => all);
      final e = await SyllabusRepository(c).weeklyPlanner([staff, profile, staff]);
      expect(c.calls.map((x) => x.q!['teacherId']), [staff, profile]);
      expect(c.calls.every((x) => x.path == '/syllabus/weekly-planner'), isTrue);
      expect(e, hasLength(2));
    });
  });
}
