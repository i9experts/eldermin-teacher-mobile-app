// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plan_upload_controller.dart';
import 'package:eldermin_teacher_app/app/modules/lesson_plans/controllers/lesson_plans_controller.dart';
import 'package:eldermin_teacher_app/core/models/academic/lesson_plan_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart' show PickedAttachment;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_academic_repositories.dart';

final fixedNow = DateTime(2026, 10, 5, 9, 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLessonPlanRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeLessonPlanRepository();
  });
  tearDown(Get.reset);

  Future<({LessonPlansController list, dynamic h})> makeList({List<String>? permissions, LessonPlanFilter? filter}) async {
    final h = await signedIn(permissions: permissions);
    final c = LessonPlansController(repository: repo, auth: h.auth, permissions: h.perms, initialFilter: filter);
    return (list: c, h: h);
  }

  group('LessonPlansController (my plans)', () {
    test('asks for MY staff id AND my teacher-profile id (both from /staff-portal/me) in one repository call', () async {
      repo.mine = (_) async => [plan('p1'), plan('p2', status: 'rejected')];
      final r = await makeList();
      await r.list.load();
      expect(repo.calls, ['mine:$myStaff6,$myProfile6']);
      expect(r.list.items, hasLength(2));
      expect(r.list.state.value.status, SectionStatus.data);
    });

    test('filters by status, with counts; an empty filter keeps the data state', () async {
      repo.mine = (_) async => [plan('a', status: 'draft'), plan('b', status: 'submitted'), plan('c', status: 'rejected'), plan('d', status: 'rejected'), plan('e', status: 'approved')];
      final c = (await makeList()).list;
      await c.load();
      expect(c.countFor(LessonPlanFilter.all), 5);
      expect(c.countFor(LessonPlanFilter.rejected), 2);
      c.setFilter(LessonPlanFilter.rejected);
      expect(c.filtered.map((p) => p.id), ['c', 'd']);
      c.setFilter(LessonPlanFilter.overdue);
      expect(c.filtered, isEmpty);
      expect(c.state.value.status, SectionStatus.data);
    });

    test('opens pre-filtered from the Home card (argument "rejected" / "submitted")', () async {
      expect(LessonPlanFilter.fromArgument('rejected'), LessonPlanFilter.rejected);
      expect(LessonPlanFilter.fromArgument('submitted'), LessonPlanFilter.submitted);
      expect(LessonPlanFilter.fromArgument(null), LessonPlanFilter.all);
      expect(LessonPlanFilter.fromArgument('weird'), LessonPlanFilter.all);
      final r = await makeList(filter: LessonPlanFilter.rejected);
      r.list.onInit();
      expect(r.list.filter.value, LessonPlanFilter.rejected);
    });

    test('empty, error then retry, 403, 404-unavailable', () async {
      final c = (await makeList()).list;
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.mine = (_) async => throw ApiException('boom', statusCode: 500);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      repo.mine = (_) async => [plan('a')];
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.data);
      repo.mine = (_) async => throw ApiException("Forbidden resource", statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
      repo.mine = (_) async => throw ApiException('nf', statusCode: 404);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.unavailable);
    });

    test('without teaching:view nothing is requested and the state is forbidden', () async {
      final c = (await makeList(permissions: ['dashboard:view'])).list;
      await c.load();
      expect(repo.calls, isEmpty);
      expect(c.state.value.status, SectionStatus.forbidden);
    });

    test('100 rows = the server cap: the list says older plans may be missing', () async {
      repo.mine = (_) async => [for (var i = 0; i < 100; i++) plan('p$i', day: '2026-10-07')];
      final c = (await makeList()).list;
      await c.load();
      expect(c.maybeTruncated, isTrue);
      repo.mine = (_) async => [plan('a')];
      await c.load(force: true);
      expect(c.maybeTruncated, isFalse);
    });

    test('upsert keeps newest plan date first and needs no re-fetch', () async {
      repo.mine = (_) async => [plan('old', day: '2026-10-01'), plan('mid', day: '2026-10-05')];
      final c = (await makeList()).list;
      await c.load();
      c.upsert(plan('new', day: '2026-10-09'));
      c.upsert(plan('old', day: '2026-10-01', topic: 'Renamed'));
      expect(c.items.map((p) => p.id), ['new', 'mid', 'old']);
      expect(c.byId('old')!.topic, 'Renamed');
      expect(repo.calls, hasLength(1));
    });

    test('a stale load result is dropped', () async {
      final slow = Completer<List<LessonPlanRecord>>();
      repo.mine = (_) => slow.future;
      final c = (await makeList()).list;
      final first = c.load();
      repo.mine = (_) async => [plan('fresh')];
      await c.load(force: true);
      slow.complete([plan('stale')]);
      await first;
      expect(c.items.map((p) => p.id), ['fresh']);
    });
  });

  group('LessonPlanFormController (create)', () {
    const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
    const cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

    Future<LessonPlanFormController> make({List<Map<String, Object?>> assignments = const [cls5a], LessonPlanRecord? editing, LessonPlanDraft? draft}) async {
      final h = await signedIn();
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      final list = LessonPlansController(repository: repo, auth: h.auth, permissions: h.perms);
      final c = LessonPlanFormController(repository: repo, auth: h.auth, list: list, clock: () => fixedNow, editing: editing, draft: draft);
      c.onInit();
      addTearDown(c.onClose);
      return c;
    }

    void fill(LessonPlanFormController c) {
      c.topicC.text = '  Adding fractions ';
      c.setPlanDay(DateTime(2026, 10, 9));
      c.objectives.first.controller.text = 'Add fractions';
    }

    test('class and subject come from MY assignments; a single class and subject auto-select', () async {
      final c = await make();
      expect(c.classes.map((e) => e.label), ['Grade 5 - A']);
      expect(c.selectedClass?.label, 'Grade 5 - A');
      expect(c.subject.value, 'Mathematics');
    });

    test('two classes: nothing is preselected, subjects follow the picked class', () async {
      final c = await make(assignments: [cls5a, cls6b]);
      expect(c.selectedClass, isNull);
      expect(c.subjects, isEmpty.or(isNotEmpty)); // before a class is picked: everything I can teach (may be empty)
      c.selectClass(1);
      expect(c.subjects, ['Science']);
      expect(c.subject.value, 'Science');
      c.selectClass(0);
      expect(c.subject.value, 'Mathematics');
    });

    test('pristine submit: every required field is flagged and NOTHING is sent', () async {
      final c = await make(assignments: [cls5a, cls6b]);
      final r = await c.submit(forApproval: true);
      expect(r, isA<PlanInvalid>());
      expect((r as PlanInvalid).errors.keys.toSet(), {'class', 'subject', 'topic', 'date'});
      expect(repo.calls, isEmpty);
    });

    test('duration must be 10..180 minutes when given', () async {
      final c = await make();
      fill(c);
      c.durationC.text = '5';
      expect(c.validate().keys, ['duration']);
      c.durationC.text = '181';
      expect(c.validate().keys, ['duration']);
      c.durationC.text = 'abc';
      expect(c.validate().keys, ['duration']);
      c.durationC.text = '45';
      expect(c.validate(), isEmpty);
    });

    test('save as draft: exact create body (teacherId = my Staff id from /me, YYYY-MM-DD, objectives, status draft)', () async {
      final c = await make();
      fill(c);
      c.setMethodology('activity');
      c.toggleResource('Textbook');
      c.otherResourceC.text = 'paper strips; scissors';
      c.homeworkC.text = 'Ex 1';
      c.durationC.text = '45';
      final r = await c.submit(forApproval: false);
      expect(r, isA<PlanSaved>());
      expect((r as PlanSaved).submitted, isFalse);
      final b = repo.created.single;
      expect(b, {
        'teacherId': myStaff6,
        'teacherName': 'Tess Teacher',
        'subject': 'Mathematics',
        'gradeLevel': 'Grade 5',
        'sectionName': 'A',
        'topic': 'Adding fractions',
        'planDate': '2026-10-09',
        'durationMins': 45,
        'teachingMethodology': 'activity',
        'objectives': ['Add fractions'],
        'resources': ['Textbook', 'paper strips', 'scissors'],
        'homework': 'Ex 1',
        'status': 'draft',
      });
      expect(c.list!.items.single.status, LessonPlanStatus.draft);
    });

    test('submit for approval sends status submitted and reports it', () async {
      final c = await make();
      fill(c);
      final r = await c.submit(forApproval: true);
      expect((r as PlanSaved).submitted, isTrue);
      expect(repo.created.single['status'], 'submitted');
    });

    test('double submit: a second tap while the first is in flight is ignored', () async {
      final slow = Completer<LessonPlanRecord>();
      repo.onCreate = (_) => slow.future;
      final c = await make();
      fill(c);
      final first = c.submit(forApproval: true);
      final second = await c.submit(forApproval: true);
      expect(second, isA<PlanIgnored>());
      expect(c.saving.value, isTrue);
      slow.complete(plan('n1', status: 'submitted'));
      await first;
      expect(repo.created, hasLength(1));
      expect(c.saving.value, isFalse);
    });

    test('offline: the form keeps every field and Retry sends the same body again', () async {
      var offline = true;
      repo.onCreate = (b) async {
        if (offline) throw ApiException('No internet connection.');
        return plan('n1');
      };
      final c = await make();
      fill(c);
      c.activitiesC.text = 'Cut paper strips';
      final r1 = await c.submit(forApproval: false);
      expect(r1, isA<PlanFailed>());
      expect((r1 as PlanFailed).failure.message, contains('kept'));
      expect(c.topicC.text, '  Adding fractions ');
      expect(c.activitiesC.text, 'Cut paper strips');
      expect(c.saving.value, isFalse);
      offline = false;
      final r2 = await c.submit(forApproval: false);
      expect(r2, isA<PlanSaved>());
      expect(repo.created, hasLength(2));
      expect(repo.created.first, repo.created.last);
    });

    test('403 from the server is shown as "You can\'t create this lesson plan" with the server text; 400 shows the server message', () async {
      repo.onCreate = (_) async => throw ApiException('You can only create lesson plans for yourself', statusCode: 403);
      final c = await make();
      fill(c);
      var r = await c.submit(forApproval: false) as PlanFailed;
      expect(r.failure.isForbidden, isTrue);
      expect(r.failure.message, contains('You can only create lesson plans for yourself'));
      repo.onCreate = (_) async => throw ApiException('LessonPlan validation failed: topic: Path `topic` is required.', statusCode: 400);
      r = await c.submit(forApproval: false) as PlanFailed;
      expect(r.failure.message, contains('validation failed'));
      expect(c.submitFailure.value, isNotNull);
    });

    test('objectives: add, remove (the last line is cleared, not removed), blank lines are not sent', () async {
      final c = await make();
      fill(c);
      c.addObjective();
      c.objectives.last.controller.text = 'Second';
      c.addObjective();
      expect(c.objectives, hasLength(3));
      await c.submit(forApproval: false);
      expect(repo.created.single['objectives'], ['Add fractions', 'Second']);
      c.removeObjective(c.objectives.first.id);
      c.removeObjective(c.objectives.first.id);
      expect(c.objectives, hasLength(1));
      c.removeObjective(c.objectives.first.id);
      expect(c.objectives, hasLength(1));
      expect(c.objectives.first.controller.text, '');
    });

    test('isDirty: false until something is typed', () async {
      final c = await make();
      expect(c.isDirty, isFalse);
      c.topicC.text = 'x';
      expect(c.isDirty, isTrue);
    });
  });

  group('LessonPlanFormController (edit, resubmit, RAW \$SET safety)', () {
    final rejected = plan('r1', status: 'rejected', reason: 'Add an assessment section', objectives: ['Add fractions'], resources: ['Textbook'], method: 'lecture', homework: 'Ex 1');

    Future<LessonPlanFormController> make(LessonPlanRecord editing) async {
      final h = await signedIn();
      final list = LessonPlansController(repository: repo, auth: h.auth, permissions: h.perms);
      list.upsert(editing);
      final c = LessonPlanFormController(repository: repo, auth: h.auth, list: list, clock: () => fixedNow, editing: editing);
      c.onInit();
      addTearDown(c.onClose);
      return c;
    }

    test('the form is prefilled from the plan; class and subject are read-only', () async {
      final c = await make(rejected);
      expect(c.topicC.text, 'Fractions');
      expect(c.durationC.text, '40');
      expect(c.methodology.value, 'lecture');
      expect(c.resources, {'Textbook'});
      expect(c.objectives.map((o) => o.controller.text), ['Add fractions']);
      expect(c.classLabel, 'Grade 5 - A');
      expect(c.subjectLabel, 'Mathematics');
      expect(c.isDirty, isFalse);
    });

    test('nothing changed: nothing is sent', () async {
      final c = await make(rejected);
      expect(await c.submit(forApproval: false), isA<PlanNoChanges>());
      expect(repo.calls, isEmpty);
    });

    test('PATCH contains ONLY the edited fields (objectives as learningObjectives), never server fields', () async {
      final c = await make(rejected);
      c.assessmentC.text = 'Exit ticket';
      c.addObjective();
      c.objectives.last.controller.text = 'Compare fractions';
      final r = await c.submit(forApproval: false);
      expect(r, isA<PlanSaved>());
      final p = repo.patches.single;
      expect(p.id, 'r1');
      expect(p.patch.keys.toSet(), {'assessment', 'learningObjectives'});
      expect(p.patch['learningObjectives'], ['Add fractions', 'Compare fractions']);
      for (final k in ['status', 'approvedBy', 'rejectionReason', 'approverNotes', 'tenantId', 'teacherId', 'campusId', 'objectives']) {
        expect(p.patch.containsKey(k), isFalse, reason: k);
      }
    });

    test('rejected -> edit -> resubmit sends the edits plus status:submitted (and only that)', () async {
      final c = await make(rejected);
      c.assessmentC.text = 'Exit ticket';
      final r = await c.submit(forApproval: true);
      expect((r as PlanSaved).submitted, isTrue);
      expect(repo.patches.single.patch, {'assessment': 'Exit ticket', 'status': 'submitted'});
      expect(c.list!.byId('r1')!.status, LessonPlanStatus.submitted);
    });

    test('resubmit without edits is just {status: submitted}', () async {
      final c = await make(rejected);
      await c.submit(forApproval: true);
      expect(repo.patches.single.patch, {'status': 'submitted'});
    });

    test('a failed save keeps the edits; the retry sends the same patch', () async {
      var fail = true;
      repo.onUpdate = (id, p) async {
        if (fail) throw ApiException('You can only modify your own lesson plans', statusCode: 403);
        return LessonPlanRecord.fromJson({'_id': id, 'status': 'submitted', 'topic': 'Fractions'});
      };
      final c = await make(rejected);
      c.assessmentC.text = 'Exit ticket';
      final r1 = await c.submit(forApproval: true) as PlanFailed;
      expect(r1.failure.isForbidden, isTrue);
      expect(c.assessmentC.text, 'Exit ticket');
      fail = false;
      await c.submit(forApproval: true);
      expect(repo.patches, hasLength(2));
      expect(repo.patches.first.patch, repo.patches.last.patch);
    });

    test('the server answering an unknown plan (empty 200 -> 404) is reported as not found, the form is kept', () async {
      repo.onUpdate = (id, p) async => throw ApiException('This lesson plan was not found on the server.', statusCode: 404);
      final c = await make(rejected);
      c.assessmentC.text = 'x';
      final r = await c.submit(forApproval: false) as PlanFailed;
      expect(r.failure.kind.name, 'notFound');
      expect(c.assessmentC.text, 'x');
    });
  });

  group('Parse-upload prefill (never auto-submits)', () {
    const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
    const cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

    Future<LessonPlanFormController> make(LessonPlanDraft d, {List<Map<String, Object?>> assignments = const [cls5a, cls6b]}) async {
      final h = await signedIn();
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      final list = LessonPlansController(repository: repo, auth: h.auth, permissions: h.perms);
      final c = LessonPlanFormController(repository: repo, auth: h.auth, list: list, clock: () => fixedNow, draft: d);
      c.onInit();
      addTearDown(c.onClose);
      return c;
    }

    final draft = LessonPlanDraft.fromJson(Map<String, dynamic>.from(fx6('parse_upload') as Map));

    test('fills the form from the draft, shows the banner and warnings, saves NOTHING', () async {
      final c = await make(draft);
      expect(c.topicC.text, contains('Equivalent fractions'));
      expect(c.durationC.text, '45');
      expect(c.methodology.value, 'activity');
      expect(c.resources, {'Textbook', 'Handouts'});
      expect(c.otherResourceC.text, 'Paper strips; coloured pencils');
      expect(c.objectives.map((o) => o.controller.text), hasLength(2));
      expect(c.homeworkC.text, 'Worksheet 3, questions 1-8');
      expect(c.prefilledFrom.value, 'plan.docx');
      expect(c.prefillWarnings, hasLength(2));
      expect(c.isDirty, isTrue);
      expect(repo.calls, isEmpty);
    });

    test('the date is never guessed: it stays empty and required', () async {
      final c = await make(draft);
      expect(c.planDay.value, isNull);
      final r = await c.submit(forApproval: false);
      expect((r as PlanInvalid).errors.keys, contains('date'));
      expect(repo.calls, isEmpty);
    });

    test('"Grade 5" + "Mathematics" in the document preselect MY matching class and subject only', () async {
      final c = await make(LessonPlanDraft(topic: 'T', gradeLevelGuess: 'Grade 5', subjectGuess: 'mathematics'));
      expect(c.selectedClass?.label, 'Grade 5 - A');
      expect(c.subject.value, 'Mathematics');
      expect(c.prefillHint.value, isNull);
    });

    test('a guess that matches none of my classes is only shown as a hint', () async {
      final c = await make(draft); // "Maths" / "Grade 5": grade matches, subject text does not
      expect(c.selectedClass?.label, 'Grade 5 - A');
      expect(c.subject.value, 'Mathematics'); // single subject of the picked class auto-selects
      final d = await make(const LessonPlanDraft(topic: 'T', gradeLevelGuess: 'Grade 9', subjectGuess: 'Physics'));
      expect(d.selectedClass, isNull);
      expect(d.prefillHint.value, contains('Grade 9'));
    });

    test('after review the teacher saves: the SAME body rules apply (draft status)', () async {
      final c = await make(draft, assignments: const [cls5a]);
      c.setPlanDay(DateTime(2026, 10, 9));
      await c.submit(forApproval: false);
      expect(repo.created.single['status'], 'draft');
      expect(repo.created.single['topic'], contains('Equivalent fractions'));
    });
  });

  group('LessonPlanUploadController', () {
    late FakeSourcePicker picker;
    late LessonPlanUploadController c;
    setUp(() {
      picker = FakeSourcePicker();
      c = LessonPlanUploadController(repository: repo, picker: picker);
    });

    PickedAttachment file(String name, {int size = 1000}) => PickedAttachment(name: name, path: '/tmp/$name', size: size);

    test('only .docx .xlsx .xls .csv .txt up to 10 MB are accepted; a pdf says what to do', () {
      c.setPicked(file('plan.pdf'));
      expect(c.picked.value, isNull);
      expect(c.pickNotice.value, contains('.docx'));
      c.setPicked(file('plan.doc'));
      expect(c.picked.value, isNull);
      c.setPicked(file('big.docx', size: 10 * 1024 * 1024 + 1));
      expect(c.pickNotice.value, contains('10 MB'));
      c.setPicked(file('Plan.DOCX'));
      expect(c.picked.value?.name, 'Plan.DOCX');
      expect(c.pickNotice.value, isNull);
      expect(c.canParse, isTrue);
    });

    test('a file and a link are mutually exclusive', () {
      c.setLink('https://docs.google.com/document/d/abc/edit');
      expect(c.canParse, isTrue);
      c.setPicked(file('plan.txt'));
      expect(c.link.value, '');
      c.setLink('https://docs.google.com/document/d/abc/edit');
      expect(c.picked.value, isNull);
    });

    test('parse success returns the draft; the file path is passed through and progress is reported', () async {
      c.setPicked(file('plan.docx'));
      final d = await c.parse();
      expect(d, isNotNull);
      expect(repo.parses.single.name, 'plan.docx');
      expect(repo.parses.single.link, isNull);
      expect(c.phase.value, UploadPhase.idle);
      expect(repo.calls, ['parse']);
    });

    test('link parse sends only the link', () async {
      c.setLink(' https://docs.google.com/document/d/abc/edit ');
      await c.parse();
      expect(repo.parses.single.path, isNull);
      expect(repo.parses.single.link, ' https://docs.google.com/document/d/abc/edit ');
    });

    test('AI not configured (500) and unreadable output (502): a calm "fill it in yourself" state, file kept', () async {
      repo.onParse = (p, n, l) async => throw ApiException('AI assistance is not configured on this server.', statusCode: 500);
      c.setPicked(file('plan.docx'));
      expect(await c.parse(), isNull);
      expect(c.phase.value, UploadPhase.failed);
      expect(c.failure.value!.manual, isTrue);
      expect(c.failure.value!.message, isNot(contains('configured')));
      expect(c.picked.value, isNotNull);
      repo.onParse = (p, n, l) async => throw ApiException("Could not understand this document's structure.", statusCode: 502);
      expect(await c.parse(), isNull);
      expect(c.failure.value!.manual, isTrue);
    });

    test('400 shows the server\'s own actionable text and offers a retry, not the manual fallback', () async {
      repo.onParse = (p, n, l) async => throw ApiException("PDF upload isn't supported yet - please upload the original Word/Excel file", statusCode: 400);
      c.setPicked(file('plan.txt'));
      await c.parse();
      expect(c.failure.value!.manual, isFalse);
      expect(c.failure.value!.message, contains('PDF'));
    });

    test('offline keeps the file and says to retry; the retry works', () async {
      var offline = true;
      repo.onParse = (p, n, l) async {
        if (offline) throw ApiException('No internet connection.');
        return LessonPlanDraft(topic: 'T');
      };
      c.setPicked(file('plan.docx'));
      expect(await c.parse(), isNull);
      expect(c.failure.value!.manual, isFalse);
      expect(c.failure.value!.message, contains('try again'));
      offline = false;
      expect(await c.parse(), isNotNull);
      expect(c.failure.value, isNull);
    });

    test('a draft with nothing usable is reported as unreadable', () async {
      repo.onParse = (p, n, l) async => const LessonPlanDraft();
      c.setPicked(file('plan.docx'));
      expect(await c.parse(), isNull);
      expect(c.failure.value!.manual, isTrue);
    });

    test('a second parse tap while reading is ignored', () async {
      final slow = Completer<LessonPlanDraft>();
      repo.onParse = (p, n, l) => slow.future;
      c.setPicked(file('plan.docx'));
      final first = c.parse();
      expect(c.canParse, isFalse);
      expect(await c.parse(), isNull);
      slow.complete(LessonPlanDraft(topic: 'T'));
      await first;
      expect(repo.parses, hasLength(1));
    });

    test('picker error is a notice, cancel is silent', () async {
      picker.throws = true;
      await c.pickFile();
      expect(c.pickNotice.value, isNotNull);
      picker.throws = false;
      await c.pickFile();
      expect(c.picked.value, isNull);
      picker.next = file('plan.xlsx');
      await c.pickFile();
      expect(c.picked.value?.name, 'plan.xlsx');
    });
  });

  group('LessonPlanDetailController', () {
    Future<({LessonPlansController list, LessonPlanDetailController d})> make(String id) async {
      final h = await signedIn();
      final list = LessonPlansController(repository: repo, auth: h.auth, permissions: h.perms);
      final d = LessonPlanDetailController(id: id, list: list, repository: repo);
      return (list: list, d: d);
    }

    test('cold open loads the list, then shows the plan; an unknown id is an honest not-found', () async {
      repo.mine = (_) async => [plan('p1', status: 'rejected', reason: 'Add assessment')];
      final r = await make('p1');
      await r.d.load();
      expect(r.d.plan!.rejectionReason, 'Add assessment');
      final r2 = await make('nope');
      await r2.d.load();
      expect(r2.d.state.value.status, SectionStatus.error);
      expect(r2.d.state.value.message, contains("isn't in your list"));
    });

    test('a 403 on the list is "You don\'t have access"', () async {
      repo.mine = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      final r = await make('p1');
      await r.d.load();
      expect(r.d.state.value.status, SectionStatus.forbidden);
    });

    test('submit sends ONLY {status: submitted} and updates the list', () async {
      repo.mine = (_) async => [plan('p1', status: 'draft')];
      final r = await make('p1');
      await r.d.load();
      final res = await r.d.submitForApproval();
      expect(res, isA<PlanSaved>());
      expect(repo.patches.single.patch, {'status': 'submitted'});
      expect(r.d.plan!.status, LessonPlanStatus.submitted);
      expect(r.list.byId('p1')!.status, LessonPlanStatus.submitted);
    });

    test('only draft / overdue plans can be submitted from here (a rejected one is edited and resubmitted; submitted and approved never)', () async {
      repo.mine = (_) async => [plan('r', status: 'rejected'), plan('s', status: 'submitted'), plan('a', status: 'approved')];
      for (final id in ['r', 's', 'a']) {
        final r = await make(id);
        await r.d.load();
        expect(await r.d.submitForApproval(), isA<PlanIgnored>(), reason: id);
      }
      expect(repo.patches, isEmpty);
    });

    test('double submit and failure: the plan stays a draft and the error is kept for the screen', () async {
      final slow = Completer<LessonPlanRecord>();
      repo.mine = (_) async => [plan('p1')];
      repo.onUpdate = (id, p) => slow.future;
      final r = await make('p1');
      await r.d.load();
      final first = r.d.submitForApproval();
      expect(await r.d.submitForApproval(), isA<PlanIgnored>());
      slow.completeError(ApiException('No internet connection.'));
      expect(await first, isA<PlanFailed>());
      expect(r.d.plan!.status, LessonPlanStatus.draft);
      expect(r.d.actionFailure.value!.message, contains('Nothing was changed'));
      expect(r.d.submitting.value, isFalse);
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
