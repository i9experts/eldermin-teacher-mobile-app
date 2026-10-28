// ignore_for_file: invalid_use_of_protected_member
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_early_years_repository.dart';

const nurseryA = {'gradeLevel': 'Nursery', 'sectionName': 'A', 'subjectName': 'All'};
const kg1 = {'gradeLevel': 'KG-1', 'sectionName': '', 'subjectName': 'All'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeEarlyYearsRepository repo;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeEarlyYearsRepository();
  });
  tearDown(Get.reset);

  Future<EarlyYearsController> make({List<Map<String, Object?>> assignments = const [nurseryA], List<String>? permissions}) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    return EarlyYearsController(repository: repo, auth: h.auth, permissions: h.perms);
  }

  group('my Early Years children', () {
    final everyone = [
      child(1, first: 'Zed'),
      child(2, first: 'Amy'),
      child(3, first: 'Other', section: 'B'),
      child(4, first: 'Kay', grade: 'KG-1', section: 'C'),
      child(5, first: 'Far', grade: 'Grade 9', section: 'Z'),
    ];

    test('only the children of my classes are kept, and the unfiltered list is not held anywhere', () async {
      repo.children = () async => everyone;
      final c = await make();
      await c.load();
      expect(c.state.value.status, SectionStatus.data);
      expect(c.all.map((k) => k.id), ['c2', 'c1']); // Nursery A only, by name
      expect(c.all.any((k) => k.id == 'c3' || k.id == 'c5'), isFalse);
      expect(c.childById('c5'), isNull, reason: 'a child of another class is unknown to the screens');
      expect(c.childById('c1'), isNotNull);
    });

    test('several classes: class chips narrow the list; "all classes" restores it', () async {
      repo.children = () async => everyone;
      final c = await make(assignments: [nurseryA, kg1]);
      await c.load();
      expect(c.visible.map((k) => k.id), unorderedEquals(['c1', 'c2', 'c4']));
      c.setClassFilter(1);
      expect(c.visible.map((k) => k.id), ['c4']);
      c.setClassFilter(-1);
      expect(c.visible, hasLength(3));
    });

    test('search by name or student id', () async {
      repo.children = () async => everyone;
      final c = await make();
      await c.load();
      c.query.value = 'amy';
      expect(c.visible.map((k) => k.id), ['c2']);
      c.query.value = 'st-1';
      expect(c.visible.map((k) => k.id), ['c1']);
      c.query.value = 'nobody';
      expect(c.visible, isEmpty);
    });

    test('every call goes through the repository, which owns the x-academic-year header (one children call per load)', () async {
      repo.children = () async => everyone;
      final c = await make();
      await c.load();
      await c.load(); // data present, no force: not asked again
      expect(repo.calls.where((x) => x == 'children'), hasLength(1));
      await c.load(force: true);
      expect(repo.calls.where((x) => x == 'children'), hasLength(2));
    });
  });

  group('empty and blocked states', () {
    test('no class assigned: empty, and the server is never asked for children', () async {
      final c = await make(assignments: const []);
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
      expect(c.classes, isEmpty);
      expect(repo.calls, isEmpty);
    });

    test('a class with no Early Years child: empty', () async {
      repo.children = () async => [child(9, grade: 'Grade 9', section: 'Z')];
      final c = await make();
      await c.load();
      expect(c.state.value.status, SectionStatus.empty);
    });

    test('a custom role without early-years:view is forbidden and nothing is requested', () async {
      final c = await make(permissions: const ['teaching:view', 'students:view']);
      await c.load();
      expect(c.canView, isFalse);
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('the teacher role can view and manage', () async {
      final c = await make();
      expect(c.canView, isTrue);
      expect(c.canManage, isTrue);
    });

    test('view without manage: can see the list, cannot create', () async {
      final c = await make(permissions: const ['early-years:view']);
      expect(c.canView, isTrue);
      expect(c.canManage, isFalse);
    });
  });

  group('failures', () {
    test('a 403 from the server (e.g. no campus) is forbidden with its own text', () async {
      repo.children = () async => throw ApiException('No campus assigned — contact your administrator', statusCode: 403);
      final c = await make();
      await c.load();
      expect(c.state.value.status, SectionStatus.forbidden);
      expect(c.state.value.forbiddenDetail, contains('No campus assigned'));
    });

    test('a 500 is an error with Retry; a failed refresh keeps the last good list', () async {
      repo.children = () async => [child(1)];
      final c = await make();
      await c.load();
      expect(c.all, hasLength(1));
      repo.children = () async => throw ApiException('boom', statusCode: 500);
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.error);
      expect(c.state.value.isStale, isTrue);
      expect(c.all, hasLength(1));
      repo.children = () async => [child(1), child(2)];
      await c.load(force: true);
      expect(c.state.value.status, SectionStatus.data);
      expect(c.all, hasLength(2));
    });

    test('a first-load failure has no data and says so', () async {
      repo.children = () async => throw ApiException('offline', statusCode: null);
      final c = await make();
      await c.load();
      expect(c.state.value.status, SectionStatus.error);
      expect(c.all, isEmpty);
    });

    test('a slow older answer never overwrites a newer one', () async {
      var n = 0;
      repo.children = () async {
        final mine = ++n;
        if (mine == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return [child(1, first: 'Old')];
        }
        return [child(2, first: 'New')];
      };
      final c = await make();
      final first = c.load(force: true);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await c.load(force: true);
      await first;
      expect(c.all.single.firstName, 'New2');
    });
  });
}
