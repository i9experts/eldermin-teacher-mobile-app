import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/splash/views/splash_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import '../support/design_harness.dart';

Future<void> pumpSplash(WidgetTester t, {bool reduce = false}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(EmLogoHandoff.reset);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: c!),
    home: const SplashScreen(),
  ));
}

double photoOpacity(WidgetTester t) =>
    t.widget<FadeTransition>(find.ancestor(of: find.byType(EmPhotoBackdrop), matching: find.byType(FadeTransition)).first).opacity.value;
double tileOpacity(WidgetTester t) =>
    t.widget<FadeTransition>(find.ancestor(of: find.byType(EmLogoTile), matching: find.byType(FadeTransition)).first).opacity.value;

void main() {
  setUpAll(loadDesignFonts);
  final originalPrecache = EmAuthPhotos.precacheImpl;
  tearDown(() => EmAuthPhotos.precacheImpl = originalPrecache);

  group('assets', () {
    test('the three photos exist, are registered in pubspec.yaml, and are WebP under 600 KB', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/images/auth/'));
      for (final a in EmAuthPhotos.slides) {
        final f = File(a);
        expect(f.existsSync(), isTrue, reason: a);
        expect(f.lengthSync(), lessThan(600 * 1024), reason: a);
        final head = f.readAsBytesSync().sublist(0, 12);
        expect(String.fromCharCodes(head.sublist(0, 4)), 'RIFF', reason: a);
        expect(String.fromCharCodes(head.sublist(8, 12)), 'WEBP', reason: a);
      }
      expect(EmAuthPhotos.slides, ['assets/images/auth/teacher_1.webp', 'assets/images/auth/teacher_2.webp', 'assets/images/auth/teacher_3.webp']);
    });

    testWidgets('they are in the asset bundle (the manifest lists them)', (t) async {
      for (final a in EmAuthPhotos.slides) {
        final data = await t.runAsync(() => rootBundle.load(a));
        expect(data!.lengthInBytes, greaterThan(50 * 1024), reason: a);
      }
    });
  });

  group('precache during init', () {
    testWidgets('the splash precaches all three photos, the splash one first', (t) async {
      final seen = <String>[];
      EmAuthPhotos.precacheImpl = (context, p) async => seen.add((p as AssetImage).assetName);
      await pumpSplash(t);
      await t.pump(const Duration(milliseconds: 50));
      expect(seen.toSet(), EmAuthPhotos.slides.toSet(), reason: 'every photo is decoded before it is needed');
      expect(seen.first, EmAuthPhotos.photo1);
    });

    testWidgets('the photo fades in as soon as it is decoded (seamless hand-off, no pop-in)', (t) async {
      final gate = Completer<void>();
      EmAuthPhotos.precacheImpl = (context, p) => (p as AssetImage).assetName == EmAuthPhotos.photo1 ? gate.future : Future<void>.value();
      await pumpSplash(t);
      await t.pump(const Duration(milliseconds: 200));
      expect(photoOpacity(t), 0, reason: 'frame 0 stays the native splash (navy + logo) until the photo is decoded');
      expect(tileOpacity(t), 0);
      gate.complete();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(photoOpacity(t), inExclusiveRange(0.2, 1), reason: 'crossfading in behind the logo');
      expect(tileOpacity(t), inExclusiveRange(0, 1));
      await t.pump(EmMotion.photoReveal);
      expect(photoOpacity(t), 1);
      expect(tileOpacity(t), 1);
    });

    testWidgets('a photo that never decodes does not hold the splash: it reveals anyway after 400 ms', (t) async {
      EmAuthPhotos.precacheImpl = (context, p) => Completer<void>().future;
      await pumpSplash(t);
      await t.pump(const Duration(milliseconds: 300));
      expect(photoOpacity(t), 0);
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(EmMotion.photoReveal);
      expect(tileOpacity(t), 1, reason: 'the logo tile still arrives; the photo area stays navy');
    });

    testWidgets('a photo that fails to load degrades to navy, no exception', (t) async {
      await t.pumpWidget(const MaterialApp(home: SizedBox(width: 200, height: 400, child: EmPhotoBackdrop(image: AssetImage('assets/images/auth/missing.webp')))));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    });
  });

  group('EmPhotoBackdrop', () {
    testWidgets('cover fit, configurable alignment, navy overlay from the tokens, light status-bar icons', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: SizedBox(
          width: 200,
          height: 400,
          child: EmPhotoBackdrop(image: AssetImage(EmAuthPhotos.photo1), alignment: Alignment.bottomCenter, safeTop: 0.5),
        ),
      ));
      final image = t.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.bottomCenter);

      final gradient = (t.widget<DecoratedBox>(find.byKey(const Key('photo_overlay'))).decoration as BoxDecoration).gradient! as LinearGradient;
      final stops = EmPhotoOverlay.stops(0.5);
      expect(gradient.stops, [for (final s in stops) s.at]);
      expect(gradient.colors.first.a, 0, reason: 'clear at the top');
      expect(gradient.colors.first.toARGB32() & 0xFFFFFF, EmColors.primaryDark.toARGB32() & 0xFFFFFF, reason: 'transparent navy, not black: no grey fringe');
      expect(gradient.colors.last.a, closeTo(EmPhotoOverlay.bottomAlpha, 0.01), reason: 'near-opaque at the bottom');
      expect(gradient.colors.last.toARGB32() & 0xFFFFFF, EmColors.primaryDark.toARGB32() & 0xFFFFFF);

      final region = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('semantics: the photo is decorative (excluded), the screen reader reads the text only', (t) async {
      final h = t.ensureSemantics();
      await t.pumpWidget(const MaterialApp(home: SizedBox(width: 200, height: 400, child: EmPhotoBackdrop(image: AssetImage(EmAuthPhotos.photo1)))));
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      h.dispose();
    });
  });

  group('reduce motion', () {
    testWidgets('splash: photo and tile crossfade (200 ms), no rings, no logo travel; then no motion at all', (t) async {
      await pumpSplash(t, reduce: true);
      await t.pump(const Duration(milliseconds: 20));
      await t.pump(const Duration(milliseconds: 100));
      expect(photoOpacity(t), inExclusiveRange(0, 1));
      await t.pump(const Duration(milliseconds: 200));
      expect(photoOpacity(t), 1);
      expect(tileOpacity(t), 1);
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EmRippleRings), findsNothing);
      final rect = t.getRect(find.byType(EmLogomark));
      await t.pump(const Duration(seconds: 2));
      expect(t.getRect(find.byType(EmLogomark)), rect, reason: 'nothing moves');
      expect(t.hasRunningAnimations, isFalse);
    });

    testWidgets('normal motion keeps animating (the rings loop while init runs)', (t) async {
      await pumpSplash(t);
      await t.pump(const Duration(seconds: 3));
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EmRippleRings), findsOneWidget);
      expect(t.hasRunningAnimations, isTrue);
    });
  });

  group('ripple rings', () {
    test('two thin accent rings, half a cycle apart, each growing and fading out', () {
      expect(EmRippleRings.count, 2);
      expect(EmRippleRings.strokeWidth, lessThanOrEqualTo(2));
      final a = EmRippleRings.ring(0, 0.25), b = EmRippleRings.ring(1, 0.25);
      expect(b.growth, isNot(a.growth));
      expect(EmRippleRings.ring(0, 0).opacity, 1);
      expect(EmRippleRings.ring(0, 0.99).opacity, lessThan(0.05));
      var prev = 0.0;
      for (var p = 0.0; p < 1; p += 0.05) {
        final g = EmRippleRings.ring(0, p).growth;
        expect(g, greaterThanOrEqualTo(prev));
        prev = g;
      }
    });

    testWidgets('paints nothing until the tile has appeared (strength 0)', (t) async {
      final phase = AlwaysStoppedAnimation<double>(0.3);
      await t.pumpWidget(Center(child: CustomPaint(size: const Size(100, 100), painter: EmRippleRings(phase: phase, strength: const AlwaysStoppedAnimation(0)))));
      expect(t.takeException(), isNull);
    });
  });
}
