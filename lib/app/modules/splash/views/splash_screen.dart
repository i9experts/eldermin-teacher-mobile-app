import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';

/// The root screen shown while [AuthController] resolves its bootstrap
/// (token check + profile fetch), and - as an overlay on the next screen - the
/// hand-off into it. Purely presentational: the swap away is driven by
/// `_AuthGate` in main.dart reacting to `AuthController.status`, which passes
/// [ready] and removes the overlay in [onExited].
///
/// Frame 0 is the native splash: same `primaryDark` background and the
/// reversed logomark at [EmLogomark.splashHeight] in the exact centre, nothing
/// moving. Then (MOTION_SPEC.md section 3.1) in the first beat the first photo
/// crossfades in behind the logo under the navy overlay, a white rounded tile
/// grows around the logo (which turns navy / orange), light travels along the
/// solid links, the dashed links drift, the accent node pulses and two thin
/// accent rings ripple out of the tile. Once [ready], at the end of the current
/// motion beat, the logo tile flies into the destination's [EmLogoAnchor] while
/// the photo fades.
///
/// Reduce motion: the photo and the tile crossfade in ([EmMotion.crossfade]);
/// no rings, no link motion; the exit is a crossfade.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.ready = false, this.flyToHeader = false, this.onExited});

  /// Init finished and the destination is in the tree under this overlay.
  final bool ready;

  /// The destination has a header logo to land on (login / intro). Otherwise
  /// the logo just fades out with the background.
  final bool flyToHeader;

  /// Called once the exit finished (remove this overlay).
  final VoidCallback? onExited;

  /// Display name and tagline under the logo.
  static const String title = 'Eldermin Teacher';
  static const String tagline = 'Your classroom, in your pocket.';

  /// Side of the white logo tile on the splash (the logo inside is [EmLogomark.splashHeight]).
  static const double tileSize = EmLogomark.splashHeight / EmLogoTile.logoShare;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

enum _Exit { flight, fade }

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  /// Side of the destination's logo tile when there is no anchor to measure.
  static const double _headerTile = 56;

  late final AnimationController _intro;
  late final AnimationController _time;
  late final AnimationController _reveal;
  late final AnimationController _rings;
  late final AnimationController _exit;
  late final AnimationController _caption;

  late final Animation<double> _charge;
  late final Animation<double> _pulse;
  late final Animation<double> _dash;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final CurvedAnimation _photo;
  late final CurvedAnimation _tile;
  late final CurvedAnimation _bgOut;
  late final CurvedAnimation _textOut;

  Timer? _exitTimer;
  Timer? _slowTimer;
  bool _reduced = false;
  bool _configured = false;
  bool _exiting = false;
  bool _darkIcons = false;
  bool _revealStarted = false;
  _Exit _mode = _Exit.fade;
  Duration _exitDuration = EmMotion.hero;

  @override
  void initState() {
    super.initState();
    EmLogoHandoff.splashShowing = true;
    _intro = AnimationController(vsync: this, duration: EmSplashTimeline.intro);
    _time = AnimationController(vsync: this, duration: EmMotion.ambientPeriod);
    _reveal = AnimationController(vsync: this, duration: EmMotion.photoReveal);
    _rings = AnimationController(vsync: this, duration: EmMotion.ringPeriod);
    _caption = AnimationController(vsync: this, duration: EmMotion.slow);
    _slowTimer = Timer(EmSplashTimeline.slowInitAfter, () {
      if (mounted && !_exiting) _caption.forward();
    });
    _exit = AnimationController(vsync: this, duration: EmMotion.hero)
      ..addListener(_onExitTick)
      ..addStatusListener(_onExitStatus);

    Animation<double> window(({int begin, int end}) w) =>
        CurvedAnimation(parent: _intro, curve: Interval(EmSplashTimeline.at(w.begin), EmSplashTimeline.at(w.end)));
    _charge = window(EmSplashTimeline.charge);
    _pulse = window(EmSplashTimeline.pulse);
    // 60 whole dash periods per ambient loop: the dash drift never seams.
    _dash = Tween<double>(
      begin: 0,
      end: EmMotion.ambientPeriod.inMilliseconds / EmMotion.dashPeriod.inMilliseconds,
    ).animate(_time);

    // photo first, the tile (and the logo turning navy) a beat behind it
    _photo = CurvedAnimation(parent: _reveal, curve: Curves.easeOut);
    _tile = CurvedAnimation(parent: _reveal, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic));

    const text = EmSplashTimeline.text;
    final t0 = EmSplashTimeline.at(text.begin), t1 = EmSplashTimeline.at(text.end);
    _titleFade = CurvedAnimation(parent: _intro, curve: Interval(t0, t0 + (t1 - t0) * 0.7, curve: Curves.easeOut));
    _titleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _intro, curve: Interval(t0, t1, curve: EmMotion.enter)));
    _taglineFade = CurvedAnimation(parent: _intro, curve: Interval(t0 + (t1 - t0) * 0.3, t1, curve: Curves.easeOut));

    _bgOut = CurvedAnimation(parent: _exit, curve: const Interval(0, 1));
    _textOut = CurvedAnimation(parent: _exit, curve: const Interval(0, 1));
  }

  /// The logo's live drive: it turns from the reversed (navy-ground) palette to
  /// the standard one as the white tile appears; links charge and the accent
  /// node pulses in the first beat. Reduce motion: the palette change only.
  EmNetworkDrive get _drive => _reduced
      ? EmNetworkDrive(to: EmNetworkPalette.standard, morph: _tile)
      : EmNetworkDrive(to: EmNetworkPalette.standard, morph: _tile, charge: _charge, dashPhase: _dash, pulse: _pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = EmReduceMotion.of(context);
    if (!_revealStarted) {
      _revealStarted = true;
      _reveal.duration = reduced ? EmMotion.crossfade : EmMotion.photoReveal;
      _beginReveal();
    }
    if (!_configured || reduced != _reduced) {
      _configured = true;
      _reduced = reduced;
      if (reduced) {
        _intro.stop();
        _time.stop();
        _rings.stop();
      } else if (!_exiting) {
        if (!_intro.isCompleted && !_intro.isAnimating) _intro.forward();
        if (!_time.isAnimating) _time.repeat();
        if (!_rings.isAnimating) _rings.repeat();
      }
    }
    if (widget.ready) _scheduleExit();
  }

  /// Preloads the photos (first one first), then crossfades the first in. The
  /// splash never waits long for them: it reveals after [_photoWait] regardless.
  static const Duration _photoWait = Duration(milliseconds: 400);

  Future<void> _beginReveal() async {
    unawaited(EmAuthPhotos.precache(context));
    await EmAuthPhotos.precache(context, assets: const [EmAuthPhotos.photo1]).timeout(_photoWait, onTimeout: () {});
    if (mounted && !_reveal.isAnimating && !_reveal.isCompleted) _reveal.forward();
  }

  @override
  void didUpdateWidget(SplashScreen old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) _scheduleExit();
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _slowTimer?.cancel();
    // never notify listeners while the tree is being torn down
    SchedulerBinding.instance.addPostFrameCallback((_) {
      EmLogoHandoff.flying.value = false;
      EmLogoHandoff.overlay.value = false;
    });
    _photo.dispose();
    _tile.dispose();
    _bgOut.dispose();
    _textOut.dispose();
    _caption.dispose();
    _intro.dispose();
    _time.dispose();
    _reveal.dispose();
    _rings.dispose();
    _exit.dispose();
    super.dispose();
  }

  // ---- Exit ----

  void _scheduleExit() {
    if (_exiting || (_exitTimer?.isActive ?? false)) return;
    final wait = _reduced
        ? Duration.zero
        : EmSplashTimeline.exitDelay(Duration(milliseconds: (_intro.value * EmSplashTimeline.intro.inMilliseconds).round()),
            exit: widget.flyToHeader ? EmMotion.hero : EmMotion.slow);
    _exitTimer = Timer(wait, () {
      // after the frame in which the destination was laid out, so its anchor exists
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startExit();
      });
      SchedulerBinding.instance.scheduleFrame();
    });
  }

  void _startExit() {
    if (_exiting) return;
    _exiting = true;
    _slowTimer?.cancel();
    _time.stop();
    _rings.stop();
    // whatever the reveal had reached is what the flight starts from
    if (_reveal.isAnimating) _reveal.value = 1;
    final fly = widget.flyToHeader && !_reduced;
    _mode = fly ? _Exit.flight : _Exit.fade;
    _exitDuration = _reduced ? EmMotion.crossfade : (fly ? EmMotion.hero : EmMotion.slow);
    _exit.duration = _exitDuration;
    if (fly) {
      // title/tagline gone in the first 180 ms; the photo fades from 120 ms (the next screen has the same photo)
      _textOut.curve = Interval(0, 180 / _exitDuration.inMilliseconds);
      _bgOut.curve = Interval(120 / _exitDuration.inMilliseconds, 480 / _exitDuration.inMilliseconds);
      EmLogoHandoff.flying.value = true;
    } else {
      _textOut.curve = const Interval(0, 1);
      _bgOut.curve = const Interval(0, 1);
    }
    _exit.forward();
  }

  void _onExitTick() {
    // a light destination (home) needs dark status-bar icons once the photo is half gone; the photo screens keep light ones
    final dark = !widget.flyToHeader && _bgOut.value > 0.5;
    if (dark != _darkIcons) setState(() => _darkIcons = dark);
  }

  void _onExitStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    EmLogoHandoff.flying.value = false;
    widget.onExited?.call();
  }

  // ---- Build ----

  (Rect, bool) _target(BuildContext context, Size screen) {
    final box = context.findRenderObject();
    final landed = box is RenderBox ? EmLogoHandoff.anchorRectIn(box) : null;
    if (landed != null) return (landed, true);
    // no anchor yet: the top corner slot the photo screens use
    const h = _headerTile;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final left = rtl ? EmSpacing.s24 : screen.width - EmSpacing.s24 - h;
    return (Rect.fromLTWH(left, MediaQuery.paddingOf(context).top + EmSpacing.s12, h, h), false);
  }

  @override
  Widget build(BuildContext context) {
    const tileSize = SplashScreen.tileSize;
    final mark = SizedBox.square(
      dimension: tileSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (!_reduced)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: EmRippleRings(phase: _rings, strength: _tile, radiusFactor: EmRadius.logoTileRatio),
                ),
              ),
            ),
          // the white tile grows in around the logo, with a small swell on the pulse
          FadeTransition(
            opacity: _tile,
            child: AnimatedBuilder(
              animation: Listenable.merge([_tile, _pulse]),
              builder: (context, child) {
                final swell = _reduced ? 1.0 : 1 + 0.03 * (_pulse.value <= 0 || _pulse.value >= 1 ? 0 : 1 - (2 * _pulse.value - 1).abs());
                return Transform.scale(scale: lerpDouble(0.92, 1, _tile.value)! * swell, child: child);
              },
              child: const EmLogoTile(size: tileSize, child: SizedBox.shrink()),
            ),
          ),
          EmLogomark(
            height: EmLogomark.splashHeight,
            reversed: true,
            semanticLabel: SplashScreen.title,
            drive: _drive,
          ),
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // light status-bar icons on the navy / photo background, like the native splash
      value: _darkIcons ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, box) {
            final screen = box.biggest;
            final textTop = screen.height / 2 + tileSize / 2 + EmSpacing.s24;
            // the text sits at or below the overlay's strong line (EmPhotoOverlay), whatever the text size
            final safeTop = EmPhotoOverlay.safeTopFor(textTop / screen.height, margin: 0.02);
            return Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: ReverseAnimation(_bgOut),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: EmColors.primaryDark),
                      FadeTransition(
                        opacity: _photo,
                        child: EmPhotoBackdrop(image: EmAuthPhotos.provider(EmAuthPhotos.photo1), safeTop: safeTop),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: textTop,
                  child: FadeTransition(
                    opacity: ReverseAnimation(_textOut),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.s32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _reduced ? const AlwaysStoppedAnimation(1) : _titleFade,
                            child: SlideTransition(
                              position: _reduced ? const AlwaysStoppedAnimation(Offset.zero) : _titleSlide,
                              child: Text(SplashScreen.title,
                                  key: const Key('splash_title'),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: EmType.splashTitle.copyWith(color: EmColors.onPrimaryDark)),
                            ),
                          ),
                          const SizedBox(height: EmSpacing.s8),
                          // accent is 4.43:1 on the navy: LARGE bold text only (3:1 rule), never body size
                          FadeTransition(
                            opacity: _reduced ? const AlwaysStoppedAnimation(1) : _taglineFade,
                            child: Text(SplashScreen.tagline,
                                key: const Key('splash_tagline'),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: EmType.splashTagline.copyWith(color: EmColors.accent)),
                          ),
                          const SizedBox(height: EmSpacing.s16),
                          // slow init only (EmSplashTimeline.slowInitAfter); space is reserved so nothing shifts
                          FadeTransition(
                            opacity: _caption,
                            child: Text('Connecting…',
                                key: const Key('splash_connecting'),
                                textAlign: TextAlign.center,
                                style: EmType.caption.copyWith(color: EmColors.primaryLight)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // exact centre, identical to the native splash image at frame 0; flies on exit
                AnimatedBuilder(
                  animation: _exit,
                  child: Center(child: mark),
                  builder: (context, child) {
                    if (!_exiting) return child!;
                    final p = _exit.value;
                    if (_mode == _Exit.flight) {
                      final t = EmMotion.emphasized.transform(p);
                      final (target, anchored) = _target(context, screen);
                      final shift = Offset.lerp(Offset.zero, target.center - screen.center(Offset.zero), t)!;
                      final scale = lerpDouble(1, target.height / tileSize, t)!;
                      final flown = Transform.translate(offset: shift, child: Transform.scale(scale: scale, child: child));
                      // nothing to land on: fade out over the last 40% of the flight
                      return anchored
                          ? flown
                          : Opacity(opacity: 1 - Curves.easeIn.transform(((p - 0.6) / 0.4).clamp(0.0, 1.0)), child: flown);
                    }
                    // no header logo to land on: scale down a touch and fade with the background
                    return Opacity(
                      opacity: 1 - EmMotion.exit.transform(p),
                      child: Transform.scale(scale: lerpDouble(1, 0.9, p)!, child: child),
                    );
                  },
                ),
                // the animated mark has its own label; this keeps the loading cue for screen readers
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Semantics(
                    label: 'Loading',
                    liveRegion: true,
                    child: const SizedBox(width: 1, height: 1),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
