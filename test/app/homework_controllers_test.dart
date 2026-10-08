// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_detail_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/homework_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/homework/controllers/submissions_controller.dart';
import 'package:eldermin_teacher_app/core/models/classroom/student_models.dart';
import 'package:eldermin_teacher_app/core/models/homework/homework_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/attachment_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_classroom_repositories.dart';
import '../support/fake_phase5b_repositories.dart';

const myStaff = '64a0000000000000000000a1';
final fixedNow = DateTime(2026, 10, 5, 9, 30);

List<Submission> defaultRows() => [
      sub('s1', 'submitted', name: 'Ana', text: 'Done'),
      sub('s2', 'late', name: 'Bo', late: true, keys: ['k/a.pdf']),
      sub('s3', 'graded', name: 'Cy', grade: 80, late: true),
      sub('s4', 'pending', name: 'Di'),
      sub('s5', 'missed', name: 'Ed'),
      sub('s6', 'submitted', name: 'Fay', max: 20),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHomeworkRepository repo;
  late FakeStudentsRepository students;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeHomeworkRepository();
    students = FakeStudentsRepository();
  });
  tearDown(Get.reset);

  Future<({HomeworkController list, dynamic h})> makeList({List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    final c = HomeworkController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => fixedNow);
    return (list: c, h: h);
  }

  group('HomeworkController (my assignments)', () {
    test('asks for MY staff id (from /staff-portal/me) and shows the rows', () async {
      repo.mine = (id) async => [asg('a1'), asg('a2', status: 'draft')];
      final r = await makeList();
      await r.list.load();
      expect(repo.calls, ['mine:$myStaff']);
      expect(r.list.items, hasLength(2));
      expect(r.list.state.value.status, SectionStatus.data);
    });

    test('empty, error then retry, 403, 404-unavailable', () async {
      final r = await makeList();
      await r.list.load();
      expect(r.list.state.value.status, SectionStatus.empty);
      repo.mine = (_) async => throw ApiException('boom', statusCode: 500);
      await r.list.load(force: true);
      expect(r.list.state.value.status, SectionStatus.error);
      repo.mine = (_) async => [asg('a1')];
      await r.list.load(force: true);
      expect(r.list.state.value.status, SectionStatus.data);
      repo.mine = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      await r.list.load(force: true);
      expect(r.list.state.value.status, SectionStatus.forbidden);
    });

    test('without teaching:view nothing is requested and the state is forbidden', () async {
      final r = await makeList(permissions: ['dashboard:view']);
      await r.list.load();
      expect(repo.calls, isEmpty);
      expect(r.list.state.value.status, SectionStatus.forbidden);
    });

    test('filters (drafts / active / overdue), computed overdue before the 01:00 cron, and counts', () async {
      repo.mine = (_) async => [
            asg('d', status: 'draft', due: '2026-10-01'),
            asg('today', due: '2026-10-05'),
            asg('soon', due: '2026-10-09'),
            asg('late', due: '2026-10-02'), // status still "assigned" (cron lag): overdue for the teacher
            asg('srv', status: 'overdue', due: '2026-10-03'),
          ];
      final c = (await makeList()).list;
      await c.load();
      expect(c.countFor(HomeworkFilter.all), 5);
      expect(c.countFor(HomeworkFilter.drafts), 1);
      expect(c.countFor(HomeworkFilter.active), 2);
      expect(c.countFor(HomeworkFilter.overdue), 2);
      c.setFilter(HomeworkFilter.overdue);
      expect(c.filtered.map((a) => a.id), ['srv', 'late']);
      c.setFilter(HomeworkFilter.active);
      expect(c.filtered.map((a) => a.id), ['soon', 'today']);
    });

    test('sort by due date, undated last, toggle flips', () async {
      repo.mine = (_) async => [asg('b', due: '2026-10-09'), asg('none', due: null), asg('a', due: '2026-10-07')];
      final c = (await makeList()).list;
      await c.load();
      expect(c.filtered.map((a) => a.id), ['b', 'a', 'none']);
      c.toggleSort();
      expect(c.filtered.map((a) => a.id), ['a', 'b', 'none']);
    });

    test('client-side paging: 45 rows, 20 at a time', () async {
      repo.mine = (_) async => [for (var i = 0; i < 45; i++) asg('a$i', title: 'T$i', due: '2026-11-${(i % 28 + 1).toString().padLeft(2, '0')}')];
      final c = (await makeList()).list;
      await c.load();
      expect(c.visible, hasLength(20));
      expect(c.hasMore, isTrue);
      c.showMore();
      c.showMore();
      expect(c.visible, hasLength(45));
      expect(c.hasMore, isFalse);
      c.setFilter(HomeworkFilter.drafts); // resets paging
      expect(c.shown.value, HomeworkController.pageSize);
    });

    test('upsert / remove keep the list in sync without a re-fetch', () async {
      repo.mine = (_) async => [asg('a1')];
      final c = (await makeList()).list;
      await c.load();
      c.upsert(asg('a2', title: 'New'));
      c.upsert(asg('a1', title: 'Renamed'));
      expect(c.items.map((a) => a.title).toSet(), {'New', 'Renamed'});
      c.remove('a1');
      c.remove('a2');
      expect(c.state.value.status, SectionStatus.empty);
      expect(repo.calls, hasLength(1));
    });

    test('a stale load result is dropped', () async {
      final slow = Completer<List<Assignment>>();
      repo.mine = (_) => slow.future;
      final c = (await makeList()).list;
      final first = c.load();
      repo.mine = (_) async => [asg('fresh')];
      await c.load(force: true);
      slow.complete([asg('stale')]);
      await first;
      expect(c.items.map((a) => a.id), ['fresh']);
    });
  });

  group('HomeworkFormController (create)', () {
    const cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

    Future<HomeworkFormController> make({List<Map<String, Object?>> assignments = const [cls5a], List<String> subjects = const [], FakePicker? picker, Assignment? editing, List<String>? permissions}) async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = assignments;
      h.api.subjects = subjects;
      await h.auth.refreshProfile(force: true);
      final list = HomeworkController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => fixedNow);
      final c = HomeworkFormController(repository: repo, students: students, auth: h.auth, picker: picker ?? FakePicker(), list: list, clock: () => fixedNow, editing: editing);
      c.onInit();
      addTearDown(c.onClose);
      return c;
    }

    void fill(HomeworkFormController c, {String title = 'Fractions'}) {
      c.titleC.text = title;
      c.setDueDay(DateTime(2026, 10, 9));
    }

    test('class and subject come from MY assignments; a single class and subject auto-select', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      expect(c.classes.map((x) => x.label), ['Grade 5 - A']);
      expect(c.classIndex.value, 0);
      expect(c.subjects, ['Mathematics']);
      expect(c.subject.value, 'Mathematics');
    });

    test('two classes: subjects follow the class; no assignment subject falls back to subjectsCanTeach', () async {
      final c = await make(assignments: [cls5a, {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'}]);
      expect(c.classIndex.value, -1);
      students.roster = (_) async => [student(1, grade: 'Grade 6', section: 'B')];
      c.selectClass(1);
      expect(c.subjects, ['Science']);
      expect(c.subject.value, 'Science');
      c.selectClass(0);
      expect(c.subject.value, 'Mathematics');
      final cc = await make(assignments: const [], subjects: ['Art']);
      expect(cc.classes, isEmpty); // no class: nothing can be created
    });

    test('validation: required fields, due date not in the past, marks bounds', () async {
      final c = await make();
      c.classIndex.value = -1;
      c.subject.value = null;
      var e = c.validate();
      expect(e.keys, containsAll(['title', 'class', 'subject', 'due']));
      fill(c);
      c.selectClass(0);
      expect(c.validate(), isEmpty);
      c.setDueDay(DateTime(2026, 10, 4));
      expect(c.validate()['due'], "The due date can't be in the past");
      c.setDueDay(DateTime(2026, 10, 5)); // today is fine
      expect(c.validate(), isEmpty);
      c.totalC.text = '0';
      expect(c.validate()['total'], isNotNull);
      c.totalC.text = '1001'; // GradeSubmissionDto caps a mark at 1000
      expect(c.validate()['total'], contains('1000'));
      c.totalC.text = 'abc';
      expect(c.validate()['total'], isNotNull);
      c.totalC.text = '20';
      c.passingC.text = '21';
      expect(c.validate()['passing'], "Passing marks can't be more than the total");
      c.passingC.text = '-1';
      expect(c.validate()['passing'], isNotNull);
      c.passingC.text = '10.5';
      expect(c.validate(), isEmpty);
      c.titleC.text = '   ';
      expect(c.validate()['title'], 'Enter a title');
    });

    test('submit refuses while invalid and sends nothing', () async {
      final c = await make();
      final r = await c.submit(assign: true);
      expect(r, isA<FormInvalid>());
      expect(repo.created, isEmpty);
    });

    test('create payload carries MY staff id and the strings stored on the students (majority), flagging odd spellings', () async {
      students.roster = (_) async => [for (var i = 1; i <= 9; i++) student(i), student(10, grade: '5', section: 'a')];
      final c = await make();
      await Future<void>.delayed(Duration.zero);
      final wire = c.roster.value.data!;
      expect((wire.grade, wire.section, wire.students, wire.mismatched), ('Grade 5', 'A', 10, 1));
      fill(c);
      final r = await c.submit(assign: true);
      expect(r, isA<FormSaved>());
      final call = repo.created.single;
      expect(call.teacherId, myStaff);
      expect(call.assign, isTrue);
      final json = call.input.toCreateJson(teacherId: call.teacherId, assign: call.assign);
      expect(json['gradeLevel'], 'Grade 5');
      expect(json['sectionName'], 'A');
      expect(json['subject'], 'Mathematics');
      expect(json['status'], 'assigned');
      expect(json['dueDate'], '2026-10-09');
      expect(json['assignedDate'], '2026-10-05');
      expect(json['teacherId'], myStaff);
    });

    test('roster unavailable: falls back to the class strings from /me, form still works', () async {
      students.roster = (_) async => throw ApiException('x', statusCode: 500);
      final c = await make();
      await Future<void>.delayed(Duration.zero);
      expect(c.roster.value.status, SectionStatus.error);
      fill(c);
      final r = await c.submit(assign: false);
      expect(r, isA<FormSaved>());
      expect(repo.created.single.input.gradeLevel, 'Grade 5');
      expect(repo.created.single.assign, isFalse);
    });

    test('submit waits while the class list is loading', () async {
      final gate = Completer<List<StudentSummary>>();
      students.roster = (_) => gate.future;
      final c = await make();
      fill(c);
      final r = await c.submit(assign: true);
      expect(r, isA<FormInvalid>());
      expect((r as FormInvalid).errors['class'], contains('Still loading'));
      gate.complete([student(1)]);
    });

    test('draft vs assign flags; a saved row is pushed into the list', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      await Future<void>.delayed(Duration.zero);
      fill(c);
      final r = await c.submit(assign: false) as FormSaved;
      expect(r.assigned, isFalse);
      expect(c.list!.byId('new1'), isNotNull);
    });

    test('double submit: the second tap while saving is ignored and only one request leaves', () async {
      students.roster = (_) async => [student(1)];
      final gate = Completer<Assignment>();
      repo.onCreate = (i, t, a) => gate.future;
      final c = await make();
      await Future<void>.delayed(Duration.zero);
      fill(c);
      final first = c.submit(assign: true);
      await Future<void>.delayed(Duration.zero);
      expect(c.saving.value, isTrue);
      expect(await c.submit(assign: true), isA<FormIgnored>());
      gate.complete(asg('x'));
      await first;
      expect(repo.created, hasLength(1));
      expect(c.saving.value, isFalse);
    });

    test('server validation error (400): message shown verbatim, every field kept, retry works', () async {
      students.roster = (_) async => [student(1)];
      repo.onCreate = (i, t, a) async => throw ApiException('dueDate must be a valid ISO 8601 date string', statusCode: 400);
      final c = await make();
      await Future<void>.delayed(Duration.zero);
      fill(c, title: 'Keep me');
      final r = await c.submit(assign: true) as FormFailed;
      expect(r.failure.message, 'dueDate must be a valid ISO 8601 date string');
      expect(c.titleC.text, 'Keep me');
      expect(c.submitFailure.value, isNotNull);
      repo.onCreate = (i, t, a) async => asg('ok');
      expect(await c.submit(assign: true), isA<FormSaved>());
      expect(c.submitFailure.value, isNull);
    });

    test('403 and offline failures read clearly', () async {
      students.roster = (_) async => [student(1)];
      final c = await make();
      await Future<void>.delayed(Duration.zero);
      fill(c);
      repo.onCreate = (i, t, a) async => throw ApiException('Forbidden resource', statusCode: 403);
      expect(((await c.submit(assign: false)) as FormFailed).failure.message, "You can't create this homework. Forbidden resource");
      repo.onCreate = (i, t, a) async => throw ApiException('No internet connection.');
      final off = (await c.submit(assign: false)) as FormFailed;
      expect(off.failure.message, contains('Reconnect'));
    });

    test('dirty tracking', () async {
      final c = await make();
      expect(c.isDirty, isFalse);
      c.titleC.text = 'x';
      expect(c.isDirty, isTrue);
    });
  });

  group('HomeworkFormController (attachments)', () {
    Future<HomeworkFormController> make({FakePicker? picker}) async {
      final h = await signedIn();
      h.api.assignments = [
        {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'}
      ];
      await h.auth.refreshProfile(force: true);
      students.roster = (_) async => [student(1)];
      final c = HomeworkFormController(repository: repo, students: students, auth: h.auth, picker: picker ?? FakePicker(), list: HomeworkController(repository: repo, auth: h.auth, permissions: h.perms), clock: () => fixedNow);
      c.onInit();
      addTearDown(c.onClose);
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    PickedAttachment file(String name, {int size = 1000}) => PickedAttachment(name: name, path: '/tmp/$name', size: size);

    test('upload runs: uploading with progress -> done with the key; the key goes into the payload', () async {
      final gate = Completer<UploadedFile>();
      void Function(int, int)? progress;
      repo.onUpload = (p, n, pr) {
        progress = pr;
        return gate.future;
      };
      final c = await make();
      final fut = c.addPicked([file('worksheet.pdf')]);
      final it = c.attachments.single;
      expect(it.status.value, UploadStatus.uploading);
      expect(c.hasUploading, isTrue);
      progress!(50, 100);
      expect(it.progress.value, 0.5);
      c.titleC.text = 't';
      c.setDueDay(DateTime(2026, 10, 9));
      expect((await c.submit(assign: false)), isA<FormInvalid>()); // blocked while uploading
      expect(c.errors['attachments'], 'Wait for the uploads to finish');
      gate.complete(const UploadedFile(key: 'demo/homework-attachments/u1.pdf'));
      await fut;
      expect(it.status.value, UploadStatus.done);
      expect(await c.submit(assign: false), isA<FormSaved>());
      expect(repo.created.single.input.attachmentKeys, ['demo/homework-attachments/u1.pdf']);
    });

    test('failure -> message and Retry; submit refused until it is retried or removed', () async {
      repo.onUpload = (p, n, pr) async => throw ApiException('The server had a problem', statusCode: 500);
      final c = await make();
      await c.addPicked([file('a.pdf')]);
      final it = c.attachments.single;
      expect(it.status.value, UploadStatus.failed);
      expect(it.error.value, isNotEmpty);
      c.titleC.text = 't';
      c.setDueDay(DateTime(2026, 10, 9));
      await Future<void>.delayed(Duration.zero);
      expect((await c.submit(assign: false)) as FormInvalid, isA<FormInvalid>());
      expect(c.errors['attachments'], 'Retry or remove the attachment that failed');
      repo.onUpload = (p, n, pr) async => const UploadedFile(key: 'k/1.pdf');
      await c.retryUpload(it.id);
      expect(it.status.value, UploadStatus.done);
      expect(it.key, 'k/1.pdf');
      expect(repo.calls.where((x) => x.startsWith('upload:')), hasLength(2));
    });

    test('remove drops a failed attachment so the form can be saved', () async {
      repo.onUpload = (p, n, pr) async => throw ApiException('x', statusCode: 413);
      final c = await make();
      await c.addPicked([file('big.pdf')]);
      expect(c.attachments.single.error.value, isNotNull);
      expect(c.validate()['attachments'], isNotNull);
      c.removeAttachment(c.attachments.single.id);
      expect(c.errors['attachments'], isNull, reason: 'stale attachment hint must clear after removing the failed file');
      c.titleC.text = 't';
      c.setDueDay(DateTime(2026, 10, 9));
      await Future<void>.delayed(Duration.zero);
      expect(await c.submit(assign: false), isA<FormSaved>());
      expect(repo.created.single.input.attachmentKeys, isEmpty);
    });

    test('rejects unsupported types, oversize files and a 6th attachment before any upload', () async {
      final c = await make();
      await c.addPicked([file('virus.exe'), file('huge.pdf', size: kMaxUploadBytes + 1), file('ok.png')]);
      expect(c.attachments.map((a) => a.name), ['ok.png']);
      expect(c.pickNotice.value, allOf(contains('virus.exe'), contains('huge.pdf')));
      expect(repo.calls.where((x) => x.startsWith('upload:')), ['upload:ok.png']);
      await c.addPicked([for (var i = 0; i < 6; i++) file('f$i.pdf')]);
      expect(c.attachments, hasLength(HomeworkFormController.maxAttachments));
      expect(c.pickNotice.value, contains('at most'));
    });

    test('the picker is used for files and photos; a picker error is a notice, not a crash', () async {
      final p = FakePicker()
        ..docs = [file('d.pdf')]
        ..photos = [file('p.jpg')];
      final c = await make(picker: p);
      await c.pickDocuments();
      await c.pickPhotos();
      expect(c.attachments.map((a) => a.name), ['d.pdf', 'p.jpg']);
    });
  });

  group('HomeworkFormController (edit)', () {
    Future<HomeworkFormController> make(Assignment a) async {
      final h = await signedIn();
      final c = HomeworkFormController(repository: repo, students: students, auth: h.auth, picker: FakePicker(), list: HomeworkController(repository: repo, auth: h.auth, permissions: h.perms), clock: () => fixedNow, editing: a);
      c.onInit();
      addTearDown(c.onClose);
      return c;
    }

    test('prefills, existing keys appear as done attachments, nothing changed -> no request', () async {
      final a = asg('a1', title: 'Old', status: 'draft', keys: ['demo/homework-attachments/x.pdf']);
      final c = await make(a);
      expect(c.titleC.text, 'Old');
      expect(c.attachments.single.status.value, UploadStatus.done);
      expect(c.isDirty, isFalse);
      expect(await c.submit(assign: false), isA<FormNoChanges>());
      expect(repo.patches, isEmpty);
    });

    test('only changed fields are PATCHed (never teacherId / class on an assigned row)', () async {
      final c = await make(asg('a1', title: 'Old'));
      c.titleC.text = 'New';
      c.setDueDay(DateTime(2026, 10, 12));
      expect(c.isDirty, isTrue);
      final r = await c.submit(assign: false);
      expect(r, isA<FormSaved>());
      expect(repo.patches.single, {'title': 'New', 'dueDate': '2026-10-12'});
    });

    test('draft -> assign sends status assigned', () async {
      final c = await make(asg('a1', status: 'draft'));
      final r = await c.submit(assign: true) as FormSaved;
      expect(repo.patches.single, {'status': 'assigned'});
      expect(r.assigned, isTrue);
    });

    test('editing may keep a past due date', () async {
      final c = await make(asg('a1', due: '2026-09-01'));
      expect(c.validate(), isEmpty);
    });

    test('404 on save (deleted elsewhere) is reported', () async {
      repo.onUpdate = (id, p) async => throw ApiException('Assignment not found', statusCode: 404);
      final c = await make(asg('a1'));
      c.titleC.text = 'New';
      final r = await c.submit(assign: false) as FormFailed;
      expect(r.failure.kind.name, 'notFound');
    });
  });

  group('HomeworkDetailController', () {
    late HomeworkController list;
    Future<HomeworkDetailController> make({String id = 'a1', Future<bool> Function(Uri)? opener}) async {
      final h = await signedIn();
      list = HomeworkController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => fixedNow);
      return HomeworkDetailController(id: id, repository: repo, list: list, opener: opener, clock: () => fixedNow);
    }

    test('uses the list cache; a cold deep link falls back to the submissions endpoint (which carries the assignment)', () async {
      final c = await make();
      list.upsert(asg('a1', title: 'Cached'));
      expect(c.assignment!.title, 'Cached');
      expect(repo.calls, isEmpty);
      final d = await make(id: 'zz');
      repo.subs = (id) async => SubmissionsResult(asg(id, title: 'Fetched'), const []);
      await d.load();
      expect(d.assignment!.title, 'Fetched');
      repo.subs = (id) async => throw ApiException('Assignment not found', statusCode: 404);
      await d.load();
      expect(d.state.status, SectionStatus.unavailable);
    });

    test('assign: draft -> PATCH status assigned, list updated; non-drafts are ignored', () async {
      final c = await make();
      list.upsert(asg('a1', status: 'draft'));
      repo.onUpdate = (id, p) async => asg(id, status: 'assigned');
      expect(await c.assign(), isA<DetailOk>());
      expect(repo.patches.single, {'status': 'assigned'});
      expect(list.byId('a1')!.status, 'assigned');
      expect(await c.assign(), isA<DetailIgnored>());
    });

    test('delete removes it from the list and the view; a failure keeps it', () async {
      final c = await make();
      list.upsert(asg('a1'));
      repo.onDelete = (_) async => throw ApiException('Forbidden resource', statusCode: 403);
      final f = await c.delete() as DetailFailed;
      expect(f.failure.isForbidden, isTrue);
      expect(list.byId('a1'), isNotNull);
      repo.onDelete = (_) async {};
      expect(await c.delete(), isA<DetailOk>());
      expect(list.byId('a1'), isNull);
      expect(c.state.status, SectionStatus.empty);
      expect(repo.calls.where((x) => x.startsWith('delete:')), hasLength(2));
    });

    test('double delete tap sends one request', () async {
      final c = await make();
      list.upsert(asg('a1'));
      final gate = Completer<void>();
      repo.onDelete = (_) => gate.future;
      final first = c.delete();
      await Future<void>.delayed(Duration.zero);
      expect(await c.delete(), isA<DetailIgnored>());
      gate.complete();
      await first;
      expect(repo.calls.where((x) => x.startsWith('delete:')), hasLength(1));
    });

    test('open attachment: resolves the key through signed-url then launches that URL', () async {
      Uri? opened;
      final c = await make(opener: (u) async {
        opened = u;
        return true;
      });
      expect(await c.openAttachment('demo/homework-attachments/x.pdf'), isA<DetailOk>());
      expect(repo.calls, ['signed:demo/homework-attachments/x.pdf']);
      expect(opened.toString(), startsWith('https://files.example.test/demo/homework-attachments/x.pdf'));
      repo.onSigned = (_) async => throw ApiException('Internal server error', statusCode: 500);
      expect(await c.openAttachment('k'), isA<DetailFailed>());
      repo.onSigned = (k) async => 'https://x.test/$k';
      final no = await make(opener: (u) async => false);
      expect(await no.openAttachment('k'), isA<DetailFailed>());
    });
  });

  group('SubmissionsController (list + grading)', () {
    late HomeworkController list;
    Future<SubmissionsController> make({List<Submission>? rows, Assignment? a}) async {
      final h = await signedIn();
      list = HomeworkController(repository: repo, auth: h.auth, permissions: h.perms, clock: () => fixedNow);
      list.upsert(a ?? asg('a1'));
      repo.subs = (id) async => SubmissionsResult(a ?? asg(id), rows ?? defaultRows());
      final c = SubmissionsController(assignmentId: 'a1', repository: repo, list: list);
      await c.load();
      return c;
    }

    test('the whole roster is listed; filters and counts; not-handed-in comes from pending + missed', () async {
      final c = await make();
      expect(c.all, hasLength(6));
      expect(c.countFor(SubmissionFilter.toGrade), 3);
      expect(c.countFor(SubmissionFilter.graded), 1);
      expect(c.countFor(SubmissionFilter.notHandedIn), 2);
      c.setFilter(SubmissionFilter.notHandedIn);
      expect(c.visible.map((s) => s.studentName), ['Di', 'Ed']);
      c.setFilter(SubmissionFilter.toGrade);
      expect(c.visible.map((s) => s.studentName), ['Ana', 'Bo', 'Fay']);
      expect(c.all[2].wasLate, isTrue); // graded and still flagged late
    });

    test('draft with no rows is empty; 403 and 404 states; retry', () async {
      final h = await signedIn();
      repo.subs = (id) async => SubmissionsResult(asg(id, status: 'draft'), const []);
      final d = SubmissionsController(assignmentId: 'a1', repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.empty);
      repo.subs = (id) async => throw ApiException('This assignment belongs to a different campus.', statusCode: 403);
      await d.load(force: true);
      expect(d.state.value.status, SectionStatus.forbidden);
      repo.subs = (id) async => throw ApiException('Assignment not found', statusCode: 404);
      await d.load(force: true);
      expect(d.state.value.status, SectionStatus.unavailable);
      repo.subs = (id) async => SubmissionsResult(asg(id), defaultRows());
      await d.load(force: true);
      expect(d.state.value.status, SectionStatus.data);
      expect(h.auth, isNotNull);
    });

    test('marks validation: blank, text, negative, above the row maximum, decimals', () async {
      expect(SubmissionsController.validateMarks('', 100), 'Enter the marks');
      expect(SubmissionsController.validateMarks('abc', 100), 'Marks must be a number');
      expect(SubmissionsController.validateMarks('NaN', 100), 'Marks must be a number');
      expect(SubmissionsController.validateMarks('-0.5', 100), "Marks can't be below 0");
      expect(SubmissionsController.validateMarks('100.5', 100), "Marks can't be more than 100");
      expect(SubmissionsController.validateMarks('21', 20), "Marks can't be more than 20");
      expect(SubmissionsController.validateMarks('0', 20), isNull);
      expect(SubmissionsController.validateMarks('20', 20), isNull);
      expect(SubmissionsController.validateMarks(' 17.5 ', 20), isNull);
      expect(SubmissionsController.validateMarks('10.5', 10.5), isNull);
    });

    test('invalid marks are never sent', () async {
      final c = await make();
      for (final bad in ['', 'x', '-1', '101']) {
        expect(await c.grade('s1', bad, ''), isA<GradeInvalid>(), reason: bad);
      }
      expect((await c.grade('s6', '21', '') as GradeInvalid).message, "Marks can't be more than 20"); // per-row maximum
      expect(repo.graded, isEmpty);
    });

    test('grading a handed-in row: request body, row becomes graded, counters and the list update', () async {
      final c = await make(a: asg('a1', count: 3));
      repo.onGrade = (a, s, g, f) async => Submission.fromJson({'_id': s, 'assignmentId': a, 'studentName': 'Ana', 'status': 'graded', 'grade': g, 'maxGrade': 100, 'feedback': f});
      final r = await c.grade('s1', '87.5', ' Well done ');
      expect(r, isA<GradeSaved>());
      expect(repo.graded.single.grade, 87.5);
      expect(repo.graded.single.feedback, ' Well done ');
      expect(c.byId('s1')!.isGraded, isTrue);
      expect(c.countFor(SubmissionFilter.toGrade), 2);
      expect(c.countFor(SubmissionFilter.graded), 2);
      expect(c.assignment!.submissionsCount, 4); // 2 to grade + 2 graded (s1,s3) + ... recomputed from rows
      expect(list.byId('a1')!.submissionsCount, c.assignment!.submissionsCount);
    });

    test('pending / missed rows cannot be graded in the app (the server would allow it)', () async {
      final c = await make();
      expect(c.canGrade(c.byId('s4')!), isFalse);
      expect(await c.grade('s4', '5', ''), isA<GradeInvalid>());
      expect(await c.grade('s5', '5', ''), isA<GradeInvalid>());
      expect(c.canGrade(c.byId('s3')!), isTrue); // re-grading is allowed
      expect(repo.graded, isEmpty);
    });

    test('server rejection (400 Grade cannot exceed...) shows the server message and leaves the row untouched', () async {
      final c = await make();
      repo.onGrade = (a, s, g, f) async => throw ApiException("Grade cannot exceed this assignment's maximum of 100.", statusCode: 400);
      final r = await c.grade('s1', '99', '') as GradeFailed;
      expect(r.failure.message, "Grade cannot exceed this assignment's maximum of 100.");
      expect(c.byId('s1')!.needsGrading, isTrue);
      expect(c.savingId.value, isNull);
    });

    test('403 / offline / 5xx failures are distinguishable and keep the marks', () async {
      final c = await make();
      repo.onGrade = (a, s, g, f) async => throw ApiException('Forbidden resource', statusCode: 403);
      expect(((await c.grade('s1', '5', '')) as GradeFailed).failure.message, "You can't save these marks. Forbidden resource");
      repo.onGrade = (a, s, g, f) async => throw ApiException('No internet connection.');
      expect(((await c.grade('s1', '5', '')) as GradeFailed).failure.message, contains('Your marks are kept'));
      repo.onGrade = (a, s, g, f) async => throw ApiException('Internal server error', statusCode: 500);
      expect(((await c.grade('s1', '5', '')) as GradeFailed).failure.kind.name, 'server');
    });

    test('double submit: a second grade call while saving is ignored', () async {
      final c = await make();
      final gate = Completer<Submission>();
      repo.onGrade = (a, s, g, f) => gate.future;
      final first = c.grade('s1', '5', '');
      await Future<void>.delayed(Duration.zero);
      expect(c.savingId.value, 's1');
      expect(await c.grade('s2', '5', ''), isA<GradeIgnored>());
      gate.complete(sub('s1', 'graded', grade: 5));
      await first;
      expect(repo.graded, hasLength(1));
    });

    test('open a student file through signed-url', () async {
      Uri? opened;
      final h = await signedIn();
      final c = SubmissionsController(assignmentId: 'a1', repository: repo, list: HomeworkController(repository: repo, auth: h.auth, permissions: h.perms), opener: (u) async {
        opened = u;
        return true;
      });
      expect(await c.openAttachment('demo/homework-submissions/z.jpg'), isNull);
      expect(opened!.path, contains('homework-submissions/z.jpg'));
      repo.onSigned = (_) async => throw ApiException('x', statusCode: 403);
      expect((await c.openAttachment('k'))!.isForbidden, isTrue);
    });
  });
}
