// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/curriculum/controllers/curriculum_controller.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/views/curriculum_detail_screen.dart';
import 'package:eldermin_teacher_app/app/modules/curriculum/views/curriculum_screen.dart';
import 'package:eldermin_teacher_app/app/modules/library/controllers/library_controller.dart';
import 'package:eldermin_teacher_app/app/modules/library/views/library_screen.dart';
import 'package:eldermin_teacher_app/core/models/assessments/reference_models.dart';
import 'package:eldermin_teacher_app/core/models/paginated.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_assessment_repositories.dart';

const maths5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};

Curriculum cur(String id, String grade, String subject, {List<Map<String, Object?>> slos = const []}) =>
    Curriculum.fromJson({'_id': id, 'name': '$subject $grade (SNC)', 'gradeLevel': grade, 'subjectName': subject, 'status': 'active', 'framework': 'national', 'academicYearLabel': '2026-27', 'slos': slos, 'standardsMapping': [{'standard': 'SNC 2020', 'code': 'M-5', 'description': 'Number'}]});

Book book(int i, {int avail = 2, int total = 3}) => Book.fromJson({'_id': 'b$i', 'title': 'Book $i', 'author': 'Author $i', 'category': 'textbook', 'totalCopies': total, 'availableCopies': avail, 'location': 'Main library', 'shelfNo': 'S-1', 'publishYear': 2020, 'purchasePrice': 1450});

void main() {
  late FakeReferenceRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeReferenceRepository();
  });
  tearDown(Get.reset);

  Future<dynamic> signIn(WidgetTester t, {List<String>? permissions}) async => (await t.runAsync(() async {
        final h = await signedIn(permissions: permissions);
        h.api.assignments = const [maths5a];
        await h.auth.refreshProfile(force: true);
        return h;
      }))!;

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 3000)}) async {
    await t.binding.setSurfaceSize(size);
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => screen));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  group('Curriculum screens', () {
    Future<CurriculumController> boot(WidgetTester t, List<Curriculum> rows) async {
      final h = await signIn(t);
      repo.onCurricula = () async => rows;
      final c = Get.put(CurriculumController(repository: repo, auth: h.auth, permissions: h.perms));
      await open(t, const CurriculumScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('list: my grades only, my subject tagged, scope chips with counts, SLO counts; read-only (no add / edit)', (t) async {
      await boot(t, [cur('1', 'Grade 5', 'Mathematics', slos: [{'sloCode': 'A'}, {'sloCode': 'B'}]), cur('2', 'Grade 5', 'English'), cur('3', 'Grade 9', 'Mathematics')]);
      expect(find.text('Mathematics Grade 5 (SNC)'), findsOneWidget);
      expect(find.text('English Grade 5 (SNC)'), findsNothing); // default scope: my subjects
      expect(find.text('Mathematics Grade 9 (SNC)'), findsNothing);
      expect(find.text('YOUR SUBJECT'), findsOneWidget);
      expect(find.text('2 learning outcomes · national'), findsOneWidget);
      expect(find.text('My subjects  1'), findsOneWidget);
      expect(find.text('All my grades  2'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_myGrades')));
      await settle(t);
      expect(find.text('English Grade 5 (SNC)'), findsOneWidget);
      for (final w in ['Add', 'Create', 'Edit', 'Delete', 'Approve']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });

    testWidgets('shimmer, empty, error + Try again, 403', (t) async {
      final h = await signIn(t);
      final gate = Completer<List<Curriculum>>();
      repo.onCurricula = () => gate.future;
      final c = Get.put(CurriculumController(repository: repo, auth: h.auth, permissions: h.perms));
      await open(t, const CurriculumScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete([]);
      await settle(t);
      expect(find.text('No curriculum for your grades yet'), findsOneWidget);
      repo.onCurricula = () async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.onCurricula = () async => [cur('1', 'Grade 5', 'Mathematics')];
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Mathematics Grade 5 (SNC)'), findsOneWidget);
      repo.onCurricula = () async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
    });

    testWidgets('detail: SLOs grouped by strand with Bloom level, assessed note, standards', (t) async {
      final h = await signIn(t);
      final k = cur('1', 'Grade 5', 'Mathematics', slos: [
        {'sloCode': 'M5-N-01', 'description': 'Add fractions', 'strand': 'Number', 'bloomsLevel': 'apply', 'isAssessed': true, 'assessmentType': 'written'},
        {'sloCode': 'M5-M-01', 'description': 'Perimeter', 'strand': 'Measurement', 'bloomsLevel': 'apply', 'isAssessed': false},
      ]);
      repo.onCurricula = () async => [k];
      final list = Get.put(CurriculumController(repository: repo, auth: h.auth, permissions: h.perms));
      final d = Get.put(CurriculumDetailController(id: '1', list: list, repository: repo));
      await open(t, const CurriculumDetailScreen());
      await d.load();
      await settle(t);
      expect(find.text('Number (1)'), findsOneWidget);
      expect(find.text('Measurement (1)'), findsOneWidget);
      expect(find.text('M5-N-01'), findsOneWidget);
      expect(find.text('Add fractions'), findsOneWidget);
      expect(find.text('APPLY'), findsNWidgets(2));
      expect(find.text('Assessed: written'), findsOneWidget);
      expect(find.text('SNC 2020 · M-5'), findsOneWidget);
    });

    testWidgets('detail without outcomes says so; a curriculum that is not for my grades is refused', (t) async {
      final h = await signIn(t);
      repo.onCurricula = () async => [cur('1', 'Grade 5', 'Mathematics')];
      repo.onCurriculum = (_) async => cur('x', 'Grade 9', 'Mathematics');
      final list = Get.put(CurriculumController(repository: repo, auth: h.auth, permissions: h.perms));
      final d = Get.put(CurriculumDetailController(id: '1', list: list, repository: repo));
      await open(t, const CurriculumDetailScreen());
      await d.load();
      await settle(t);
      expect(find.byKey(const Key('cur_no_slos')), findsOneWidget);
      Get.delete<CurriculumDetailController>();
      final other = Get.put(CurriculumDetailController(id: 'x', list: list, repository: repo));
      await other.load();
      expect(other.state.value.message, contains("isn't available"));
    });
  });

  group('Library screen', () {
    Future<LibraryController> boot(WidgetTester t, Future<Paginated<Book>> Function(String, String, bool, int) f) async {
      final h = await signIn(t);
      repo.onBooks = f;
      final c = Get.put(LibraryController(repository: repo, auth: h.auth, permissions: h.perms));
      await open(t, const LibraryScreen());
      await c.load();
      await settle(t);
      return c;
    }

    testWidgets('catalogue: title, author, availability tag, location; no price, no issue / return / fine / reserve actions', (t) async {
      await boot(t, (s, c, a, p) async => Paginated<Book>(items: [book(1), book(2, avail: 0)], page: 1, pages: 1, total: 2));
      expect(find.text('Book 1'), findsOneWidget);
      expect(find.text('2 OF 3 AVAILABLE'), findsOneWidget);
      expect(find.text('ALL ISSUED'), findsOneWidget);
      expect(find.text('Author 1 · 2020'), findsOneWidget);
      expect(find.text('Main library · shelf S-1'), findsNWidgets(2));
      expect(find.text('2 books'), findsOneWidget);
      expect(find.textContaining('1450'), findsNothing);
      for (final w in ['Issue', 'Return', 'Fine', 'Reserve', 'Renew', 'Borrow']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });

    testWidgets('search is debounced and sent to the server; Available now and a category chip filter; clear brings everything back', (t) async {
      final c = await boot(t, (s, cat, a, p) async => Paginated<Book>(items: s.isEmpty ? [book(1), book(2)] : [book(9)], page: 1, pages: 1, total: s.isEmpty ? 2 : 1));
      await t.enterText(find.byKey(const Key('lib_search')), 'fractions');
      await t.pump(const Duration(milliseconds: 100));
      expect(repo.bookQueries.where((q) => q.search == 'fractions'), isEmpty); // still debouncing
      await t.pump(const Duration(milliseconds: 600));
      await settle(t);
      expect(repo.bookQueries.last.search, 'fractions');
      expect(find.text('Book 9'), findsOneWidget);
      await t.tap(find.byKey(const Key('chip_available')));
      await settle(t);
      expect(repo.bookQueries.last.available, isTrue);
      await t.tap(find.byKey(const Key('chip_cat_textbook')));
      await settle(t);
      expect(repo.bookQueries.last.category, 'textbook');
      await c.clearFilters();
      await settle(t);
      expect(find.text('Book 1'), findsOneWidget);
    });

    testWidgets('no match: explains whole-word search; empty catalogue: different message; error + retry; 403', (t) async {
      final c = await boot(t, (s, cat, a, p) async => Paginated<Book>(items: const [], page: 1, pages: 0, total: 0));
      expect(find.text('The catalogue is empty'), findsOneWidget);
      await c.setQuery('fract');
      await settle(t);
      expect(find.text('No books match'), findsOneWidget);
      expect(find.textContaining('whole words'), findsOneWidget);
      repo.onBooks = (s, cat, a, p) async => throw ApiException('x', statusCode: 500);
      await c.load(force: true);
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      repo.onBooks = (s, cat, a, p) async => Paginated<Book>(items: [book(1)], page: 1, pages: 1, total: 1);
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Book 1'), findsOneWidget);
      repo.onBooks = (s, cat, a, p) async => throw ApiException('Forbidden resource', statusCode: 403);
      await c.load(force: true);
      await settle(t);
      expect(find.text("You don't have access"), findsOneWidget);
      expect(find.byKey(const Key('lib_search')), findsNothing);
    });

    testWidgets('scrolling to the end loads the next page; a failed page offers retry', (t) async {
      var failPage2 = true;
      await boot(t, (s, cat, a, p) async {
        if (p == 1) return Paginated<Book>(items: [for (var i = 1; i <= 20; i++) book(i)], page: 1, pages: 2, total: 22);
        if (failPage2) throw ApiException('offline');
        return Paginated<Book>(items: [book(21), book(22)], page: 2, pages: 2, total: 22);
      });
      await t.binding.setSurfaceSize(const Size(430, 800));
      await t.pump();
      await t.drag(find.byType(ListView).first, const Offset(0, -20000));
      await settle(t);
      await t.pump(const Duration(milliseconds: 400));
      await t.drag(find.byType(ListView).first, const Offset(0, -20000));
      await settle(t);
      expect(find.byKey(const Key('lib_more_retry')), findsOneWidget);
      failPage2 = false;
      await t.tap(find.byKey(const Key('lib_more_retry')));
      await settle(t);
      await t.drag(find.byType(ListView).first, const Offset(0, -20000));
      await settle(t);
      expect(find.text('Book 22'), findsOneWidget);
    });
  });
}
