// ignore_for_file: invalid_use_of_protected_member
import 'dart:io';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_child_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_controller.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/fake_early_years_repository.dart';

const nurseryA = {'gradeLevel': 'Nursery', 'sectionName': 'A', 'subjectName': 'All'};

EceEvidence photo(String name) => EceEvidence(type: 'photo', url: 'https://b.s3.x.amazonaws.com/school/ece-evidence/$name.jpg');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeEarlyYearsRepository repo;
  var clock = DateTime(2026, 10, 5, 9);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeEarlyYearsRepository();
    clock = DateTime(2026, 10, 5, 9);
    repo.domains = () async => const [EceDomain(id: 'd2', name: 'Language', order: 2), EceDomain(id: 'd1', name: 'Physical', order: 1)];
    repo.profile = (_) async => EceProfile.fromJson({
          'domainSummaries': [
            {'domainId': 'd2', 'currentLevel': 'Consistent', 'evidenceCount': 4, 'lastObservedAt': '2026-10-01T09:00:00.000Z'},
            {'domainId': 'd1', 'currentLevel': 'Developing', 'evidenceCount': 1},
            {'domainId': 'dX', 'currentLevel': 'Odd level', 'evidenceCount': 2},
          ],
          'interests': ['Animals'],
          'schemas': ['Rotation'],
        });
  });
  tearDown(Get.reset);

  Future<EarlyYearsChildController> make({
    String id = 'c1',
    EceChild? initial,
    List<Map<String, Object?>> assignments = const [nurseryA],
    List<String>? permissions,
    bool useInitial = true,
  }) async {
    final h = await signedIn(permissions: permissions);
    h.api.assignments = assignments;
    await h.auth.refreshProfile(force: true);
    return EarlyYearsChildController(
      childId: id,
      initial: useInitial ? (initial ?? child(1)) : null,
      repository: repo,
      auth: h.auth,
      permissions: h.perms,
      now: () => clock,
    );
  }

  group('loading a child of my class', () {
    test('three sections load; progress rows carry domain names, order and level position', () async {
      repo.observations = (_) async => [EceObservation.fromJson({'_id': 'o1', 'narrative': 'n'})];
      repo.portfolio = (_) async => [EcePortfolioEntry.fromJson({'_id': 'p1', 'title': 't'})];
      final c = await make();
      await c.load();
      expect(c.childState.value.status, SectionStatus.data);
      expect(c.profileState.value.status, SectionStatus.data);
      expect(c.observationsState.value.status, SectionStatus.data);
      expect(c.portfolioState.value.status, SectionStatus.data);
      expect(c.progress.map((p) => p.name), ['Physical', 'Language', 'Learning area']); // by domain order; unknown domain last, neutral name
      expect(c.progress[0].fraction, closeTo(3 / 6, 1e-9)); // Developing is 3rd of the default six
      expect(c.progress[1].fraction, closeTo(4 / 6, 1e-9));
      expect(c.progress[2].fraction, isNull); // a level that is not one of the framework's: no bar, the label still shows
      expect(c.progress[1].evidenceCount, 4);
      expect(c.ageText, '4 years 7 months');
      expect(c.canManage, isTrue);
    });

    test('the framework\'s own level names drive the bar', () async {
      repo.levels = () async => ['Low', 'Developing', 'High'];
      final c = await make();
      await c.load();
      expect(c.progress.firstWhere((p) => p.name == 'Physical').fraction, closeTo(2 / 3, 1e-9));
    });

    test('domain or level lookups failing never blank the progress', () async {
      repo.domains = () async => throw ApiException('boom', statusCode: 500);
      repo.levels = () async => throw ApiException('boom', statusCode: 500);
      final c = await make();
      await c.load();
      expect(c.profileState.value.status, SectionStatus.data);
      expect(c.progress.every((p) => p.name == 'Learning area'), isTrue);
      expect(c.progress.first.fraction, isNotNull); // default levels
    });

    test('a never-observed child: honest empty states', () async {
      repo.profile = (_) async => const EceProfile();
      final c = await make();
      await c.load();
      expect(c.profileState.value.status, SectionStatus.empty);
      expect(c.observationsState.value.status, SectionStatus.empty);
      expect(c.portfolioState.value.status, SectionStatus.empty);
    });

    test('a failing section does not touch the others, and recovers on retry', () async {
      var fail = true;
      repo.observations = (_) async {
        if (fail) throw ApiException('boom', statusCode: 500);
        return [EceObservation.fromJson({'_id': 'o1'})];
      };
      repo.portfolio = (_) async => [EcePortfolioEntry.fromJson({'_id': 'p1'})];
      final c = await make();
      await c.load();
      expect(c.observationsState.value.status, SectionStatus.error);
      expect(c.profileState.value.status, SectionStatus.data);
      expect(c.portfolioState.value.status, SectionStatus.data);
      fail = false;
      await c.load(force: true);
      expect(c.observationsState.value.status, SectionStatus.data);
    });

    test('a 403 on one section is forbidden for that section only', () async {
      repo.portfolio = (_) async => throw ApiException('No campus assigned — contact your administrator', statusCode: 403);
      final c = await make();
      await c.load();
      expect(c.portfolioState.value.status, SectionStatus.forbidden);
      expect(c.profileState.value.status, SectionStatus.data);
    });

    test('skill names are fetched only when an observation names a skill; a failure is ignored', () async {
      repo.observations = (_) async => [
            EceObservation.fromJson({'_id': 'o1', 'skillMappings': [{'skillId': 's1', 'progressionLevel': 'Emerging'}]})
          ];
      repo.skills = (_) async => const [EceSkill(id: 's1', domainId: 'd1', name: 'Pencil Control')];
      final c = await make();
      await c.load();
      await Future<void>.delayed(Duration.zero);
      expect(c.skillNames['s1'], 'Pencil Control');

      Get.reset();
      Get.testMode = true;
      repo = FakeEarlyYearsRepository()..skills = (_) async => throw ApiException('x', statusCode: 500);
      repo.observations = (_) async => [
            EceObservation.fromJson({'_id': 'o1', 'skillMappings': [{'skillId': 's1', 'progressionLevel': 'Emerging'}]})
          ];
      final c2 = await make();
      await c2.load();
      await Future<void>.delayed(Duration.zero);
      expect(c2.observationsState.value.status, SectionStatus.data);
      expect(c2.skillNames, isEmpty);

      Get.reset();
      Get.testMode = true;
      repo = FakeEarlyYearsRepository();
      final c3 = await make();
      await c3.load();
      expect(repo.calls.where((x) => x.startsWith('skills')), isEmpty);
    });

    test('a page that already loaded does not reload without force', () async {
      final c = await make();
      await c.load();
      await c.load();
      expect(repo.calls.where((x) => x.startsWith('profile:')), hasLength(1));
      await c.load(force: true);
      expect(repo.calls.where((x) => x.startsWith('profile:')), hasLength(2));
    });

    test('new entries show at once, newest first, without a duplicate', () async {
      repo.observations = (_) async => [EceObservation.fromJson({'_id': 'o1'})];
      repo.portfolio = (_) async => [];
      final c = await make();
      await c.load();
      c.addObservation(EceObservation.fromJson({'_id': 'o2'}));
      c.addObservation(EceObservation.fromJson({'_id': 'o2'}));
      expect(c.observationsState.value.data!.map((o) => o.id), ['o2', 'o1']);
      c.addPortfolioEntry(EcePortfolioEntry.fromJson({'_id': 'p1'}));
      expect(c.portfolioState.value.status, SectionStatus.data);
    });
  });

  group('a child that is not mine', () {
    test('a child of another class: a plain message, and nothing about the child is requested', () async {
      final c = await make(initial: child(7, grade: 'KG-2', section: 'B'), id: 'c7');
      await c.load();
      expect(c.childState.value.status, SectionStatus.forbidden);
      expect(c.childState.value.forbiddenDetail, contains("isn't one of the children in your classes"));
      for (final s in [c.profileState.value, c.observationsState.value, c.portfolioState.value]) {
        expect(s.status, SectionStatus.forbidden);
      }
      expect(repo.calls.where((x) => x.startsWith('profile') || x.startsWith('observations') || x.startsWith('portfolio')), isEmpty);
    });

    test('opened by id (deep link): found in the roster of my classes, else refused', () async {
      repo.children = () async => [child(1), child(7, grade: 'KG-2', section: 'B')];
      final mine = await make(useInitial: false);
      await mine.load();
      expect(mine.childState.value.status, SectionStatus.data);
      expect(mine.child!.id, 'c1');

      final other = await make(useInitial: false, id: 'c7');
      await other.load();
      expect(other.childState.value.status, SectionStatus.forbidden);

      final missing = await make(useInitial: false, id: 'nope');
      await missing.load();
      expect(missing.childState.value.status, SectionStatus.forbidden);
    });

    test('the list screen\'s already-filtered children are used before any fetch', () async {
      final h = await signedIn();
      h.api.assignments = const [nurseryA];
      await h.auth.refreshProfile(force: true);
      repo.children = () async => [child(1)];
      final list = Get.put(EarlyYearsController(repository: repo, auth: h.auth, permissions: h.perms));
      await list.load();
      repo.calls.clear();
      final c = EarlyYearsChildController(childId: 'c1', repository: repo, auth: h.auth, permissions: h.perms);
      await c.load();
      expect(c.childState.value.status, SectionStatus.data);
      expect(repo.calls.contains('children'), isFalse);
    });

    test('a custom role without early-years:view is forbidden everywhere and nothing is requested', () async {
      final c = await make(permissions: const ['teaching:view']);
      await c.load();
      expect(c.childState.value.status, SectionStatus.forbidden);
      expect(c.profileState.value.status, SectionStatus.forbidden);
      expect(repo.calls, isEmpty);
    });

    test('a roster failure while resolving the child is an error, not a refusal', () async {
      repo.children = () async => throw ApiException('offline', statusCode: null);
      final c = await make(useInitial: false);
      await c.load();
      expect(c.childState.value.status, SectionStatus.error);
    });
  });

  group('photo links', () {
    test('a link is reused until it is old, then asked for again', () async {
      final c = await make();
      final a = await c.photoUrl(photo('a'));
      final b = await c.photoUrl(photo('a'));
      expect(a, b);
      expect(repo.calls.where((x) => x.startsWith('signed:')), hasLength(1));
      clock = clock.add(EarlyYearsChildController.photoLinkTtl + const Duration(seconds: 1));
      await c.photoUrl(photo('a'));
      expect(repo.calls.where((x) => x.startsWith('signed:')), hasLength(2));
    });

    test('two looks at the same photo at once share one request', () async {
      var n = 0;
      repo.onSigned = (k) async {
        n++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'https://signed/$k';
      };
      final c = await make();
      final both = await Future.wait([c.photoUrl(photo('a')), c.photoUrl(photo('a'))]);
      expect(both[0], both[1]);
      expect(n, 1);
    });

    test('a failure is null, is not remembered, and the next look succeeds', () async {
      var fail = true;
      repo.onSigned = (k) async {
        if (fail) throw ApiException('nope', statusCode: 500);
        return 'https://signed/$k';
      };
      final c = await make();
      expect(await c.photoUrl(photo('a')), isNull);
      fail = false;
      expect(await c.photoUrl(photo('a')), 'https://signed/school/ece-evidence/a.jpg');
    });

    test('only keys of our shape are ever sent to the signing route', () async {
      final c = await make();
      expect(await c.photoUrl(const EceEvidence(type: 'photo', url: 'javascript:alert(1)')), isNull);
      expect(await c.photoUrl(const EceEvidence(type: 'photo', url: '')), isNull);
      expect(await c.photoUrl(const EceEvidence(type: 'photo', url: 'a/../../etc/passwd')), isNull);
      expect(repo.calls.where((x) => x.startsWith('signed:')), isEmpty);
    });
  });

  test('the controller only calls the repository methods the page needs: no care, allergy or support source', () {
    final src = File('lib/app/modules/early_years/controllers/early_years_child_controller.dart').readAsStringSync();
    final used = {for (final m in RegExp(r'repo\.(\w+)\(').allMatches(src)) m.group(1)!};
    expect(used, {'fetchChildren', 'fetchProfile', 'fetchDomains', 'fetchProgressionLevels', 'fetchObservations', 'fetchSkills', 'fetchPortfolio', 'signedUrl'});
  });
}
