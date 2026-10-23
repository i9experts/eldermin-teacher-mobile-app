// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_child_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/early_years_child_screen.dart';
import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/fake_early_years_repository.dart';
import '../support/layout_probe.dart';

const nurseryA = {'gradeLevel': 'Nursery', 'sectionName': 'A', 'subjectName': 'All'};
final fixedNow = DateTime(2026, 10, 5, 9);

EceObservation obs(String id, {String narrative = 'Built a tower', bool shared = false, List<Map<String, Object?>> evidence = const [], String type = 'learning_story'}) =>
    EceObservation.fromJson({
      '_id': id,
      'observationType': type,
      'narrative': narrative,
      'nextStep': 'Count the blocks',
      'observedBy': 'Ms Sara',
      'skillMappings': [{'skillId': 's1', 'progressionLevel': 'Emerging'}],
      'evidence': evidence,
      'isSharedWithFamily': shared,
      'createdAt': '2026-10-02T08:00:00.000Z',
    });

EcePortfolioEntry entry(String id, {String title = 'Painting', bool shared = false, String tryHome = '', List<Map<String, Object?>> evidence = const []}) =>
    EcePortfolioEntry.fromJson({
      '_id': id,
      'title': title,
      'narrative': 'Mixed two colours',
      'tryThisAtHome': tryHome,
      'isVisibleToFamily': shared,
      'evidence': evidence,
      'createdAt': '2026-10-03T08:00:00.000Z',
    });

const photoEv = {'type': 'photo', 'url': 'https://b.s3.x.amazonaws.com/school/ece-evidence/a.jpg', 'caption': 'Our painting'};

void main() {
  late FakeEarlyYearsRepository repo;

  setUpAll(loadDesignFonts);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeEarlyYearsRepository();
    repo.domains = () async => const [EceDomain(id: 'd1', name: 'Physical', order: 1)];
    repo.skills = (_) async => const [EceSkill(id: 's1', domainId: 'd1', name: 'Pencil Control')];
    repo.profile = (_) async => EceProfile.fromJson({
          'domainSummaries': [{'domainId': 'd1', 'currentLevel': 'Developing', 'evidenceCount': 3, 'lastObservedAt': '2026-10-01T09:00:00.000Z'}],
          'interests': ['Animals'],
          'schemas': ['Rotation'],
        });
  });
  tearDown(Get.reset);
  tearDown(ProbeEnv.reset);

  Future<EarlyYearsChildController> boot(WidgetTester t, {EceChild? initial, List<String>? permissions, Size size = const Size(430, 3000)}) async {
    final h = (await t.runAsync(() async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = const [nurseryA];
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    final c = Get.put(EarlyYearsChildController(childId: (initial ?? child(1)).id, initial: initial ?? child(1), repository: repo, auth: h.auth, permissions: h.perms, now: () => fixedNow));
    await t.binding.setSurfaceSize(probeSize(size));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => probeHome(const EarlyYearsChildScreen())));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await c.load();
    await settle(t);
    return c;
  }

  group('child page', () {
    testWidgets('header: name, class, age and the school id', (t) async {
      await boot(t);
      expect(find.byKey(const Key('ey_child_header')), findsOneWidget);
      expect(find.text('Child1 Khan'), findsOneWidget);
      expect(find.text('Nursery - A · 4 years 7 months'), findsOneWidget);
      expect(find.text('ST-1'), findsOneWidget);
    });

    testWidgets('progress tab: domain name, level, evidence count; interests and play patterns', (t) async {
      await boot(t);
      expect(find.text('Physical'), findsOneWidget);
      expect(find.text('Developing'), findsOneWidget);
      expect(find.textContaining('3 observations'), findsOneWidget);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Rotation'), findsOneWidget);
    });

    testWidgets('a never-observed child shows the honest empty progress', (t) async {
      repo.profile = (_) async => const EceProfile();
      await boot(t);
      expect(find.text('No progress recorded yet'), findsOneWidget);
    });

    testWidgets('observations tab: shared and private entries are told apart; skill name + level; next step', (t) async {
      repo.observations = (_) async => [obs('o1', narrative: 'Shared story', shared: true), obs('o2', narrative: 'Private note', type: 'spontaneous')];
      await boot(t);
      await t.tap(find.text('Observations'));
      await settle(t);
      expect(find.text('Shared story'), findsOneWidget);
      expect(find.text('Private note'), findsOneWidget);
      expect(find.text('SHARED WITH FAMILY'), findsOneWidget);
      expect(find.text('PRIVATE'), findsOneWidget);
      expect(find.text('LEARNING STORY'), findsOneWidget);
      expect(find.text('Pencil Control · Emerging'), findsNWidgets(2));
      expect(find.text('Next step: Count the blocks'), findsNWidgets(2));
      expect(find.byKey(const Key('ey_obs_note')), findsOneWidget);
    });

    testWidgets('portfolio tab: private by default marker, try-this-at-home callout', (t) async {
      repo.portfolio = (_) async => [entry('p1', shared: true, tryHome: 'Paint with water'), entry('p2', title: 'Sand play')];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      expect(find.text('Painting'), findsOneWidget);
      expect(find.text('Sand play'), findsOneWidget);
      expect(find.text('SHARED WITH FAMILY'), findsOneWidget);
      expect(find.text('PRIVATE'), findsOneWidget);
      expect(find.byKey(const Key('ey_try_home')), findsOneWidget);
      expect(find.textContaining('Paint with water'), findsOneWidget);
    });

    testWidgets('empty observations and portfolio say so', (t) async {
      await boot(t);
      await t.tap(find.text('Observations'));
      await settle(t);
      expect(find.text('No observations yet'), findsOneWidget);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      expect(find.text('No portfolio entries yet'), findsOneWidget);
    });

    testWidgets('one failing section shows its own error + Retry; the others are untouched', (t) async {
      var fail = true;
      repo.observations = (_) async {
        if (fail) throw ApiException('boom', statusCode: 500);
        return [obs('o1')];
      };
      await boot(t);
      expect(find.text('Physical'), findsOneWidget); // progress fine
      await t.tap(find.text('Observations'));
      await settle(t);
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Built a tower'), findsOneWidget);
    });

    testWidgets('a child outside my classes: the plain message, no data', (t) async {
      await boot(t, initial: child(7, grade: 'KG-2', section: 'B'));
      expect(find.text("This child isn't one of the children in your classes."), findsOneWidget);
      expect(find.byKey(const Key('ey_child_header')), findsNothing);
      expect(repo.calls.where((x) => x.startsWith('profile') || x.startsWith('observations') || x.startsWith('portfolio')), isEmpty);
    });

    testWidgets('no early-years:view: no access, nothing requested', (t) async {
      await boot(t, permissions: const ['teaching:view']);
      expect(find.text("You don't have access"), findsOneWidget);
      expect(repo.calls, isEmpty);
    });
  });

  group('photos', () {
    testWidgets('a photo gets one signed link and shows as a tappable thumbnail with its caption in the viewer', (t) async {
      repo.portfolio = (_) async => [entry('p1', evidence: const [photoEv])];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(repo.calls.where((x) => x.startsWith('signed:')), ['signed:school/ece-evidence/a.jpg']);
      expect(find.byKey(const Key('ey_photo')), findsOneWidget);
      await t.tap(find.byKey(const Key('ey_photo')));
      await settle(t);
      expect(find.text('Our painting'), findsOneWidget);
      await t.tap(find.byKey(const Key('ey_photo_close')));
      await settle(t);
      expect(find.text('Our painting'), findsNothing);
    });

    testWidgets('a photo whose link cannot be had says "Photo unavailable" and the page still works', (t) async {
      repo.onSigned = (_) async => throw ApiException('storage', statusCode: 503);
      repo.portfolio = (_) async => [entry('p1', evidence: const [photoEv])];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.text('Photo unavailable'), findsOneWidget);
      expect(find.text('Painting'), findsOneWidget);
    });

    testWidgets('video and voice evidence are listed by name, never played or fetched', (t) async {
      repo.portfolio = (_) async => [
            entry('p1', evidence: const [
              {'type': 'video', 'url': 'https://b/x/ece-evidence/v.mp4'},
              {'type': 'voice_note', 'url': 'https://b/x/ece-evidence/v.m4a'},
            ])
          ];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      expect(find.textContaining('Video attached'), findsOneWidget);
      expect(find.textContaining('Voice note attached'), findsOneWidget);
      expect(repo.calls.where((x) => x.startsWith('signed:')), isEmpty);
    });
  });

  for (final w in [320.0, 430.0]) {
    testWidgets('lays out at ${w.toInt()} dp with large text, all tabs, LTR and RTL', (t) async {
      repo.observations = (_) async => [obs('o1', narrative: 'A very long observation narrative ' * 6, shared: true)];
      repo.portfolio = (_) async => [entry('p1', title: 'A very long portfolio title that has to wrap nicely', shared: true, tryHome: 'Try this at home ' * 5, evidence: const [photoEv])];
      final c = await boot(t, size: Size(w, 3000));
      for (final dir in probeDirs) {
        for (final tab in EyTab.values) {
          c.setTab(tab);
          await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: probeWrap(const EarlyYearsChildScreen(), scale: 1.3, dir: dir)));
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await settle(t);
          expectNoLayoutError(t);
        }
      }
    });
  }
}

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}
