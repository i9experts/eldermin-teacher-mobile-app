import 'package:flutter/material.dart';
import '../motion/constellation_painter.dart';
import '../motion/logo_handoff.dart';
import '../motion/logomark_geometry.dart';
import '../motion/reduce_motion.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';
import 'em_app_bar.dart';
import 'em_logomark.dart';

enum EmHeroSize { full, compact }

/// The navy hero of the sign-in screens: the logo (the splash landing anchor),
/// the title and subtitle over a slowly drifting constellation.
///
/// [collapsed] (the keyboard is open) shrinks the logo, drops the subtitle and
/// dims the constellation; the height follows with [AnimatedSize], so the form
/// below stays in view. Reduce motion: no constellation, no animated resize.
class EmAuthHero extends StatelessWidget {
  const EmAuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.size = EmHeroSize.compact,
    this.collapsed = false,
    this.showBack = false,
    this.glyph,
    this.time,
    this.intensity,
  });

  final String title;
  final String subtitle;
  final EmHeroSize size;
  final bool collapsed;
  final bool showBack;

  /// Replaces the logo (the assembled success glyph on forgot password).
  final Widget? glyph;

  /// Constellation drivers (the screen owns the controllers); null = none.
  final Animation<double>? time;
  final Animation<double>? intensity;

  static const double logoFull = 84, logoCompact = 56, logoCollapsed = 40;

  @override
  Widget build(BuildContext context) {
    final reduced = EmReduceMotion.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final full = size == EmHeroSize.full;
    final logoHeight = collapsed ? logoCollapsed : (full ? logoFull : logoCompact);
    final slide = reduced ? Duration.zero : EmMotion.slow;

    final logo = glyph ??
        EmLogoAnchor(
          palette: EmNetworkPalette.reversed,
          child: EmLogomark(height: logoHeight, reversed: true, semanticLabel: 'Eldermin'),
        );

    final content = Padding(
      padding: EdgeInsetsDirectional.only(top: top + EmSpacing.s12, bottom: EmSpacing.s24, start: EmSpacing.s24, end: EmSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // the logo slot keeps its height while a glyph is shown in it
          AnimatedContainer(
            duration: slide,
            curve: EmMotion.emphasized,
            height: glyph != null ? 96 : logoHeight,
            alignment: Alignment.center,
            child: logo,
          ),
          const SizedBox(height: EmSpacing.s12),
          Semantics(
            header: true,
            child: Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (full && !collapsed ? EmType.display : EmType.title).copyWith(color: EmColors.onPrimaryDark)),
          ),
          if (!collapsed) ...[
            const SizedBox(height: EmSpacing.s8),
            Text(subtitle,
                textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.primaryContainer, fontWeight: FontWeight.w400)),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: EmColors.primaryDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(EmRadius.hero)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(EmRadius.hero)),
        child: Stack(
          children: [
            if (!reduced && time != null && intensity != null)
              Positioned.fill(child: EmConstellation(time: time!, intensity: intensity!, seed: 21)),
            SizedBox(
              width: double.infinity,
              child: AnimatedSize(duration: slide, curve: EmMotion.emphasized, alignment: Alignment.topCenter, child: content),
            ),
            if (showBack) Positioned(top: top, left: 0, right: 0, child: const EmAppBar()),
          ],
        ),
      ),
    );
  }
}
