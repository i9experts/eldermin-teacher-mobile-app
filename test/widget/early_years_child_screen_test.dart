// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_child_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/early_years_child_screen.dart';
import 'package:eldermin_teacher_app/core/models/early_years/ece_models.dart';
import 'package:eldermin_teacher_app/core/design/design.dart' show EmLoading;
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:eldermin_teacher_app/app/components/external_link.dart';
import 'package:eldermin_teacher_app/core/widgets/image_viewer.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show SynchronousFuture;
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

    testWidgets('observations tab: rows tell shared and private apart; the sheet shows skill name + level, next step and observer', (t) async {
      repo.observations = (_) async => [obs('o1', narrative: 'Shared story', shared: true), obs('o2', narrative: 'Private note', type: 'spontaneous')];
      await boot(t);
      await t.tap(find.text('Observations'));
      await settle(t);
      expect(find.text('Shared story'), findsOneWidget);
      expect(find.text('Private note'), findsOneWidget);
      expect(find.text('Shared with family'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Learning story'), findsOneWidget);
      expect(find.byKey(const Key('ey_obs_note')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('ey_obs_o1')));
      await settle(t);
      expect(find.byKey(const Key('detail_sheet')), findsOneWidget);
      expect(find.byKey(const Key('detail_long_text')), findsOneWidget);
      expect(find.text('Pencil Control · Emerging'), findsOneWidget);
      expect(find.text('Count the blocks'), findsOneWidget);
      expect(find.text('Ms Sara'), findsOneWidget);
    });

    testWidgets('portfolio tab: private marker; the sheet carries the try-this-at-home idea', (t) async {
      repo.portfolio = (_) async => [entry('p1', shared: true, tryHome: 'Paint with water'), entry('p2', title: 'Sand play')];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      expect(find.text('Painting'), findsOneWidget);
      expect(find.text('Sand play'), findsOneWidget);
      expect(find.text('Shared with family'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('ey_entry_p1')));
      await settle(t);
      expect(find.text('Try this at home'), findsOneWidget);
      expect(find.text('Paint with water'), findsOneWidget);
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
    testWidgets('nothing is fetched until a sheet opens; then one signed link per photo, shown as an attachment with its caption', (t) async {
      repo.portfolio = (_) async => [entry('p1', evidence: const [photoEv])];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      expect(repo.calls.where((x) => x.startsWith('signed:')), isEmpty);
      await t.tap(find.byKey(const ValueKey('ey_entry_p1')));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(repo.calls.where((x) => x.startsWith('signed:')), ['signed:school/ece-evidence/a.jpg']);
      expect(find.text('Our painting'), findsOneWidget);
      expect(find.textContaining('could not be opened'), findsNothing);
    });

    testWidgets('while the link is being fetched the sheet shows its loading state', (t) async {
      final gate = Completer<String>();
      repo.onSigned = (_) => gate.future;
      repo.portfolio = (_) async => [entry('p1', evidence: const [photoEv])];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('ey_entry_p1')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(EmLoading), findsOneWidget);
      expect(find.byKey(const Key('detail_sheet')), findsOneWidget);
      gate.complete('https://signed.example/a.jpg');
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.text('Our painting'), findsOneWidget);
    });

    testWidgets('a photo whose link cannot be had is reported in the sheet and the page still works', (t) async {
      repo.onSigned = (_) async => throw ApiException('storage', statusCode: 503);
      repo.portfolio = (_) async => [entry('p1', evidence: const [photoEv])];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('ey_entry_p1')));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await settle(t);
      expect(find.textContaining('1 photo could not be opened'), findsOneWidget);
      expect(find.text('Painting'), findsWidgets);
    });

    group('in-app viewer', () {
      final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
      late List<String> requested;
      late List<Uri> launched;
      late bool failImages;
      late ImageProvider Function(String) oldProvider;
      late Future<bool> Function(Uri) oldLauncher;

      setUp(() {
        requested = [];
        launched = [];
        failImages = false;
        oldProvider = ImageViewer.providerFor;
        oldLauncher = ExternalLinks.launcher;
        ExternalLinks.launcher = (u) async {
          launched.add(u);
          return true;
        };
        ImageViewer.providerFor = (u) {
          requested.add(u);
          return failImages ? _FailingImage(u) : MemoryImage(png) as ImageProvider;
        };
      });
      tearDown(() {
        ImageViewer.providerFor = oldProvider;
        ExternalLinks.launcher = oldLauncher;
      });

      Future<void> openPhotoSheet(WidgetTester t) async {
        repo.portfolio = (_) async => [entry('p1', evidence: const [photoEv])];
        await boot(t);
        await t.tap(find.text('Portfolio'));
        await settle(t);
        await t.tap(find.byKey(const ValueKey('ey_entry_p1')));
        await t.pump();
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await settle(t);
      }

      const rowKey = ValueKey('detail_attachment_https://signed.example/school/ece-evidence/a.jpg?sig=1');

      testWidgets('tapping a photo opens the in-app viewer with the signed link; no browser, no confirm dialog', (t) async {
        await openPhotoSheet(t);
        await t.tap(find.byKey(rowKey));
        await t.pump();
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('image_viewer')), findsOneWidget);
        expect(requested, ['https://signed.example/school/ece-evidence/a.jpg?sig=1']);
        expect(find.bySemanticsLabel('Our painting'), findsOneWidget);
        expect(find.text('Open this link?'), findsNothing);
        expect(launched, isEmpty);
      });

      testWidgets('after the link expires, Try again fetches a fresh signed link (not the remembered one)', (t) async {
        await openPhotoSheet(t);
        failImages = true;
        var n = 0;
        repo.onSigned = (k) async => 'https://signed.example/$k?sig=${++n + 1}';
        await t.tap(find.byKey(rowKey));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('image_viewer_error')), findsOneWidget);
        expect(repo.calls.where((x) => x.startsWith('signed:')).length, 1);
        await t.tap(find.text('Try again'));
        await t.pumpAndSettle();
        expect(repo.calls.where((x) => x.startsWith('signed:')).length, 2);
        expect(requested.last, 'https://signed.example/school/ece-evidence/a.jpg?sig=2');
        expect(launched, isEmpty);
      });
    });

    testWidgets('video and voice evidence are only counted, never played or fetched', (t) async {
      repo.portfolio = (_) async => [
            entry('p1', evidence: const [
              {'type': 'video', 'url': 'https://b/x/ece-evidence/v.mp4'},
              {'type': 'voice_note', 'url': 'https://b/x/ece-evidence/v.m4a'},
            ])
          ];
      await boot(t);
      await t.tap(find.text('Portfolio'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('ey_entry_p1')));
      await settle(t);
      expect(find.textContaining('2 files attached (not shown in the app yet)'), findsOneWidget);
      expect(repo.calls.where((x) => x.startsWith('signed:')), isEmpty);
    });
  });

  group('create actions need early-years:manage', () {
    testWidgets('with manage: the Add button opens the three create choices', (t) async {
      await boot(t);
      expect(find.byKey(const Key('ey_add_fab')), findsOneWidget);
      await t.tap(find.byKey(const Key('ey_add_fab')));
      await settle(t);
      expect(find.byKey(const Key('ey_add_quick')), findsOneWidget);
      expect(find.byKey(const Key('ey_add_observe')), findsOneWidget);
      expect(find.byKey(const Key('ey_add_portfolio')), findsOneWidget);
    });

    testWidgets('view only: the child page opens but no create button exists', (t) async {
      await boot(t, permissions: const ['early-years:view']);
      expect(find.byKey(const Key('ey_child_header')), findsOneWidget);
      expect(find.byKey(const Key('ey_add_fab')), findsNothing);
    });
  });

  for (final w in [320.0, 430.0]) {
    testWidgets('lays out at ${w.toInt()} dp with large text, all tabs, LTR and RTL', (t) async {
      repo.observations = (_) async => [obs('o1', narrative: 'A very long observation narrative ' * 6, shared: true)];
      repo.portfolio = (_) async => [entry('p1', title: 'A very long portfolio title that has to wrap nicely', shared: true, tryHome: 'Try this at home ' * 5)];
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

class _FailingImage extends ImageProvider<_FailingImage> {
  _FailingImage(this.url);
  final String url;
  @override
  Future<_FailingImage> obtainKey(ImageConfiguration c) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_FailingImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Future<ImageInfo>.error(Exception('expired')));
  @override
  bool operator ==(Object o) => o is _FailingImage && o.url == url;
  @override
  int get hashCode => url.hashCode;
}
