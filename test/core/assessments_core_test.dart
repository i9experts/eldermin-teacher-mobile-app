import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/models/assessments/assessment_models.dart';
import 'package:eldermin_teacher_app/core/models/assessments/reference_models.dart';
import 'package:eldermin_teacher_app/core/models/paginated.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:eldermin_teacher_app/core/services/reference_repository.dart';
import 'package:eldermin_teacher_app/core/services/students_repository.dart';
import 'package:eldermin_teacher_app/core/utils/assessment_scope.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_assessment_repositories.dart';

typedef Call = ({String method, String path, Map<String, dynamic>? q, dynamic body, Map<String, String>? headers});

class _Client extends BaseClient {
  final Object? Function(String method, String path, Map<String, dynamic>? q, dynamic body) handler;
  final calls = <Call>[];
  _Client(this.handler);

  Response _respond(String method, String url, Map<String, dynamic>? q, dynamic body, Map<String, String>? headers) {
    final path = Uri.parse(url).path.replaceFirst('/api/v1', '');
    calls.add((method: method, path: path, q: q, body: body, headers: headers));
    final ro = RequestOptions(path: url);
    final r = handler(method, path, q, body);
    if (r is int) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: r, data: {'statusCode': r, 'message': 'msg $r'}));
    }
    return Response(requestOptions: ro, statusCode: method == 'POST' ? 201 : 200, data: r);
  }

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('GET', url, queryParameters, null, headers);
  @override
  Future<Response> post(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async => _respond('POST', url, queryParameters, data, headers);
  @override
  Future<Response> patch(String url, {dynamic data, Map<String, dynamic>? queryParameters, bool requiresAuth = true}) async => _respond('PATCH', url, queryParameters, data, null);
}

Map<String, Object?> page(List<Object?> rows, int page, int pages, {int? total}) => {'data': rows, 'meta': {'total': total ?? rows.length, 'page': page, 'limit': rows.length, 'pages': pages}};

void main() {
  final all = fixtureAssessments();
  Assessment byTitle(String t) => all.firstWhere((a) => a.title.startsWith(t));

  group('marksText', () {
    test('trims zeros and keeps two decimals', () {
      expect(marksText(10), '10');
      expect(marksText(7.5), '7.5');
      expect(marksText(7.25), '7.25');
      expect(marksText(7.2500001), '7.25');
      expect(marksText(0), '0');
      expect(marksText(33.333), '33.33');
    });
  });

  group('Assessment (stub fixture = ASC:33-96)', () {
    test('reads class, term, subjects with totals and the quiz-paper flag', () {
      final a = byTitle('Unit Test 1');
      expect(a.grade, 'Grade 5');
      expect(a.section, 'A');
      expect(a.status, 'ongoing');
      expect(a.subjects.map((s) => (s.subject, s.totalMarks, s.passingMarks)), [('Mathematics', 50.0, 20.0), ('English', 30.0, 12.0)]);
      expect(a.isOnline, isFalse);
      final q = byTitle('Online Quiz');
      expect(q.isOnline, isTrue);
      expect(q.subjects.single.hasQuizPaper, isTrue);
    });

    test('all-sections assessment has an empty section; published flag from status or resultPublished', () {
      expect(byTitle('Mid-Term').section, '');
      expect(byTitle('Mid-Term').classLabel, 'Grade 5');
      expect(byTitle('Term 1 Result').isResultPublished, isTrue);
      expect(Assessment.fromJson({'_id': 'x', 'status': 'result_published'}).isResultPublished, isTrue);
      expect(Assessment.fromJson({'_id': 'x', 'status': 'completed', 'resultPublished': true}).isResultPublished, isTrue);
    });

    test('the stored UTC-midnight start date is the same calendar day in every timezone', () {
      final a = Assessment.fromJson({'_id': 'x', 'startDate': '2026-10-05T00:00:00.000Z', 'endDate': '2026-10-06T00:00:00.000Z'});
      expect((a.startDate!.year, a.startDate!.month, a.startDate!.day), (2026, 10, 5));
      expect((a.endDate!.year, a.endDate!.month, a.endDate!.day), (2026, 10, 6));
    });

    test('subject lookup is case and space tolerant; tolerant reader never throws on junk', () {
      final a = byTitle('Unit Test 1');
      expect(a.subjectNamed(' mathematics ')?.totalMarks, 50);
      expect(Assessment.fromJson(const {}).id, '');
      expect(Assessment.fromJson({'_id': 'x', 'subjects': 'nope', 'startDate': 'garbage'}).startDate, isNull);
    });

    test('whitelist: the raw payload carries grading scale, creator, school and campus; the model keeps none of them', () {
      final raw = (fx6b('assessments')['data'] as List).first as Map;
      expect(raw.keys, containsAll(['gradingScale', 'createdBy', 'schoolSlug', 'campusId']));
      final a = Assessment.fromJson(Map<String, dynamic>.from(raw));
      final shown = [a.title, a.description, a.type, a.grade, a.section, a.academicYear, a.term, a.status, a.subjects.map((s) => '${s.subject}${s.examiner}${s.venue}').join()].join('|');
      expect(shown, isNot(contains('demo-school')));
      expect(shown, isNot(contains('Admin (DUMMY)')));
    });
  });

  group('MarkRecord', () {
    final rows = Paginated<MarkRecord>.fromJson(fx6b('marks_mid_term'), MarkRecord.fromJson).items;

    test('verified flag and absent / numbers', () {
      expect(rows.where((m) => m.verified), hasLength(10));
      expect(rows.where((m) => !m.verified), hasLength(2));
      expect(rows.first.obtainedMarks, isNotNull);
      final unit = Paginated<MarkRecord>.fromJson(fx6b('marks_unit_test'), MarkRecord.fromJson).items;
      final absent = unit.firstWhere((m) => m.isAbsent);
      expect(absent.obtainedMarks, isNull);
      expect(absent.hasEntry, isTrue);
      expect(absent.remarks, 'Sick');
    });

    test('online quiz marks are recognised by their enteredBy marker', () {
      expect(MarkRecord.fromJson({'studentId': 's', 'enteredBy': 'Online Quiz (auto)'}).fromOnlineQuiz, isTrue);
      expect(MarkRecord.fromJson({'studentId': 's', 'enteredBy': 'Tess Teacher'}).fromOnlineQuiz, isFalse);
      expect(MarkRecord.fromJson({'studentId': 's'}).hasEntry, isFalse);
    });
  });

  group('ReportCard / QuizAttempt (stub fixtures)', () {
    test('report card reads remarks, position, published; principal remarks are kept separately', () {
      final cards = Paginated<ReportCard>.fromJson(fx6b('report_cards'), ReportCard.fromJson).items;
      expect(cards, hasLength(15));
      expect(cards[1].classTeacherRemarks, startsWith('Works steadily'));
      expect(cards[2].principalRemarks, startsWith('Excellent'));
      expect(cards.every((c) => !c.published), isTrue);
      expect(cards.first.subjects.map((s) => s.subject), ['Mathematics', 'Science', 'English']);
      expect(cards.first.withClassTeacherRemarks('new').classTeacherRemarks, 'new');
    });

    test('attempt list: written answers needing a mark; detail: hydrated question with the answer key', () {
      final list = (fx6b('quiz_attempts') as List).map((e) => QuizAttempt.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      expect(list, hasLength(4));
      expect(list.every((a) => a.isPending), isTrue);
      expect(list.first.manualAnswers, hasLength(2));
      expect(list.first.pendingCount, 2);
      expect(list.first.answers.first.question, isNull); // the list does NOT hydrate questions
      final d = QuizAttempt.fromJson(Map<String, dynamic>.from(fx6b('quiz_attempt_detail') as Map));
      expect(d.answers.map((a) => a.question?.marks), [2, 4, 4]);
      expect(d.answers.first.question!.options.where((o) => o.isCorrect), hasLength(1));
      expect(d.answers[1].question!.correctAnswer, isNotEmpty);
      expect(d.answers[1].needsManualGrading, isTrue);
      expect(d.answers.first.isCorrect, isTrue);
    });
  });

  group('Curriculum / Book (whitelist)', () {
    test('curriculum: SLOs by strand, standards; creator and tenant ids are not kept', () {
      final k = (fx6b('curricula') as List).map((e) => Curriculum.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final m5 = k.firstWhere((c) => c.name.startsWith('Mathematics Grade 5 (SNC)'));
      expect(m5.slos, hasLength(4));
      expect(m5.byStrand.keys, ['Number', 'Measurement']);
      expect(m5.slos.first.code, 'M5-N-01');
      expect(m5.standards.single.standard, 'Pakistan SNC 2020');
      expect(k.map((c) => c.status).toSet(), {'active', 'draft', 'archived'});
      expect(Curriculum.fromJson(const {'_id': 'x'}).byStrand, isEmpty);
    });

    test('book: availability and location; price, copies, barcodes and issue counters are ignored', () {
      final raw = (fx6b('books')['data'] as List).first as Map<String, dynamic>;
      expect(raw.keys, containsAll(['purchasePrice', 'copies', 'tenantId', 'issuedCopies']));
      final b = Book.fromJson(raw);
      expect(b.title, isNotEmpty);
      final shown = [b.title, b.author, b.isbn, b.publisher, b.callNumber, b.location, b.shelfNo, b.description, b.status, b.coverImageUrl].join('|');
      expect(shown, isNot(contains('1450')));
      expect(shown, isNot(contains('BC000')));
      expect(Book.fromJson({'_id': 'b', 'totalCopies': 3, 'availableCopies': 0}).isAvailable, isFalse);
      expect(Book.fromJson({'_id': 'b', 'totalCopies': 3, 'availableCopies': 2, 'status': 'deaccessioned'}).isAvailable, isFalse);
      expect(bookCategoryLabel('non_fiction'), 'Non-fiction');
    });
  });

  group('assessment scope (class matching, subjects, attempts, cards)', () {
    const g5a = ClassRef(grade: 'Grade 5', section: 'A', subjects: ['Mathematics']);
    const g6b = ClassRef(grade: 'Grade 6', section: 'B', subjects: ['Science']);
    const ct5a = ClassRef(grade: 'Grade 5', section: 'A', isClassTeacherClass: true);

    test('mine = a subject I teach in one of its classes; drafts and other grades are dropped', () {
      final classes = [g5a, g6b];
      final mine = myAssessments(all, classes).map((a) => a.title.split(' (').first).toList();
      expect(mine, containsAll(['Unit Test 1 - Fractions', 'Mid-Term Exam', 'Class Test - Plants', 'Final Exam', 'Term 1 Result', 'Online Quiz - Fractions', 'Cancelled Quiz']));
      expect(mine, isNot(contains('Grade 7 Unit Test')));
      expect(mine, isNot(contains('Draft - Spelling Bee')));
      expect(mine, isNot(contains('English Dictation'))); // Grade 5 B English: not my class
    });

    test('subjects: only the ones I teach in that class (English of Unit Test 1 is a colleague\'s)', () {
      expect(mySubjectsOf(byTitle('Unit Test 1'), [g5a]), ['Mathematics']);
      expect(mySubjectsOf(byTitle('Mid-Term'), [g5a]), ['Mathematics']);
      expect(mySubjectsOf(byTitle('Class Test - Plants'), [g5a]), isEmpty);
    });

    test('an all-sections assessment matches my section; a whole-grade assignment matches any section of the grade', () {
      expect(isMyAssessment(byTitle('Mid-Term'), [g5a]), isTrue);
      expect(isMyAssessment(byTitle('Mid-Term'), [const ClassRef(grade: 'Grade 5', section: 'B', subjects: ['Mathematics'])]), isTrue);
      expect(isMyAssessment(byTitle('Unit Test 1'), [const ClassRef(grade: 'Grade 5', section: 'B', subjects: ['Mathematics'])]), isFalse);
      expect(isMyAssessment(byTitle('Unit Test 1'), [const ClassRef(grade: 'Grade 5', subjects: ['Mathematics'])]), isTrue); // whole grade
    });

    test('tolerant grade / section strings ("5" / "a") match "Grade 5" / "A"', () {
      expect(isMyAssessment(byTitle('Unit Test 1'), [const ClassRef(grade: '5', section: 'a', subjects: ['mathematics '])]), isTrue);
    });

    test('class teacher sees the assessment read-only even without teaching the subject', () {
      expect(isMyAssessment(byTitle('Unit Test 1'), [ct5a]), isTrue);
      expect(mySubjectsOf(byTitle('Unit Test 1'), [ct5a]), isEmpty);
      expect(myClassTeacherClassesFor(byTitle('Unit Test 1'), [ct5a]), hasLength(1));
      expect(myClassTeacherClassesFor(byTitle('Unit Test 1'), [g5a]), isEmpty);
    });

    test('roster class: the assessment\'s own section wins; otherwise mine', () {
      final r = rosterClassesFor(byTitle('Unit Test 1'), 'Mathematics', [const ClassRef(grade: 'Grade 5', subjects: ['Mathematics'])]).single;
      expect(r.label, 'Grade 5 - A');
      final two = rosterClassesFor(byTitle('Mid-Term'), 'Mathematics', [g5a, const ClassRef(grade: 'Grade 5', section: 'B', subjects: ['Mathematics'])]);
      expect(two.map((c) => c.label), ['Grade 5 - A', 'Grade 5 - B']);
      expect(rosterClassesFor(byTitle('Mid-Term'), 'Art', [g5a]), isEmpty);
    });

    test('quiz attempts: my class AND my subject only', () {
      final list = (fx6b('quiz_attempts') as List).map((e) => QuizAttempt.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final mine = list.where((a) => isMyAttempt(a, [g5a])).toList();
      expect(mine, hasLength(2)); // 5A Mathematics x2; 5B Maths and 5A English are dropped
      expect(mine.every((a) => a.subject == 'Mathematics' && a.section == 'A'), isTrue);
    });

    test('report cards: my class-teacher class only', () {
      final cards = Paginated<ReportCard>.fromJson(fx6b('report_cards'), ReportCard.fromJson).items;
      expect(cards.where((c) => isCardOfClass(c, ct5a)), hasLength(12));
      expect(cards.where((c) => isCardOfClass(c, const ClassRef(grade: 'Grade 5', section: 'B'))), hasLength(3));
      expect(cards.where((c) => isCardOfClass(c, const ClassRef(grade: 'Grade 5'))), hasLength(15)); // whole-grade class
    });
  });

  group('AssessmentRepository (exact requests)', () {
    test('listAssessments pages until meta.pages (limit 100, sorted by start date)', () async {
      final c = _Client((m, p, q, b) => page([{'_id': 'a${q!['page']}', 'title': 'T'}], q['page'] as int, 3));
      final r = await AssessmentRepository(c).listAssessments();
      expect(r.items.map((a) => a.id), ['a1', 'a2', 'a3']);
      expect(r.truncated, isFalse);
      expect(c.calls.map((x) => x.q), [
        {'sortBy': 'startDate', 'sortOrder': 'desc', 'page': 1, 'limit': 100},
        {'sortBy': 'startDate', 'sortOrder': 'desc', 'page': 2, 'limit': 100},
        {'sortBy': 'startDate', 'sortOrder': 'desc', 'page': 3, 'limit': 100},
      ]);
    });

    test('a runaway server is cut at the page cap and says so', () async {
      final c = _Client((m, p, q, b) => page([{'_id': 'a${q!['page']}'}], q['page'] as int, 999));
      final r = await AssessmentRepository(c).listAssessments();
      expect(r.items, hasLength(AssessmentRepository.maxPages));
      expect(r.truncated, isTrue);
    });

    test('marks: assessmentId + subject, 200 per page, all pages', () async {
      final c = _Client((m, p, q, b) => page([{'studentId': 's${q!['page']}'}], q['page'] as int, 2));
      final r = await AssessmentRepository(c).marks('A1', 'Mathematics');
      expect(r.items.map((x) => x.studentId), ['s1', 's2']);
      expect(c.calls.first.path, '/assessments/marks/list');
      expect(c.calls.first.q, {'assessmentId': 'A1', 'subject': 'Mathematics', 'page': 1, 'limit': 200});
    });

    test('saveMarks: exact body, null marks for absent / exempt rows, x-academic-year header', () async {
      final c = _Client((m, p, q, b) => {'message': 'Marks entered for 3 students', 'subject': 'Mathematics'});
      await AssessmentRepository(c).saveMarks(assessmentId: 'A1', subject: 'Mathematics', grade: 'Grade 5', academicYear: '2026-27', marks: const [
        MarkWrite(studentId: 's1', studentName: 'Aarav Ahmed', rollNumber: '1', section: 'A', obtainedMarks: 42.5, remarks: 'ok'),
        MarkWrite(studentId: 's2', studentName: 'Zara', rollNumber: '2', section: 'A', obtainedMarks: 9, isAbsent: true),
        MarkWrite(studentId: 's3', studentName: 'Omar', rollNumber: '3', section: 'A', isExempt: true),
      ]);
      final call = c.calls.single;
      expect(call.method, 'POST');
      expect(call.path, '/assessments/marks/bulk');
      expect(call.headers, {'x-academic-year': '2026-27'});
      expect(call.body, {
        'assessmentId': 'A1',
        'subject': 'Mathematics',
        'grade': 'Grade 5',
        'marks': [
          {'studentId': 's1', 'studentName': 'Aarav Ahmed', 'rollNumber': '1', 'section': 'A', 'obtainedMarks': 42.5, 'isAbsent': false, 'isExempt': false, 'remarks': 'ok'},
          {'studentId': 's2', 'studentName': 'Zara', 'rollNumber': '2', 'section': 'A', 'obtainedMarks': null, 'isAbsent': true, 'isExempt': false, 'remarks': ''},
          {'studentId': 's3', 'studentName': 'Omar', 'rollNumber': '3', 'section': 'A', 'obtainedMarks': null, 'isAbsent': false, 'isExempt': true, 'remarks': ''},
        ],
      });
    });

    test('saveMarks maps a 400 / 403 to an ApiException with the status', () async {
      final c = _Client((m, p, q, b) => 400);
      await expectLater(AssessmentRepository(c).saveMarks(assessmentId: 'A', subject: 'S', grade: 'G', marks: const []), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    });

    test('saveRemarks sends ONLY classTeacherRemarks; an empty 200 (unknown id) becomes a 404', () async {
      final c = _Client((m, p, q, b) => p.endsWith('/gone/remarks') ? null : {'_id': 'c1', 'classTeacherRemarks': 'Nice'});
      final repo = AssessmentRepository(c);
      final ok = await repo.saveRemarks('c1', 'Nice');
      expect(ok.classTeacherRemarks, 'Nice');
      expect(c.calls.single.method, 'PATCH');
      expect(c.calls.single.path, '/assessments/report-cards/c1/remarks');
      expect(c.calls.single.body, {'classTeacherRemarks': 'Nice'});
      await expectLater(repo.saveRemarks('gone', 'x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    });

    test('reportCards: by assessment, 100 per page', () async {
      final c = _Client((m, p, q, b) => page([{'_id': 'c1'}], 1, 1));
      await AssessmentRepository(c).reportCards('A1');
      expect(c.calls.single.q, {'assessmentId': 'A1', 'page': 1, 'limit': 100});
    });

    test('quiz: pending list, one attempt, grade body {grades:[{questionId, marksAwarded}]}', () async {
      final c = _Client((m, p, q, b) => p == '/assessments/quiz-attempts' ? [fx6b('quiz_attempt_detail')] : fx6b('quiz_attempt_detail'));
      final repo = AssessmentRepository(c);
      expect((await repo.pendingAttempts()).single.id, isNotEmpty);
      expect((await repo.attempt('T1')).answers, hasLength(3));
      await repo.gradeAttempt('T1', [(questionId: 'q1', marks: 3), (questionId: 'q2', marks: 2.5)]);
      final g = c.calls.last;
      expect(g.method, 'POST');
      expect(g.path, '/assessments/quiz-attempts/T1/grade');
      expect(g.body, {
        'grades': [
          {'questionId': 'q1', 'marksAwarded': 3.0},
          {'questionId': 'q2', 'marksAwarded': 2.5}
        ]
      });
    });
  });

  group('ReferenceRepository (exact requests)', () {
    test('curricula asks status=active; books send only the filters that are set', () async {
      final c = _Client((m, p, q, b) => p.contains('curriculum') ? fx6b('curricula') : fx6b('books'));
      final repo = ReferenceRepository(c);
      expect((await repo.curricula()).length, 6);
      expect(c.calls.single.q, {'status': 'active'});
      await repo.books();
      await repo.books(search: ' fractions ', category: 'textbook', availableOnly: true, page: 2);
      expect(c.calls[1].q, {'page': 1, 'limit': 20});
      expect(c.calls[2].q, {'page': 2, 'limit': 20, 'search': 'fractions', 'category': 'textbook', 'available': 'true'});
    });

    test('curriculum by id: empty body is a 404', () async {
      final c = _Client((m, p, q, b) => <String, Object?>{});
      await expectLater(ReferenceRepository(c).curriculum('x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    });
  });
  group('class roster for marks entry is fetched in full (the web silently stops at limit=100)', () {
    Map<String, Object?> stu(int i) => {'_id': 'st$i', 'firstName': 'F$i', 'lastName': 'L$i', 'currentGrade': 'Grade 5', 'currentSection': 'A', 'currentRollNumber': '$i', 'status': 'active', 'monthlyTuitionFee': 18500, 'guardians': [{'phone': '0300-1'}]};

    test('230 students arrive over two 200-row pages and all 230 are kept; fee and contact fields never reach the model', () async {
      final c = _Client((m, p, q, b) {
        final pg = q!['page'] as int;
        final rows = pg == 1 ? [for (var i = 1; i <= 200; i++) stu(i)] : [for (var i = 201; i <= 230; i++) stu(i)];
        return {'data': rows, 'meta': {'total': 230, 'page': pg, 'limit': 200, 'pages': 2}};
      });
      final roster = await StudentsRepository(c).fetchClassRoster(const ClassRef(grade: 'Grade 5', section: 'A'));
      expect(roster, hasLength(230));
      expect(c.calls.map((x) => (x.q!['page'], x.q!['limit'])), [(1, 200), (2, 200)]);
      expect(roster.first.toString(), isNot(contains('18500')));
    });
  });
}
