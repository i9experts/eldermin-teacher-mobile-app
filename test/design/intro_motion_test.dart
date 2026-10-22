import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/intro/controllers/intro_controller.dart';
import 'package:eldermin_teacher_app/app/modules/intro/views/intro_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_design_harness.dart';
import '../support/design_harness.dart';

NodeScenePainter scene(WidgetTester t) =>
    t.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is NodeScenePainter)).painter! as NodeScenePainter;

NodeIndicatorPainter indicator(WidgetTester t) =>
    t.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is NodeIndicatorPainter)).painter! as NodeIndicatorPainter;

Future<void> pumpIntro(WidgetTester t, {bool reduce = false, double width = 390, double height = 844, double scale = 1}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.light,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce, textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
    home: const IntroScreen(),
  ));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadDesignFonts);
  late AuthController auth;
  setUp(() => auth = setUpAuthDeps()..introSeen.value = false);
  tearDown(() {
    Get.reset();
    EmLogoHandoff.reset();
  });

  group('scrubbed by the page offset', () {
    testWidgets('scene and indicator progress = the PageController offset (half a swipe = half the transition)', (t) async {
      await pumpIntro(t);
      expect(scene(t).value, 0);
      expect(indicator(t).linkFill(0), 0);

      final g = await t.startGesture(const Offset(200, 600));
      await g.moveBy(const Offset(-195, 0)); // half of the 390 dp page
      await t.pump();
      expect(scene(t).value, closeTo(0.5, 0.02));
      expect(indicator(t).linkFill(0), closeTo(0.5, 0.02));
      expect(indicator(t).nodeFill(1), closeTo(0.5, 0.02), reason: 'the next node fills as the link reaches it');

      await g.moveBy(const Offset(-97.5, 0)); // 3/4
      await t.pump();
      expect(scene(t).value, closeTo(0.75, 0.02));

      await g.moveBy(const Offset(97.5, 0)); // back to 1/2: it runs backwards with the finger
      await t.pump();
      expect(scene(t).value, closeTo(0.5, 0.02));

      await g.up();
      await t.pumpAndSettle();
      expect(scene(t).value, anyOf(closeTo(0, 0.001), closeTo(1, 0.001))); // settles on a page
    });

    testWidgets('every layout is a distinct arrangement of the same nodes (grid -> checks -> bubbles)', (t) async {
      expect(EmScenes.intro, hasLength(3));
      for (final l in EmScenes.intro) {
        expect(l.nodes, hasLength(EmScenes.introRoles.length));
        expect(l.radii, hasLength(EmScenes.introRoles.length));
      }
      expect(EmScenes.checks.nodes, isNot(EmScenes.classGrid.nodes));
      expect(EmScenes.bubbles.nodes, isNot(EmScenes.checks.nodes));
      expect(EmScenes.bubbles.bubbles, hasLength(2)); // teacher + parent
      expect(EmScenes.bubbles.links.where((l) => l.dashed), hasLength(2)); // the message links
    });

    testWidgets('indicator fills link by link', (t) async {
      final p = FixedProgress(1.5);
      final painter = NodeIndicatorPainter(count: 3, progress: p, palette: EmNetworkPalette.standard);
      expect([painter.linkFill(0), painter.linkFill(1)], [1.0, 0.5]);
      expect([painter.nodeFill(0), painter.nodeFill(1), painter.nodeFill(2)], [1.0, 1.0, 0.5]);
    });
  });

  group('actions', () {
    testWidgets('Next advances; the last page says Get started and finishes (flag set, gate moves on)', (t) async {
      await pumpIntro(t);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Stay close to families'), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
      expect(Get.find<IntroController>().isLast, isTrue);
      expect(find.byKey(const Key('intro_skip')), findsOneWidget, reason: 'Skip stays available on the last page');
      await t.tap(find.text('Get started'));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(auth.introSeen.value, isTrue);
    });

    testWidgets('Skip finishes from the first page', (t) async {
      await pumpIntro(t);
      await t.tap(find.byKey(const Key('intro_skip')));
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(auth.introSeen.value, isTrue);
    });

    testWidgets('copy is unchanged', (t) async {
      await pumpIntro(t);
      expect(find.text('Your classroom, in your pocket'), findsOneWidget);
      expect(find.text('Timetable, classes, homework and marks - the tools you use every day, on your phone.'), findsOneWidget);
    });

    testWidgets('the header logo is the splash landing anchor', (t) async {
      await pumpIntro(t);
      final logo = find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark));
      expect(logo, findsOneWidget);
      expect(EmLogoHandoff.hasAnchor, isTrue);
      expect(t.getCenter(logo).dx, closeTo(195, 1)); // centred in the header
    });
  });

  group('reduce motion', () {
    testWidgets('no scrub: the scene is a static layout that crossfades per page', (t) async {
      await pumpIntro(t, reduce: true);
      expect(scene(t).progress, isA<FixedProgress>());
      expect(scene(t).value, 0);
      await t.tap(find.text('Next'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100)); // mid-crossfade: both scenes in the tree
      expect(find.byType(AnimatedSwitcher), findsWidgets);
      await t.pump(const Duration(milliseconds: 500));
      expect(scene(t).value, 1);
      expect(indicator(t).progress, isA<FixedProgress>());
      expect(indicator(t).linkFill(0), 1);
    });
  });

  group('layout', () {
    for (final (w, h, s) in [(320.0, 568.0, 1.0), (320.0, 568.0, 1.3), (360.0, 800.0, 1.3), (430.0, 932.0, 1.0)]) {
      testWidgets('${w.toInt()}x${h.toInt()} text $s: no overflow, button and indicator visible', (t) async {
        await pumpIntro(t, width: w, height: h, scale: s);
        expect(t.takeException(), isNull);
        expect(t.getRect(find.byType(EmPrimaryButton).first).bottom, lessThanOrEqualTo(h));
        expect(find.byKey(const Key('intro_indicator')), findsOneWidget);
      });
    }
    testWidgets('RTL: the logo is not mirrored (same SVG, centred)', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!), home: const IntroScreen()));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      expect(t.getCenter(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark))).dx, closeTo(195, 1));
    });
  });
}
