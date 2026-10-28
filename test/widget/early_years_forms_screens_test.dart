// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_child_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/observation_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/portfolio_form_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/quick_observe_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/early_years_child_screen.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/observation_form_screen.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/portfolio_form_screen.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/quick_observe_screen.dart';
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

void main() {
  late FakeEarlyYearsRepository repo;
  late FakePhotoPicker picker;

  setUpAll(loadDesignFonts);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeEarlyYearsRepository();
    picker = FakePhotoPicker();
    repo.domains = () async => const [EceDomain(id: 'd1', name: 'Physical', order: 1)];
    repo.skills = (_) async => const [EceSkill(id: 's1', domainId: 'd1', name: 'Pencil Control')];
  });
  tearDown(Get.reset);
  tearDown(ProbeEnv.reset);

  Future<dynamic> signIn(WidgetTester t, {List<String>? permissions}) async => (await t.runAsync(() async {
        final h = await signedIn(permissions: permissions);
        h.api.assignments = const [nurseryA];
        await h.auth.refreshProfile(force: true);
        return h;
      }))!;

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 3000)}) async {
    await t.binding.setSurfaceSize(probeSize(size));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => probeHome(screen)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<QuickObserveController> bootQuick(WidgetTester t, {List<String>? permissions, EceChild? kid, Size size = const Size(430, 3000)}) async {
    final h = await signIn(t, permissions: permissions);
    final k = kid ?? child(1);
    final c = Get.put(QuickObserveController(childId: k.id, initial: k, repository: repo, auth: h.auth, permissions: h.perms));
    await open(t, const QuickObserveScreen(), size: size);
    await t.runAsync(c.loadRefs);
    await settle(t);
    return c;
  }

  Future<ObservationFormController> bootObs(WidgetTester t, {List<String>? permissions, Size size = const Size(430, 3000)}) async {
    final h = await signIn(t, permissions: permissions);
    final c = Get.put(ObservationFormController(childId: 'c1', initial: child(1), repository: repo, auth: h.auth, permissions: h.perms, picker: picker));
    await open(t, const ObservationFormScreen(), size: size);
    await t.runAsync(c.loadRefs);
    await settle(t);
    return c;
  }

  Future<PortfolioFormController> bootPortfolio(WidgetTester t, {List<String>? permissions, Size size = const Size(430, 3000)}) async {
    final h = await signIn(t, permissions: permissions);
    final c = Get.put(PortfolioFormController(childId: 'c1', initial: child(1), repository: repo, auth: h.auth, permissions: h.perms, picker: picker));
    await open(t, const PortfolioFormScreen(), size: size);
    await settle(t);
    return c;
  }

  Future<void> tapSave(WidgetTester t, Key key) async {
    await t.ensureVisible(find.byKey(key));
    await t.tap(find.byKey(key));
    await settle(t);
    await t.pump(const Duration(seconds: 3)); // the saved toast's timer
  }

  group('Quick observation', () {
    testWidgets('area -> skill -> level -> save sends exactly the quick body and closes the screen', (t) async {
      await bootQuick(t);
      expect(find.text('Child1 Khan'), findsOneWidget);
      await t.tap(find.byKey(const Key('ey_dom_d1')));
      await settle(t);
      await t.tap(find.byKey(const Key('ey_skill_s1')));
      await t.tap(find.byKey(const Key('ey_lvl_Emerging')));
      await settle(t);
      await t.enterText(find.byKey(const Key('ey_quick_note')), 'Held it well');
      await tapSave(t, const Key('ey_quick_submit'));
      expect(repo.bodies.single, {'studentId': 'c1', 'skillId': 's1', 'progressionLevel': 'Emerging', 'narrative': 'Held it well'});
      expect(find.byKey(const Key('ey_quick_submit')), findsNothing);
    });

    testWidgets('saving with nothing chosen says what is missing and sends nothing', (t) async {
      await bootQuick(t);
      await tapSave(t, const Key('ey_quick_submit'));
      expect(find.text('Choose a skill'), findsWidgets);
      expect(repo.bodies, isEmpty);
    });

    testWidgets('a server failure shows a banner and keeps what was chosen', (t) async {
      repo.onQuick = (b) async => throw ApiException('The server had a problem', statusCode: 500);
      await bootQuick(t);
      await t.tap(find.byKey(const Key('ey_dom_d1')));
      await settle(t);
      await t.tap(find.byKey(const Key('ey_skill_s1')));
      await t.tap(find.byKey(const Key('ey_lvl_Emerging')));
      await tapSave(t, const Key('ey_quick_submit'));
      expect(find.byKey(const Key('ey_submit_error')), findsOneWidget);
      expect(find.byKey(const Key('ey_quick_submit')), findsOneWidget);
    });

    testWidgets('without early-years:manage the form is blocked', (t) async {
      await bootQuick(t, permissions: const ['early-years:view']);
      expect(find.byKey(const Key('ey_blocked')), findsOneWidget);
      expect(find.byKey(const Key('ey_quick_submit')), findsNothing);
    });

    testWidgets('a child outside my classes is blocked and nothing is loaded', (t) async {
      await bootQuick(t, kid: child(7, grade: 'KG-2', section: 'B'));
      expect(find.byKey(const Key('ey_blocked')), findsOneWidget);
      expect(repo.calls.where((x) => x.startsWith('domains') || x.startsWith('skills')), isEmpty);
    });

    testWidgets('no skills set up: honest empty state', (t) async {
      repo.skills = (_) async => const [];
      await bootQuick(t);
      expect(find.text('No skills are set up yet'), findsOneWidget);
    });
  });

  group('Observation form', () {
    testWidgets('private by default: save goes straight through, isSharedWithFamily false, no dialog', (t) async {
      await bootObs(t);
      expect(find.text('Off: only staff can see it.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('ey_obs_narrative')), 'Built a tower');
      await tapSave(t, const Key('ey_obs_submit'));
      expect(find.text('Share with the family?'), findsNothing);
      expect(repo.bodies.single['isSharedWithFamily'], isFalse);
    });

    testWidgets('share ON: a confirm first. "Go back" sends nothing; "Share and save" sends isSharedWithFamily true', (t) async {
      await bootObs(t);
      await t.enterText(find.byKey(const Key('ey_obs_narrative')), 'Built a tower');
      await t.ensureVisible(find.byKey(const Key('ey_share_switch')));
      await t.tap(find.byKey(const Key('ey_share_switch')));
      await settle(t);
      expect(find.text('Parents will see this observation in their app.'), findsOneWidget);
      await tapSave(t, const Key('ey_obs_submit'));
      expect(find.text('Share with the family?'), findsOneWidget);
      expect(find.textContaining('Parents will be able to see this observation'), findsOneWidget);
      await t.tap(find.text('Go back'));
      await settle(t);
      expect(repo.bodies, isEmpty);
      await tapSave(t, const Key('ey_obs_submit'));
      await t.tap(find.text('Share and save'));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.bodies.single['isSharedWithFamily'], isTrue);
    });

    testWidgets('a missing narrative is flagged and the confirm is not shown for an invalid form', (t) async {
      await bootObs(t);
      await t.ensureVisible(find.byKey(const Key('ey_share_switch')));
      await t.tap(find.byKey(const Key('ey_share_switch')));
      await tapSave(t, const Key('ey_obs_submit'));
      expect(find.text('Share with the family?'), findsNothing);
      expect(find.text('Describe what you observed'), findsWidgets);
    });

    testWidgets('photos: thumbnails with their state; a failed one offers Retry and Remove; saving is refused until fixed', (t) async {
      var fail = true;
      repo.onUpload = (p, n) async {
        if (fail) throw ApiException('The server had a problem', statusCode: 500);
        return EceUploaded(url: 'https://b/s/ece-evidence/$n', key: 's/ece-evidence/$n');
      };
      picker.next = [pickedPhoto('a.jpg')];
      final c = await bootObs(t);
      await t.enterText(find.byKey(const Key('ey_obs_narrative')), 'n');
      await t.ensureVisible(find.byKey(const Key('ey_add_photos')));
      await t.tap(find.byKey(const Key('ey_add_photos')));
      await settle(t);
      expect(find.byKey(const Key('ey_photo_ph1')), findsOneWidget);
      expect(find.byKey(const Key('ey_photo_retry_ph1')), findsOneWidget);
      await tapSave(t, const Key('ey_obs_submit'));
      expect(find.text('Retry or remove the photo that failed'), findsWidgets);
      expect(repo.bodies, isEmpty);
      fail = false;
      await t.tap(find.byKey(const Key('ey_photo_retry_ph1')));
      await settle(t);
      expect(find.byKey(const Key('ey_photo_retry_ph1')), findsNothing);
      await tapSave(t, const Key('ey_obs_submit'));
      expect(repo.bodies.single['evidence'], hasLength(1));
      expect(c.photos.evidence, hasLength(1));
    });

    testWidgets('storage not configured: a clear banner, and saving without photos still works', (t) async {
      repo.onUpload = (p, n) async => throw ApiException('File uploads are not available on this server (storage is not configured).', statusCode: 503);
      picker.next = [pickedPhoto('a.jpg')];
      await bootObs(t);
      await t.enterText(find.byKey(const Key('ey_obs_narrative')), 'n');
      await t.ensureVisible(find.byKey(const Key('ey_add_photos')));
      await t.tap(find.byKey(const Key('ey_add_photos')));
      await settle(t);
      expect(find.byKey(const Key('ey_upload_unavailable')), findsOneWidget);
      await t.tap(find.byKey(const Key('ey_photo_remove_ph1')));
      await settle(t);
      expect(find.byKey(const Key('ey_upload_unavailable')), findsNothing);
      await tapSave(t, const Key('ey_obs_submit'));
      expect(repo.bodies, hasLength(1));
    });

    testWidgets('leaving with text asks first; Discard leaves, Cancel stays', (t) async {
      await bootObs(t);
      await t.enterText(find.byKey(const Key('ey_obs_narrative')), 'unsaved');
      await t.pump();
      unawaited(Navigator.of(t.element(find.byKey(const Key('ey_obs_submit')))).maybePop());
      await settle(t);
      expect(find.text('Discard this observation?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byKey(const Key('ey_obs_submit')), findsOneWidget);
    });

    testWidgets('blocked without manage', (t) async {
      await bootObs(t, permissions: const ['early-years:view']);
      expect(find.byKey(const Key('ey_blocked')), findsOneWidget);
    });
  });

  group('Portfolio form', () {
    testWidgets('private by default: saves without a dialog; try-this-at-home goes along', (t) async {
      await bootPortfolio(t);
      await t.enterText(find.byKey(const Key('ey_pf_title')), 'Painting');
      await t.enterText(find.byKey(const Key('ey_pf_narrative')), 'Mixed colours');
      await t.enterText(find.byKey(const Key('ey_pf_tryhome')), 'Paint with water');
      await tapSave(t, const Key('ey_pf_submit'));
      expect(find.text('Share with the family?'), findsNothing);
      expect(repo.bodies.single, {'studentId': 'c1', 'title': 'Painting', 'narrative': 'Mixed colours', 'tryThisAtHome': 'Paint with water', 'isVisibleToFamily': false});
    });

    testWidgets('share ON: the confirm says the guardian will be emailed; only "Share and save" shares', (t) async {
      await bootPortfolio(t);
      await t.enterText(find.byKey(const Key('ey_pf_title')), 'Painting');
      await t.enterText(find.byKey(const Key('ey_pf_narrative')), 'Mixed colours');
      await t.ensureVisible(find.byKey(const Key('ey_share_switch')));
      await t.tap(find.byKey(const Key('ey_share_switch')));
      await settle(t);
      expect(find.textContaining('guardian will be emailed'), findsOneWidget);
      await tapSave(t, const Key('ey_pf_submit'));
      expect(find.text('Share with the family?'), findsOneWidget);
      expect(find.textContaining("child's guardian will be emailed"), findsOneWidget);
      await t.tap(find.text('Go back'));
      await settle(t);
      expect(repo.bodies, isEmpty);
      await tapSave(t, const Key('ey_pf_submit'));
      await t.tap(find.text('Share and save'));
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(repo.bodies.single['isVisibleToFamily'], isTrue);
    });

    testWidgets('title and text are required', (t) async {
      await bootPortfolio(t);
      await tapSave(t, const Key('ey_pf_submit'));
      expect(find.text('Enter a title'), findsWidgets);
      expect(repo.bodies, isEmpty);
    });
  });

  group('Add sheet on the child page', () {
    Future<void> bootChild(WidgetTester t, {List<String>? permissions}) async {
      final h = await signIn(t, permissions: permissions);
      final c = Get.put(EarlyYearsChildController(childId: 'c1', initial: child(1), repository: repo, auth: h.auth, permissions: h.perms));
      await open(t, const EarlyYearsChildScreen());
      await c.load();
      await settle(t);
    }

    testWidgets('with manage: an Add button opens the three choices', (t) async {
      await bootChild(t);
      await t.tap(find.byKey(const Key('ey_add_fab')));
      await settle(t);
      expect(find.byKey(const Key('ey_add_quick')), findsOneWidget);
      expect(find.byKey(const Key('ey_add_observe')), findsOneWidget);
      expect(find.byKey(const Key('ey_add_portfolio')), findsOneWidget);
    });

    testWidgets('view-only: no Add button at all', (t) async {
      await bootChild(t, permissions: const ['early-years:view']);
      expect(find.byKey(const Key('ey_add_fab')), findsNothing);
    });
  });

  for (final w in [320.0, 430.0]) {
    testWidgets('forms lay out at ${w.toInt()} dp with large text, LTR and RTL', (t) async {
      picker.next = [pickedPhoto('a.jpg'), pickedPhoto('b.jpg')];
      final h = await signIn(t);
      final q = Get.put(QuickObserveController(childId: 'c1', initial: child(1), repository: repo, auth: h.auth, permissions: h.perms));
      final o = Get.put(ObservationFormController(childId: 'c1', initial: child(1), repository: repo, auth: h.auth, permissions: h.perms, picker: picker));
      final p = Get.put(PortfolioFormController(childId: 'c1', initial: child(1), repository: repo, auth: h.auth, permissions: h.perms, picker: picker));
      await t.binding.setSurfaceSize(Size(w, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.runAsync(() async {
        await q.loadRefs();
        await o.loadRefs();
        await o.photos.pick();
      });
      q.setDomain('d1');
      o.setDomain('d1');
      o.setShare(true);
      p.setShare(true);
      for (final dir in probeDirs) {
        for (final screen in const [QuickObserveScreen(), ObservationFormScreen(), PortfolioFormScreen()]) {
          await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: probeWrap(screen, scale: 1.3, dir: dir)));
          await settle(t);
          expectNoLayoutError(t);
        }
      }
    });
  }
}
