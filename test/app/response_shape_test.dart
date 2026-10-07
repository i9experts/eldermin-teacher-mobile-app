// ignore_for_file: invalid_use_of_protected_member
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/assessments_controller.dart';
import 'package:eldermin_teacher_app/app/modules/assessments/controllers/quiz_controllers.dart';
import 'package:eldermin_teacher_app/app/modules/behaviour/controllers/behaviour_controller.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/controllers/curriculum_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_dashboard_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plans_controller.dart';
import 'package:eldermin_teacher_app/app/modules/library/controllers/library_controller.dart';
import 'package:eldermin_teacher_app/app/modules/students/controllers/students_controller.dart';
import 'package:eldermin_teacher_app/app/modules/syllabus/controllers/syllabus_controller.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/network/response_shape.dart';
import 'package:eldermin_teacher_app/core/services/assessment_repository.dart';
import 'package:eldermin_teacher_app/core/services/attendance_repository.dart';
import 'package:eldermin_teacher_app/core/services/behaviour_repository.dart';
import 'package:eldermin_teacher_app/core/services/home_repository.dart';
import 'package:eldermin_teacher_app/core/services/homework_repository.dart';
import 'package:eldermin_teacher_app/core/services/lesson_plan_repository.dart';
import 'package:eldermin_teacher_app/core/services/reference_repository.dart';
import 'package:eldermin_teacher_app/core/services/students_repository.dart';
import 'package:eldermin_teacher_app/core/services/syllabus_repository.dart';
import 'package:eldermin_teacher_app/core/utils/roster_scope.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import '../support/auth_harness.dart';

/// One rule for EVERY list-loading repository / controller (core/network/response_shape.dart):
///   valid empty list -> empty state; failed call -> error state; unexpected shape (Map without the key / String / null / wrong key type /
///   rows that are not objects) -> UnexpectedResponseShape -> error state ("Something went wrong loading X - try again", Retry), never empty.
class _Client extends BaseClient {
  Object? body;
  int? failStatus;
  _Client([this.body]);

  @override
  Future<Response> get(String url, {Map<String, dynamic>? queryParameters, bool requiresAuth = true, Map<String, String>? headers}) async {
    final ro = RequestOptions(path: url);
    final s = failStatus;
    if (s != null) {
      throw DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: Response(requestOptions: ro, statusCode: s, data: {'statusCode': s, 'message': 'boom'}));
    }
    return Response(requestOptions: ro, statusCode: 200, data: body);
  }
}

/// Bodies that are NOT a list / `{data: [...]}` (for list endpoints answering a bare array or a `data` wrapper).
final List<(String, Object?)> badLists = [
  ('a Map without the wrapper key', {'unexpected': 1}),
  ('a Map with the list under the wrong key', {'results': []}),
  ('a String', 'Internal error page'),
  ('null', null),
  ('data is not a list', {'data': 'x'}),
  ('data is a Map', {'data': {'a': 1}}),
  ('rows that are not objects', [1, 2]),
  ('a list with a null row', [null]),
];

const staff = '64a0000000000000000000a1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  group('response_shape helpers', () {
    test('expectRows: bare list, data wrapper, items wrapper; empty is valid', () {
      expect(expectRows([{'a': 1}], what: 'x'), hasLength(1));
      expect(expectRows({'data': [{'a': 1}]}, what: 'x'), hasLength(1));
      expect(expectRows({'items': []}, what: 'x', keys: ['data', 'items']), isEmpty);
      expect(expectRows([], what: 'x'), isEmpty);
    });
    test('every bad shape throws UnexpectedResponseShape with the user text', () {
      for (final (name, b) in badLists) {
        expect(() => expectRows(b, what: 'homework'), throwsA(isA<UnexpectedResponseShape>()), reason: name);
      }
      try {
        expectRows('x', what: 'homework');
      } on ApiException catch (e) {
        expect(e.message, 'Something went wrong loading homework — try again.');
        expect(e.statusCode, isNull);
      }
      expect(() => expectMap([], what: 'x'), throwsA(isA<UnexpectedResponseShape>()));
      expect(() => expectKeyRows({'a': 1}, 'a', what: 'x'), throwsA(isA<UnexpectedResponseShape>()));
    });
  });

  // ── Repositories: valid empty -> empty result; every bad shape -> UnexpectedResponseShape; HTTP error -> ApiException (not shape) ──
  final listCases = <String, (Object? emptyOk, Future<Object?> Function(_Client) call)>{
    'HomeworkRepository.fetchMine': ([], (c) => HomeworkRepository(c).fetchMine(staff)),
    'AssessmentRepository.listAssessments': ({'data': [], 'meta': {'pages': 1}}, (c) async => (await AssessmentRepository(c).listAssessments()).items),
    'AssessmentRepository.marks': ({'data': [], 'meta': {}}, (c) async => (await AssessmentRepository(c).marks('a', 'Maths')).items),
    'AssessmentRepository.reportCards': ({'data': [], 'meta': {}}, (c) async => (await AssessmentRepository(c).reportCards('a')).items),
    'AssessmentRepository.pendingAttempts (quiz)': ([], (c) => AssessmentRepository(c).pendingAttempts()),
    'LessonPlanRepository.fetchMine': ([], (c) => LessonPlanRepository(c).fetchMine([staff])),
    'SyllabusRepository.list': ([], (c) => SyllabusRepository(c).list({'teacherId': staff})),
    'SyllabusRepository.weeklyPlanner': ([], (c) => SyllabusRepository(c).weeklyPlanner([staff])),
    'ReferenceRepository.curricula': ([], (c) => ReferenceRepository(c).curricula()),
    'ReferenceRepository.books (library)': ({'data': [], 'meta': {'total': 0, 'pages': 0}}, (c) async => (await ReferenceRepository(c).books()).items),
    'BehaviourRepository.fetchGradeRecords': ({'data': [], 'meta': {}}, (c) => BehaviourRepository(c).fetchGradeRecords('Grade 5')),
    'BehaviourRepository.fetchStudentRecords': ({'data': [], 'meta': {}}, (c) => BehaviourRepository(c).fetchStudentRecords('s1')),
    'BehaviourRepository.fetchTarbiyah': ({'data': []}, (c) => BehaviourRepository(c).fetchTarbiyah('s1')),
    'StudentsRepository.fetchClassRoster': ({'data': [], 'meta': {}}, (c) => StudentsRepository(c).fetchClassRoster(const ClassRef(grade: 'Grade 5', section: 'A'))),
    'AttendanceRepository.fetchRange': ({'data': [], 'meta': {}}, (c) => AttendanceRepository(c).fetchRange(grade: 'Grade 5', firstDay: DateTime(2026, 10, 1), lastDay: DateTime(2026, 10, 2))),
    'HomeRepository.fetchTeacherTimetable': ([], (c) => HomeRepository(c).fetchTeacherTimetable(staff)),
    'HomeRepository.fetchAssignments': ([], (c) => HomeRepository(c).fetchAssignments(staff)),
    'HomeRepository.fetchLessonPlans': ([], (c) => HomeRepository(c).fetchLessonPlans(staff, 'submitted')),
    'HomeRepository.fetchUpcomingPtms': ([], (c) => HomeRepository(c).fetchUpcomingPtms(staff)),
    'HomeRepository.fetchPtmsInRange': ([], (c) => HomeRepository(c).fetchPtmsInRange(staff, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 2))),
    'HomeRepository.fetchSubstitutions (fixtures)': ([], (c) => HomeRepository(c).fetchSubstitutions(staff, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 2))),
  };

  group('repositories: empty is empty, HTTP failure is an ApiException, a wrong shape is UnexpectedResponseShape', () {
    listCases.forEach((name, spec) {
      test(name, () async {
        // valid empty
        final ok = await spec.$2(_Client(spec.$1));
        expect(ok is List ? ok : ok, isNotNull);
        if (ok is List) expect(ok, isEmpty);
        // failed call: an ApiException with the status, NOT the shape error
        final failing = _Client()..failStatus = 500;
        await expectLater(spec.$2(failing), throwsA(isA<ApiException>().having((e) => e is UnexpectedResponseShape, 'is shape', isFalse).having((e) => e.statusCode, 'status', 500)));
        // unexpected shapes
        for (final (shape, b) in badLists) {
          await expectLater(spec.$2(_Client(b)), throwsA(isA<UnexpectedResponseShape>()), reason: '$name: $shape');
        }
      });
    });
  });

  final objectCases = <String, (Object? okBody, Future<Object?> Function(_Client) call, List<(String, Object?)> bad)>{
    'HomeRepository.getMyTimetable': ({'from': '2026-10-05', 'to': '2026-10-05', 'days': []}, (c) => HomeRepository(c).getMyTimetable(DateTime(2026, 10, 5), DateTime(2026, 10, 5)), [('no days key', {'from': 'x'}), ('List', []), ('String', 's'), ('null', null), ('days is a Map', {'days': {}})]),
    'HomeRepository.getPendingGrading': ({'total': 0, 'items': []}, (c) => HomeRepository(c).getPendingGrading(), [('no items', {'total': 1}), ('List', []), ('String', 's'), ('null', null)]),
    'HomeRepository.fetchOpenThreads': ({'items': [], 'unreadCount': 0}, (c) => HomeRepository(c).fetchOpenThreads(), [('no items', {'unreadCount': 1}), ('List', []), ('String', 's'), ('null', null)]),
    'HomeRepository.fetchSubmissions': ({'submissions': []}, (c) => HomeRepository(c).fetchSubmissions('a1'), [('no key', {'x': 1}), ('List', []), ('null', null)]),
    'HomeworkRepository.fetchSubmissions': ({'assignment': {}, 'submissions': []}, (c) => HomeworkRepository(c).fetchSubmissions('a1'), [('no key', {'x': 1}), ('List', []), ('null', null)]),
    'HomeRepository.fetchNotificationUnreadCount': ({'unreadCount': 0}, (c) => HomeRepository(c).fetchNotificationUnreadCount(), [('no count', {}), ('List', []), ('null', null)]),
    'StudentsRepository.fetchGradesSections': ({'grades': [], 'sections': []}, (c) => StudentsRepository(c).fetchGradesSections(), [('no grades', {'x': 1}), ('List', []), ('null', null)]),
    'StudentsRepository.fetchAttendanceSummary': ([], (c) => StudentsRepository(c).fetchAttendanceSummary('s1', year: 2026, month: 10), [('String', 's'), ('null', null)]),
    'AssessmentRepository.assessment': ({'_id': 'a1'}, (c) => AssessmentRepository(c).assessment('a1'), [('List', []), ('String', 's'), ('null', null)]),
    'ReferenceRepository.curriculum': ({'_id': 'c1'}, (c) => ReferenceRepository(c).curriculum('c1'), [('List', []), ('String', 's'), ('null', null)]),
    'SyllabusRepository.one': ({'_id': 's1'}, (c) => SyllabusRepository(c).one('s1'), [('List', []), ('String', 's'), ('null', null)]),
    'StudentsRepository.fetchStudent360': ({'_id': 's1', 'firstName': 'A'}, (c) => StudentsRepository(c).fetchStudent360('s1'), [('List', []), ('String', 's'), ('null', null)]),
    'AssessmentRepository.attempt': ({'_id': 't1'}, (c) => AssessmentRepository(c).attempt('t1'), [('List', []), ('String', 's'), ('null', null)]),
  };

  group('repositories (single object / envelope endpoints)', () {
    objectCases.forEach((name, spec) {
      test(name, () async {
        await spec.$2(_Client(spec.$1)); // valid shape parses
        await expectLater(spec.$2(_Client()..failStatus = 403), throwsA(isA<ApiException>().having((e) => e is UnexpectedResponseShape, 'shape', isFalse)));
        for (final (shape, b) in spec.$3) {
          await expectLater(spec.$2(_Client(b)), throwsA(isA<UnexpectedResponseShape>()), reason: '$name: $shape');
        }
      });
    });
  });

  // ── Controllers wired to the REAL repositories behind the fake client ──
  Future<({AuthController auth, dynamic perms})> boot({bool classTeacher = false}) async {
    final h = await signedIn(classTeacher: classTeacher);
    h.api.assignments = const [
      {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'}
    ];
    h.api.subjects = const ['Mathematics'];
    await h.auth.refreshProfile(force: true);
    return (auth: h.auth, perms: h.perms);
  }

  final controllerCases = <String, (Object? emptyOk, Future<Rx<SectionState<dynamic>>> Function(_Client c, dynamic h) run)>{};

  Future<Rx<SectionState<dynamic>>> viaLoad(dynamic ctrl, Rx<SectionState<dynamic>> state) async {
    await ctrl.load(force: true);
    return state;
  }

  controllerCases['HomeworkController'] = ([], (c, h) async {
    final ctl = HomeworkController(repository: HomeworkRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['QuizAttemptsController'] = ([], (c, h) async {
    final ctl = QuizAttemptsController(repository: AssessmentRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['AssessmentsController'] = ({'data': [], 'meta': {'pages': 1}}, (c, h) async {
    final ctl = AssessmentsController(repository: AssessmentRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['LessonPlansController'] = ([], (c, h) async {
    final ctl = LessonPlansController(repository: LessonPlanRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['SyllabusController'] = ([], (c, h) async {
    final ctl = SyllabusController(repository: SyllabusRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['CurriculumController'] = ([], (c, h) async {
    final ctl = CurriculumController(repository: ReferenceRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['LibraryController'] = ({'data': [], 'meta': {'total': 0, 'pages': 0}}, (c, h) async {
    final ctl = LibraryController(repository: ReferenceRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['BehaviourController'] = ({'data': [], 'meta': {}}, (c, h) async {
    final ctl = BehaviourController(repository: BehaviourRepository(c), students: StudentsRepository(c), auth: h.auth, permissions: h.perms);
    return viaLoad(ctl, ctl.state as Rx<SectionState<dynamic>>);
  });
  controllerCases['StudentsController (class roster)'] = ({'data': [], 'meta': {}}, (c, h) async {
    final ctl = StudentsController(repository: StudentsRepository(c), auth: h.auth, permissions: h.perms);
    await ctl.load(force: true);
    return Rx<SectionState<dynamic>>(ctl.rosters.values.single);
  });

  group('controllers: valid empty -> empty state; failed call -> error; unexpected shape -> error with Retry text, never empty', () {
    controllerCases.forEach((name, spec) {
      testWidgets(name, (t) async {
        final h = (await t.runAsync(() => boot()))!;
        var s = (await spec.$2(_Client(spec.$1), h)).value;
        expect(s.status, SectionStatus.empty, reason: '$name valid empty');
        s = (await spec.$2(_Client()..failStatus = 500, h)).value;
        expect(s.status, SectionStatus.error, reason: '$name failed call');
        for (final (shape, b) in badLists) {
          // The library / behaviour / roster endpoints answer an object with `data`; a bare list is also a valid wrapper for them, so skip
          // only the bodies that are valid for a given endpoint family.
          final r = (await spec.$2(_Client(b), h)).value;
          expect(r.status, SectionStatus.error, reason: '$name $shape');
          expect(r.message, contains('Something went wrong loading'), reason: '$name $shape');
        }
      });
    });
  });

  group('Home dashboard sections', () {
    Future<HomeDashboardController> make(_Client c, dynamic h) async {
      final badges = HomeBadgesController(repository: HomeRepository(c), auth: h.auth, autoPoll: false);
      return HomeDashboardController(repository: HomeRepository(c), auth: h.auth, permissions: h.perms, badges: badges, clock: () => DateTime(2026, 10, 5, 9), tick: null);
    }

    testWidgets('lesson plans / PTM / substitutions: [] -> empty, failure and wrong shape -> error', (t) async {
      final h = (await t.runAsync(() => boot()))!;
      final empty = await make(_Client([]), h);
      await empty.loadLessonPlans();
      await empty.loadPtms();
      await empty.loadSubstitutions();
      expect(empty.lessonPlans.value.status, SectionStatus.empty);
      expect(empty.ptms.value.status, SectionStatus.empty);
      expect(empty.substitutions.value.status, SectionStatus.empty);
      final failed = await make(_Client()..failStatus = 500, h);
      await failed.loadLessonPlans();
      await failed.loadPtms();
      await failed.loadSubstitutions();
      await failed.loadTimetable();
      await failed.loadHomework();
      for (final s in [failed.lessonPlans.value, failed.ptms.value, failed.substitutions.value, failed.timetable.value, failed.homework.value]) {
        expect(s.status, SectionStatus.error);
      }
      for (final (shape, b) in badLists) {
        final bad = await make(_Client(b), h);
        await bad.loadLessonPlans();
        await bad.loadPtms();
        await bad.loadSubstitutions();
        await bad.loadTimetable();
        await bad.loadHomework();
        for (final s in [bad.lessonPlans.value, bad.ptms.value, bad.substitutions.value, bad.timetable.value, bad.homework.value]) {
          expect(s.status, SectionStatus.error, reason: shape);
          expect(s.message, contains('Something went wrong loading'), reason: shape);
        }
      }
    });

    testWidgets('messages section: valid empty envelope = data, wrong shape = error', (t) async {
      final h = (await t.runAsync(() => boot()))!;
      final good = await make(_Client({'items': [], 'unreadCount': 0}), h);
      await good.badges.refreshThreads();
      expect(good.badges.threads.value.status, SectionStatus.data);
      for (final b in <Object?>['x', null, {'unexpected': 1}, []]) {
        final bad = await make(_Client(b), h);
        await bad.badges.refreshThreads();
        expect(bad.badges.threads.value.status, SectionStatus.error);
      }
    });
  });
}
