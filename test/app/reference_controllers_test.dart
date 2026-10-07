// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/curriculum/controllers/curriculum_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/app/modules/library/controllers/library_controller.dart';
import 'package:eldermin_teacher_app/core/models/assessments/reference_models.dart';
import 'package:eldermin_teacher_app/core/models/paginated.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const sci6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

Curriculum cur(String id, String grade, String subject, {String status = 'active'}) => Curriculum.fromJson({'_id': id, 'name': '$subject $grade', 'gradeLevel': grade, 'subjectName': subject, 'status': status, 'slos': []});
Book book(int i, {int avail = 1}) => Book.fromJson({'_id': 'b$i', 'title': 'Book $i', 'author': 'A', 'totalCopies': 2, 'availableCopies': avail});
Paginated<Book> pageOf(List<Book> items, int page, int pages, {int? total}) => Paginated<Book>(items: items, page: page, pages: pages, total: total ?? items.length);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeReferenceRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeReferenceRepository();
  });
  tearDown(Get.reset);

  Future<({dynamic auth, dynamic perms})> boot({List<Map<String, Object?>> assignments = const [maths5a, sci6b], List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    return (auth: h.auth, perms: h.perms);
  }

  group('CurriculumController', () {
    Future<CurriculumController> make({List<Map<String, Object?>> assignments = const [maths5a, sci6b], List<String>? permissions}) async {
      final h = await boot(assignments: assignments, permissions: permissions);
      return CurriculumController(repository: repo, auth: h.auth, permissions: h.perms);
    }

    test('keeps ACTIVE curricula of MY grades; "my subjects" narrows; other grades and drafts never show', () async {
      repo.onCurricula = () async => [cur('1', 'Grade 5', 'Mathematics'), cur('2', 'Grade 5', 'English'), cur('3', 'Grade 6', 'Science'), cur('4', 'Grade 7', 'Mathematics'), cur('5', 'Grade 5', 'Mathematics', status: 'draft')];
      final c = await make();
      await c.load();
      expect(c.items.map((k) => k.id), ['2', '1', '3']); // by grade, then subject
      expect(c.scope.value, CurriculumScope.mySubjects);
      expect(c.filtered.map((k) => k.id), ['1', '3']);
      expect(c.countFor(CurriculumScope.myGrades), 3);
      c.setScope(CurriculumScope.myGrades);
      expect(c.filtered, hasLength(3));
    });

    test('nothing in my subjects: falls back to all my grades so the list is not empty by accident', () async {
      repo.onCurricula = () async => [cur('2', 'Grade 5', 'English')];
      final c = await make();
      await c.load();
      expect(c.scope.value, CurriculumScope.myGrades);
      expect(c.filtered, hasLength(1));
    });

    test('empty, 403, error + retry, no permission', () async {
      var c = await make();
      repo.onCurricula = () async => [cur('4', 'Grade 7', 'Mathematics')];
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.onCurricula = () async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
      var fail = true;
      repo.onCurricula = () async => fail ? throw ApiException('x', statusCode: 500) : [cur('1', 'Grade 5', 'Mathematics')];
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      fail = false;
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.data);
      Get.reset();
      Get.testMode = true;
      repo = FakeReferenceRepository();
      c = await make(permissions: ['teaching:view']);
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('detail: cache, cold link with the same grade test, 404', () async {
      repo.onCurricula = () async => [cur('1', 'Grade 5', 'Mathematics')];
      repo.onCurriculum = (id) async => id == 'other' ? cur('other', 'Grade 9', 'Mathematics') : cur(id, 'Grade 5', 'English');
      final list = await make();
      var d = CurriculumDetailController(id: '1', list: list, repository: repo);
      await d.load();
      expect(d.state.value.data!.id, '1');
      expect(repo.calls.where((x) => x.startsWith('curriculum:')), isEmpty);
      d = CurriculumDetailController(id: 'cold', list: list, repository: repo);
      await d.load();
      expect(d.state.value.data!.id, 'cold');
      d = CurriculumDetailController(id: 'other', list: list, repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.error);
      repo.onCurriculum = (_) async => throw ApiException('Curriculum not found', statusCode: 404);
      d = CurriculumDetailController(id: 'gone', list: list, repository: repo);
      await d.load();
      expect(d.state.value.status, SectionStatus.unavailable);
    });
  });

  group('Curriculum drafts are never shown to teachers', () {
    Future<CurriculumController> make() async {
      final h = await boot();
      return CurriculumController(repository: repo, auth: h.auth, permissions: h.perms);
    }

    test('only status "active" is visible: draft, archived, unknown and missing status are hidden (case-tolerant)', () {
      expect(cur('a', 'Grade 5', 'Maths').isVisibleToTeachers, isTrue);
      expect(Curriculum.fromJson({'_id': 'u', 'status': ' ACTIVE '}).isVisibleToTeachers, isTrue);
      for (final st in ['draft', 'archived', 'pending', '']) {
        expect(cur('x', 'Grade 5', 'Maths', status: st).isVisibleToTeachers, isFalse, reason: st);
      }
      expect(Curriculum.fromJson({'_id': 'n'}).isVisibleToTeachers, isFalse);
    });

    test('a server that returns drafts anyway: the list hides them; only drafts = empty state', () async {
      repo.onCurricula = () async => [cur('1', 'Grade 5', 'Mathematics'), cur('d', 'Grade 5', 'Mathematics', status: 'draft'), cur('z', 'Grade 5', 'Mathematics', status: 'archived')];
      final c = await make();
      await c.load();
      expect(c.items.map((e) => e.id), ['1']);
      repo.onCurricula = () async => [cur('d', 'Grade 5', 'Mathematics', status: 'draft')];
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.empty);
    });

    test('opening a draft / archived curriculum by id shows "not available"', () async {
      repo.onCurricula = () async => [cur('1', 'Grade 5', 'Mathematics')];
      final list = await make();
      for (final st in ['draft', 'archived']) {
        repo.onCurriculum = (id) async => cur(id, 'Grade 5', 'Mathematics', status: st);
        final d = CurriculumDetailController(id: 'dr', list: list, repository: repo);
        await d.load();
        expect(d.state.value.status, SectionStatus.error, reason: st);
        expect(d.state.value.message, 'This curriculum is not available.');
      }
    });
  });

  group('LibraryController', () {
    Future<LibraryController> make({List<String>? permissions}) async {
      final h = await boot(permissions: permissions);
      return LibraryController(repository: repo, auth: h.auth, permissions: h.perms);
    }

    test('first page, total, hasMore; load more appends and skips duplicates; stops on the last page', () async {
      repo.onBooks = (s, c, a, p) async => p == 1 ? pageOf([book(1), book(2)], 1, 2, total: 3) : pageOf([book(2), book(3)], 2, 2, total: 3);
      final c = await make();
      await c.load();
      expect(c.books.map((b) => b.id), ['b1', 'b2']);
      expect(c.total.value, 3);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.books.map((b) => b.id), ['b1', 'b2', 'b3']);
      expect(c.hasMore, isFalse);
      await c.loadMore();
      expect(repo.bookQueries.map((q) => q.page), [1, 2]);
    });

    test('search, category and availability go to the server and reset to page 1; clear filters', () async {
      repo.onBooks = (s, c, a, p) async => pageOf([book(1)], 1, 1);
      final c = await make();
      await c.load();
      await c.setQuery('fractions');
      await c.setCategory('textbook');
      await c.toggleAvailable(true);
      expect(repo.bookQueries.last, (search: 'fractions', category: 'textbook', available: true, page: 1));
      expect(c.filtersActive, isTrue);
      await c.clearFilters();
      expect(repo.bookQueries.last, (search: '', category: '', available: false, page: 1));
      expect(c.filtersActive, isFalse);
      final n = repo.bookQueries.length;
      await c.setQuery(' ');
      expect(repo.bookQueries.length, n); // same (blank) query: no request
    });

    test('empty result, 403, error + retry; a failed "load more" keeps the list and offers retry', () async {
      var c = await make();
      repo.onBooks = (s, cat, a, p) async => pageOf(const [], 1, 0);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      repo.onBooks = (s, cat, a, p) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.forbidden);
      repo.onBooks = (s, cat, a, p) async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      var ok = true;
      repo.onBooks = (s, cat, a, p) async => p == 1 ? pageOf([book(1)], 1, 2, total: 2) : (ok ? pageOf([book(2)], 2, 2, total: 2) : throw ApiException('offline'));
      await c.load(force: true);
      ok = false;
      await c.loadMore();
      expect(c.books, hasLength(1));
      expect(c.loadMoreError.value, contains('retry'));
      ok = true;
      await c.loadMore();
      expect(c.books, hasLength(2));
      expect(c.loadMoreError.value, isNull);
      Get.reset();
      Get.testMode = true;
      repo = FakeReferenceRepository();
      c = await make(permissions: ['teaching:view']);
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('a stale response of an older query never overwrites a newer one', () async {
      final slow = Completer<Paginated<Book>>();
      repo.onBooks = (s, c, a, p) => s.isEmpty ? slow.future : Future.value(pageOf([book(7)], 1, 1));
      final c = await make();
      final first = c.load(); // the unfiltered request is still in flight ...
      await c.setQuery('abc'); // ... when the teacher searches
      expect(c.books.single.id, 'b7');
      slow.complete(pageOf([book(1), book(2)], 1, 1));
      await first;
      expect(c.books.single.id, 'b7');
    });
  });
}
