import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../components/common_image_view.dart';
import '../../../components/custom_text.dart';
import '../../../config/app_images.dart';

/// The root screen shown while [AuthController] resolves its bootstrap
/// (token check + profile fetch). Purely presentational - the
/// swap away from this screen is driven entirely by `_AuthGate` in
/// main.dart reacting to `AuthController.status`, matching the same
/// gradient/ring language as [HeroCard] so the very first frame the
/// user sees already looks like the rest of the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop;
  late final Animation<double> _ringFade;
  late final Animation<double> _ringScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _ringFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut));
    _ringScale = Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));

    _logoFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.05, 0.5, curve: Curves.easeOut));
    _logoScale = Tween(begin: 0.55, end: 1.0).animate(CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.05, 0.6, curve: Curves.easeOutBack)));

    _titleFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOut));
    _titleSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic)));

    _taglineFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.6, 0.95, curve: Curves.easeOut));
    _loaderFade = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -70,
              top: -70,
              child: FadeTransition(
                opacity: _ringFade,
                child: ScaleTransition(
                  scale: _ringScale,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.07), width: 42),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -80,
              child: FadeTransition(
                opacity: _ringFade,
                child: ScaleTransition(
                  scale: _ringScale,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.05), width: 46),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: 128,
                          height: 128,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primaryColor.withOpacity(0.8)),
                          ),
                          child: const CommonImageView(
                            imagePath: AppImages.fullLogo,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: const CustomText(
                          text: 'Eldermin Teacher',
                          textAlign: TextAlign.center,
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl),
                        child: CustomText(
                          text: 'Your classroom, in your pocket.',
                          textAlign: TextAlign.center,
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13.5,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: _loaderFade,
                      child: _LoadingDots(loop: _loop),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three softly pulsing dots, phase-offset via a repeating [loop]
/// controller - a lighter-weight "still working" affordance than a
/// spinner, consistent with the calm tone of the rest of the splash.
class _LoadingDots extends StatelessWidget {
  final AnimationController loop;
  const _LoadingDots({required this.loop});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
                color: Colors.white.withOpacity(0.35 + 0.55 * t),
              ),
            );
          }),
        );
      },
    );
  }
}
