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
/// moving. Then (MOTION_SPEC.md §3.1) light travels along the solid links, the
/// dashed links drift, the orange node pulses with ripples and a faint
/// constellation fades in. Once [ready], at the end of the current motion beat,
/// the logo flies into the destination's [EmLogoAnchor] while the navy fades.
///
/// Reduce motion: the mark stays static, no constellation; the exit is a
/// crossfade.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.ready = false, this.flyToHeader = false, this.onExited});

  /// Init finished and the destination is in the tree under this overlay.
  final bool ready;

  /// The destination has a header logo to land on (login / intro). Otherwise
  /// the logo just fades out with the background.
  final bool flyToHeader;

  /// Called once the exit finished (remove this overlay).
  final VoidCallback? onExited;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

enum _Exit { flight, fade }

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const double _headerLogoHeight = 72;

  /// Constellation keeps clear of the centre column (logo, title, tagline).
  static const Rect _logoZone = Rect.fromLTRB(0.15, 0.36, 0.85, 0.66);

  late final AnimationController _intro;
  late final AnimationController _time;
  late final AnimationController _exit;
  late final AnimationController _caption;

  late final Animation<double> _charge;
  late final Animation<double> _pulse;
  late final Animation<double> _ripple;
  late final Animation<double> _dash;
  late final Animation<double> _constellation;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final CurvedAnimation _morph;
  late final CurvedAnimation _bgOut;
  late final CurvedAnimation _textOut;

  late final EmNetworkDrive _drive;
  Timer? _exitTimer;
  Timer? _slowTimer;
  bool _reduced = false;
  bool _configured = false;
  bool _exiting = false;
  bool _darkIcons = false;
  _Exit _mode = _Exit.fade;
  Duration _exitDuration = EmMotion.hero;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: EmSplashTimeline.intro);
    _time = AnimationController(vsync: this, duration: EmMotion.ambientPeriod);
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
    _ripple = window(EmSplashTimeline.ripple);
    _constellation = window(EmSplashTimeline.constellation);
    // 60 whole dash periods per ambient loop: the dash drift never seams.
    _dash = Tween<double>(
      begin: 0,
      end: EmMotion.ambientPeriod.inMilliseconds / EmMotion.dashPeriod.inMilliseconds,
    ).animate(_time);

    const text = EmSplashTimeline.text;
    final t0 = EmSplashTimeline.at(text.begin), t1 = EmSplashTimeline.at(text.end);
    _titleFade = CurvedAnimation(parent: _intro, curve: Interval(t0, t0 + (t1 - t0) * 0.7, curve: Curves.easeOut));
    _titleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _intro, curve: Interval(t0, t1, curve: EmMotion.enter)));
    _taglineFade = CurvedAnimation(parent: _intro, curve: Interval(t0 + (t1 - t0) * 0.3, t1, curve: Curves.easeOut));

    _morph = CurvedAnimation(parent: _exit, curve: const Threshold(1));
    _bgOut = CurvedAnimation(parent: _exit, curve: const Interval(0, 1));
    _textOut = CurvedAnimation(parent: _exit, curve: const Interval(0, 1));

    _drive = EmNetworkDrive(
      to: EmNetworkPalette.standard,
      morph: _morph,
      charge: _charge,
      dashPhase: _dash,
      pulse: _pulse,
      ripple: _ripple,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = EmReduceMotion.of(context);
    if (!_configured || reduced != _reduced) {
      _configured = true;
      _reduced = reduced;
      if (reduced) {
        _intro.stop();
        _time.stop();
      } else if (!_exiting) {
        if (!_intro.isCompleted && !_intro.isAnimating) _intro.forward();
        if (!_time.isAnimating) _time.repeat();
      }
    }
    if (widget.ready) _scheduleExit();
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
    if (EmLogoHandoff.flying.value) {
      // never notify listeners while the tree is being torn down
      SchedulerBinding.instance.addPostFrameCallback((_) => EmLogoHandoff.flying.value = false);
    }
    _morph.dispose();
    _bgOut.dispose();
    _textOut.dispose();
    _caption.dispose();
    _intro.dispose();
    _time.dispose();
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
    final fly = widget.flyToHeader && !_reduced;
    _mode = fly ? _Exit.flight : _Exit.fade;
    _exitDuration = _reduced ? EmMotion.crossfade : (fly ? EmMotion.hero : EmMotion.slow);
    _exit.duration = _exitDuration;
    if (fly) {
      // title/tagline gone in the first 180 ms; navy + constellation from 120 ms
      _textOut.curve = Interval(0, 180 / _exitDuration.inMilliseconds);
      _bgOut.curve = Interval(120 / _exitDuration.inMilliseconds, 480 / _exitDuration.inMilliseconds);
      _morph.curve = EmMotion.emphasized;
      EmLogoHandoff.flying.value = true;
    } else {
      _textOut.curve = const Interval(0, 1);
      _bgOut.curve = const Interval(0, 1);
    }
    _exit.forward();
  }

  void _onExitTick() {
    final dark = _bgOut.value > 0.5;
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
    // no anchor yet (the intro screen has no logo until M2): the header slot
    const h = _headerLogoHeight;
    const w = h * EmLogomarkGeometry.aspect;
    return (Rect.fromLTWH((screen.width - w) / 2, MediaQuery.paddingOf(context).top + EmSpacing.s16, w, h), false);
  }

  @override
  Widget build(BuildContext context) {
    final logo = EmLogomark(
      height: EmLogomark.splashHeight,
      reversed: true,
      semanticLabel: 'Eldermin Teacher',
      drive: _reduced ? null : _drive,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // light status-bar icons on the navy background, like the native splash
      value: _darkIcons ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, box) {
            final screen = box.biggest;
            final belowLogo = screen.height / 2 + EmLogomark.splashHeight / 2 + EmSpacing.s24;
            return Stack(
              fit: StackFit.expand,
              children: [
                FadeTransition(
                  opacity: ReverseAnimation(_bgOut),
                  child: Scaffold(
                    backgroundColor: EmColors.primaryDark,
                    body: _reduced ? null : EmConstellation(time: _time, intensity: _constellation, avoid: _logoZone),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: belowLogo,
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
                              child: Text('Eldermin Teacher',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: EmType.display.copyWith(color: EmColors.onPrimaryDark)),
                            ),
                          ),
                          const SizedBox(height: EmSpacing.s8),
                          FadeTransition(
                            opacity: _reduced ? const AlwaysStoppedAnimation(1) : _taglineFade,
                            child: Text('Your classroom, in your pocket.',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: EmType.body.copyWith(color: EmColors.primaryLight, fontWeight: FontWeight.w400)),
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
                // exact centre, identical to the native splash image; flies on exit
                AnimatedBuilder(
                  animation: _exit,
                  child: Center(child: logo),
                  builder: (context, child) {
                    if (!_exiting) return child!;
                    final p = _exit.value;
                    if (_mode == _Exit.flight) {
                      final t = EmMotion.emphasized.transform(p);
                      final (target, anchored) = _target(context, screen);
                      final shift = Offset.lerp(Offset.zero, target.center - screen.center(Offset.zero), t)!;
                      final scale = lerpDouble(1, target.height / EmLogomark.splashHeight, t)!;
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
