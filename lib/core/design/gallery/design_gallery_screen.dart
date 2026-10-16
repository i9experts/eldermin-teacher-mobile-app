import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../widgets.dart';
import 'gallery_sections.dart';

/// DEBUG-ONLY catalogue of every Em widget, the colour tokens and the type
/// scale. Registered only when `kDebugMode` (see `AppPages.designGalleryPages`);
/// open with `Get.toNamed(Routes.designGallery)`.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'DesignGalleryScreen is debug-only');
    return EmScaffold(
      appBar: const EmAppBar(title: 'Design gallery'),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.screenH, 0, EmSpacing.screenH, EmSpacing.navClearance),
        children: const [
          Text('Debug build only. Brand hexes and the logomark are pending brand confirmation.', style: TextStyle(color: EmColors.textSecondary)),
          GallerySectionTitle('Brand'),
          GalleryBrandSection(),
          GallerySectionTitle('Colour tokens'),
          GalleryColorsSection(),
          GallerySectionTitle('Type scale'),
          GalleryTypeSection(),
          GallerySectionTitle('Radii'),
          GalleryShapeSection(),
          GallerySectionTitle('Chrome'),
          GalleryChromeSection(),
          GallerySectionTitle('Dashboard'),
          GalleryDashboardSection(),
          GallerySectionTitle('Charts'),
          GalleryChartsSection(),
          GallerySectionTitle('Lists'),
          GalleryListsSection(),
          GallerySectionTitle('Controls & states'),
          GalleryControlsSection(),
        ],
      ),
    );
  }
}
