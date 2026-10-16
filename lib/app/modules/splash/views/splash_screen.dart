import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';

/// The root screen shown while [AuthController] resolves its bootstrap
/// (token check + profile fetch). Purely presentational - the
/// swap away from this screen is driven entirely by `_AuthGate` in
/// main.dart reacting to `AuthController.status`.
///
/// Hand-off from the native splash: same `primaryDark` background and the
/// reversed logomark at the same size ([EmLogomark.splashHeight]) in the exact
/// centre of the screen, fully visible from the first frame (no scale or fade
/// on the logo, so nothing jumps). Only the title, tagline and loading dots
/// fade in, below the logo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _titleFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.1, 0.55, curve: Curves.easeOut));
    _titleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic)));
    _taglineFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.35, 0.8, curve: Curves.easeOut));
    _loaderFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle
          .light, // light status-bar icons on the navy background, like the native splash
      child: Scaffold(
        backgroundColor: EmColors.primaryDark,
        body: LayoutBuilder(
          builder: (context, box) {
            final belowLogo =
                box.maxHeight / 2 + EmLogomark.splashHeight / 2 + EmSpacing.s24;
            return Stack(
              children: [
                // exact centre, identical to the native splash image
                const Center(
                    child: EmLogomark(
                        height: EmLogomark.splashHeight,
                        reversed: true,
                        semanticLabel: 'Eldermin Teacher')),
                Positioned(
                  left: 0,
                  right: 0,
                  top: belowLogo,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: EmSpacing.s32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _titleFade,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: Text('Eldermin Teacher',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: EmType.display.copyWith(
                                    color: EmColors.onPrimaryDark,
                                    fontSize: 28)),
                          ),
                        ),
                        const SizedBox(height: EmSpacing.s8),
                        FadeTransition(
                          opacity: _taglineFade,
                          child: Text('Your classroom, in your pocket.',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: EmType.body.copyWith(
                                  color: EmColors.primaryLight,
                                  fontWeight: FontWeight.w400)),
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                          bottom: EmSpacing.s32),
                      child: FadeTransition(
                          opacity: _loaderFade,
                          child: Center(child: _LoadingDots(loop: _loop))),
                    ),
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

/// Three softly pulsing dots (phase-offset via a repeating controller).
class _LoadingDots extends StatelessWidget {
  final AnimationController loop;
  const _LoadingDots({required this.loop});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (loop.value + i * 0.2) % 1.0;
              final t = 0.5 + 0.5 * math.sin(2 * math.pi * phase);
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: EmColors.primaryLight.withOpacity(0.35 + 0.65 * t)),
              );
            }),
          );
        },
      ),
    );
  }
}
