import 'package:eldermin_teacher_app/app/routes/app_pages.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/design/gallery/design_gallery_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(loadDesignFonts);

  group('gallery route is debug-only', () {
    test('disabled (release config): no page is registered', () {
      expect(AppPages.designGalleryPages(enabled: false), isEmpty);
    });
    test('enabled (debug config): exactly one page at /design-gallery', () {
      final pages = AppPages.designGalleryPages(enabled: true);
      expect(pages.length, 1);
      expect(pages.single.name, Routes.designGallery);
    });
    test('default follows kDebugMode, and AppPages.pages matches', () {
      expect(AppPages.designGalleryPages().isNotEmpty, kDebugMode);
      expect(AppPages.pages.any((p) => p.name == Routes.designGallery), kDebugMode);
    });
    test('the gallery is not a module route and not public', () {
      expect(Routes.all, isNot(contains(Routes.designGallery)));
    });
    test('release builds drop the route: the only registration site is behind the flag', () {
      // `AppPages.designGalleryPages` returns `const []` unless enabled, and
      // `enabled` defaults to the compile-time `kDebugMode` (false in release),
      // so the only reference to DesignGalleryScreen is unreachable and tree-shaken.
      expect(AppPages.designGalleryPages(enabled: kReleaseMode), kReleaseMode ? isNotEmpty : isEmpty);
    });
  });

  group('gallery renders every section without layout errors', () {
    for (final (name, w, h, scale) in [
      ('360x800', 360.0, 800.0, 1.0),
      ('SE 375x667', 375.0, 667.0, 1.0),
      ('360x800 @1.3x', 360.0, 800.0, 1.3),
      ('SE 375x667 @1.3x', 375.0, 667.0, 1.3),
    ]) {
      testWidgets(name, (t) async {
        Get.testMode = true;
        await pumpEm(t, const DesignGalleryScreen(), width: w, height: h, textScale: scale, scaffold: false);
        expectNoLayoutErrors(t);
        // scroll to the end so every lazily built section is laid out
        for (var i = 0; i < 40; i++) {
          await t.drag(find.byType(ListView).first, const Offset(0, -500));
          await t.pump(const Duration(milliseconds: 50));
          final e = t.takeException();
          expect(e, isNull, reason: 'scroll step $i: ${e?.toString().split('\n').first}');
        }
        expect(find.text('Open sheet'), findsOneWidget);
      });
    }
  });
}
