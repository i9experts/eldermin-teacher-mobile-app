@Tags(['golden'])
library;

import 'dart:io';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/design/gallery/gallery_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';

/// Goldens of each gallery section: normal (390), text scale 1.3 and iPhone SE
/// width (375). macOS baselines only; other hosts skip.
///
///   Update:  flutter test test/design/gallery_golden_test.dart --tags golden --update-goldens
///   Verify:  flutter test --tags golden
void main() {
  setUpAll(loadDesignFonts);
  // flutter_test draws shadows as hard shapes by default; render them for real.
  final skip = Platform.isMacOS ? null : 'goldens are macOS baselines';

  final sections = <String, Widget>{
    'brand': const GalleryBrandSection(),
    'colors': const GalleryColorsSection(),
    'type_shapes': const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [GalleryTypeSection(), SizedBox(height: 12), GalleryShapeSection()]),
    'chrome': const GalleryChromeSection(),
    'dashboard': GalleryDashboardSection(today: DateTime(2025, 5, 21)),
    'charts': const GalleryChartsSection(),
    'lists': const GalleryListsSection(),
    'controls': const GalleryControlsSection(),
  };
  final variants = {'normal': (390.0, 1.0), 'scale13': (390.0, 1.3), 'se375': (375.0, 1.0)};

  for (final s in sections.entries) {
    for (final v in variants.entries) {
      testWidgets('${s.key} / ${v.key}', (t) async {
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = true);
        final key = GlobalKey();
        await pumpEm(
          t,
          RepaintBoundary(key: key, child: ColoredBox(color: EmColors.background, child: Padding(padding: const EdgeInsets.all(16), child: s.value))),
          width: v.value.$1,
          height: 4000,
          textScale: v.value.$2,
          padding: EdgeInsets.zero,
        );
        expectNoLayoutErrors(t);
        await expectLater(find.byKey(key), matchesGoldenFile('goldens/${s.key}_${v.key}.png'));
        debugDisableShadows = true; // invariant: must be restored before the test body ends
      }, skip: skip != null);
    }
  }
}
