import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../motion/reduce_motion.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_photo_overlay.dart';

/// The three auth photos (assets/images/auth) and their preloading.
class EmAuthPhotos {
  EmAuthPhotos._();

  static const String photo1 = 'assets/images/auth/teacher_1.webp';
  static const String photo2 = 'assets/images/auth/teacher_2.webp';
  static const String photo3 = 'assets/images/auth/teacher_3.webp';

  /// Onboarding order; [photo1] is also the splash and sign-in photo.
  static const List<String> slides = [photo1, photo2, photo3];

  static ImageProvider provider(String asset) => AssetImage(asset);

  /// Decodes [assets] into the image cache so the splash hand-off and the swipes
  /// never show a half-loaded photo. Photo 1 goes first (the splash needs it).
  static Future<void> precache(BuildContext context, {List<String> assets = slides}) async {
    for (final a in assets) {
      await precacheImpl(context, provider(a));
    }
  }

  /// Swappable in tests (widget tests cannot decode real images).
  @visibleForTesting
  static Future<void> Function(BuildContext, ImageProvider) precacheImpl = _precache;

  static Future<void> _precache(BuildContext context, ImageProvider p) async {
    try {
      await precacheImage(p, context);
    } catch (_) {/* a missing photo degrades to the navy background */}
  }
}

/// Full-bleed photo with the navy overlay. [image] fills the box (`BoxFit.cover`,
/// [alignment]); the overlay builds from clear at the top to near-opaque
/// [EmPhotoOverlay.base] at the bottom, with its stops from [EmPhotoOverlay]
/// hung off [safeTop]. Status-bar icons are light. See [EmPhotoOverlay] for the
/// text rule: content starts at or below `EmPhotoOverlay.strongLine(safeTop)`.
class EmPhotoBackdrop extends StatelessWidget {
  const EmPhotoBackdrop({
    super.key,
    required this.image,
    this.alignment = Alignment.topCenter,
    this.safeTop = EmPhotoOverlay.defaultSafeTop,
    this.bottomAlpha = EmPhotoOverlay.bottomAlpha,
    this.topScrim = true,
    this.child,
  });

  final ImageProvider image;
  final Alignment alignment;
  final double safeTop;

  /// Alpha at the very bottom (1 where the backdrop meets a solid navy page).
  final double bottomAlpha;
  final bool topScrim;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: EmPhotoOverlay.base),
          ExcludeSemantics(child: EmPhotoImage(image: image, alignment: alignment)),
          EmPhotoOverlayLayer(safeTop: safeTop, bottomAlpha: bottomAlpha, topScrim: topScrim),
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// The photo alone: cover-fit, fades in when it was not preloaded, navy if it fails to load.
class EmPhotoImage extends StatelessWidget {
  const EmPhotoImage({super.key, required this.image, this.alignment = Alignment.topCenter});
  final ImageProvider image;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final fade = EmReduceMotion.of(context) ? EmMotion.crossfade : EmMotion.slow;
    return Image(
      image: image,
      fit: BoxFit.cover,
      alignment: alignment,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sync) =>
          sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: EmMotion.enter, child: child),
      errorBuilder: (context, error, stack) => const ColoredBox(color: EmPhotoOverlay.base),
    );
  }
}

/// The overlay gradient (and the status-bar scrim) on its own.
class EmPhotoOverlayLayer extends StatelessWidget {
  const EmPhotoOverlayLayer({super.key, required this.safeTop, this.bottomAlpha = EmPhotoOverlay.bottomAlpha, this.topScrim = true});
  final double safeTop;
  final double bottomAlpha;
  final bool topScrim;

  @override
  Widget build(BuildContext context) {
    final stops = EmPhotoOverlay.stops(safeTop, bottom: bottomAlpha);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            key: const Key('photo_overlay'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [for (final s in stops) EmPhotoOverlay.base.withValues(alpha: s.alpha)],
                stops: [for (final s in stops) s.at],
              ),
            ),
          ),
          if (topScrim)
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: EmPhotoOverlay.topScrimHeight,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [EmPhotoOverlay.base.withValues(alpha: EmPhotoOverlay.topScrimAlpha), EmPhotoOverlay.base.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The onboarding photo stack: [progress] (a PageController offset, 0..n-1)
/// scrubs a crossfade from photo `floor(progress)` to the next, with a slight
/// parallax (each photo drifts [EmMotion.parallaxShift] against the swipe).
///
/// Reduce motion: no parallax and no scrubbing; the photos just crossfade
/// ([EmMotion.crossfade]) when the settled page changes.
class EmPhotoCarouselBackdrop extends StatelessWidget {
  const EmPhotoCarouselBackdrop({
    super.key,
    required this.images,
    required this.progress,
    this.alignment = Alignment.topCenter,
    this.safeTop = EmPhotoOverlay.defaultSafeTop,
  });

  final List<ImageProvider> images;
  final ValueListenable<double> progress;
  final Alignment alignment;
  final double safeTop;

  @override
  Widget build(BuildContext context) {
    final reduced = EmReduceMotion.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: EmPhotoOverlay.base),
          ExcludeSemantics(
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, p, _) => reduced ? _settled(p) : _scrubbed(p),
            ),
          ),
          EmPhotoOverlayLayer(safeTop: safeTop),
        ],
      ),
    );
  }

  Widget _photo(int i) => EmPhotoImage(key: ValueKey('photo_$i'), image: images[i], alignment: alignment);

  /// Reduce motion: the settled photo is opaque, the others are clear; changes crossfade.
  Widget _settled(double p) {
    final current = p.round().clamp(0, images.length - 1);
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < images.length; i++)
        AnimatedOpacity(
          key: ValueKey('fade_$i'),
          opacity: i == current ? 1 : 0,
          duration: EmMotion.crossfade,
          child: _photo(i),
        ),
    ]);
  }

  /// A true crossfade (the lower photo stays opaque, the upper one fades in over
  /// it, so the middle never dips to the navy behind) with parallax.
  Widget _scrubbed(double p) {
    final clamped = p.clamp(0.0, (images.length - 1).toDouble()).toDouble();
    final lo = clamped.floor();
    final t = clamped - lo;
    final hi = math.min(lo + 1, images.length - 1);
    Widget shifted(int i, double opacity) {
      final dx = (i - clamped) * EmMotion.parallaxShift; // the photo trails the swipe
      return Opacity(
        key: ValueKey('scrub_$i'),
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(dx, 0),
          // scaled up a touch so the shifted edge never shows the navy behind
          child: Transform.scale(scale: EmMotion.parallaxScale, child: _photo(i)),
        ),
      );
    }

    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        shifted(lo, 1),
        if (hi != lo && t > 0) shifted(hi, t),
      ]),
    );
  }
}
