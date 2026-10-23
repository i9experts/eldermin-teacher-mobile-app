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

EmPhotoCarouselBackdrop carousel(WidgetTester t) => t.widget<EmPhotoCarouselBackdrop>(find.byKey(const Key('intro_scene')));

/// Opacity and horizontal parallax offset of photo [i] while scrubbing.
double photoOpacity(WidgetTester t, int i) => t.widget<Opacity>(find.byKey(ValueKey('scrub_$i'))).opacity;
double photoShift(WidgetTester t, int i) =>
    t.widget<Transform>(find.descendant(of: find.byKey(ValueKey('scrub_$i')), matching: find.byType(Transform)).first).transform.getTranslation().x;

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
    testWidgets('photo crossfade + parallax = the PageController offset (half a swipe = half the transition)', (t) async {
      await pumpIntro(t);
      expect(carousel(t).progress.value, 0);
      expect(photoOpacity(t, 0), 1);
      expect(find.byKey(const ValueKey('scrub_1')), findsNothing, reason: 'the next photo only exists once the swipe starts');

      final g = await t.startGesture(const Offset(200, 300));
      await g.moveBy(const Offset(-195, 0)); // half of the 390 dp page
      await t.pump();
      expect(carousel(t).progress.value, closeTo(0.5, 0.02));
      expect(photoOpacity(t, 0), 1, reason: 'the lower photo stays opaque: no dip to the navy in the middle');
      expect(photoOpacity(t, 1), closeTo(0.5, 0.02));
      expect(photoShift(t, 0), closeTo(-EmMotion.parallaxShift * 0.5, 0.6), reason: 'parallax: the photos trail the finger');
      expect(photoShift(t, 1), closeTo(EmMotion.parallaxShift * 0.5, 0.6));

      await g.moveBy(const Offset(-97.5, 0)); // 3/4
      await t.pump();
      expect(photoOpacity(t, 1), closeTo(0.75, 0.02));

      await g.moveBy(const Offset(97.5, 0)); // back to 1/2: it runs backwards with the finger
      await t.pump();
      expect(photoOpacity(t, 1), closeTo(0.5, 0.02));

      await g.up();
      await t.pumpAndSettle();
      expect(carousel(t).progress.value, anyOf(closeTo(0, 0.001), closeTo(1, 0.001))); // settles on a page
    });

    testWidgets('the three backdrops are the three photos, in order, cover-fit', (t) async {
      await pumpIntro(t);
      final c = carousel(t);
      expect(c.images, hasLength(3));
      expect([for (final i in c.images) (i as AssetImage).assetName], EmAuthPhotos.slides);
      expect(t.widget<Image>(find.descendant(of: find.byKey(const ValueKey('photo_0')), matching: find.byType(Image)).first).fit, BoxFit.cover);
    });

    testWidgets('dots: the active one is an accent pill that follows the offset', (t) async {
      expect(EmPhotoDots.activeness(0, 0), 1);
      expect(EmPhotoDots.activeness(1, 0), 0);
      expect(EmPhotoDots.activeness(0, 0.5), 0.5);
      expect(EmPhotoDots.activeness(1, 0.5), 0.5);
      expect(EmPhotoDots.activeness(2, 0.5), 0);
      await pumpIntro(t);
      final dots = t.widgetList<Container>(find.descendant(of: find.byKey(const Key('intro_indicator')), matching: find.byType(Container))).toList();
      expect(dots, hasLength(3));
      expect((dots.first.decoration! as BoxDecoration).color, EmColors.accent);
      expect(t.getSize(find.byWidget(dots.first)).width, EmPhotoDots.activeWidth);
      expect(t.getSize(find.byWidget(dots.last)).width, EmPhotoDots.dot);
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

    testWidgets('the logo tile on the photo is the splash landing anchor', (t) async {
      await pumpIntro(t);
      final logo = find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark));
      expect(logo, findsOneWidget);
      expect(EmLogoHandoff.hasAnchor, isTrue);
      expect(t.getCenter(logo).dx, closeTo(334, 1)); // top-end corner of the photo (390 - 24 - 64/2)
    });
  });

  group('reduce motion', () {
    testWidgets('no scrub and no parallax: the photos just crossfade when the page settles', (t) async {
      await pumpIntro(t, reduce: true);
      expect(carousel(t).progress, isA<FixedProgress>());
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('scrub_')), findsNothing, reason: 'no parallax layers');
      double fade(int i) => t.widget<AnimatedOpacity>(find.byKey(ValueKey('fade_$i'))).opacity;
      expect([fade(0), fade(1), fade(2)], [1, 0, 0]);
      await t.tap(find.text('Next'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100)); // mid-crossfade
      expect([fade(0), fade(1), fade(2)], [0, 1, 0]);
      expect(t.widget<AnimatedOpacity>(find.byKey(const ValueKey('fade_1'))).duration, EmMotion.crossfade);
      await t.pump(const Duration(milliseconds: 500));
      expect(carousel(t).progress.value, 1);
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
    testWidgets('RTL: the logo tile moves to the left corner and is not mirrored', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!), home: const IntroScreen()));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      expect(t.getCenter(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark))).dx, closeTo(56, 1)); // RTL: the end is the left edge, tile not mirrored
    });
  });
}
