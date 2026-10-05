import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../components/custom_button.dart';
import '../../../components/custom_text.dart';
import '../bindings/intro_binding.dart';
import '../controllers/intro_controller.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = [
  _Slide(Icons.school_rounded, 'Your classroom, in your pocket',
      'Timetable, classes, homework and marks - the tools you use every day, on your phone.'),
  _Slide(Icons.forum_rounded, 'Stay close to families',
      'Message parents, follow school notices and keep up with meetings and events.'),
  _Slide(Icons.lock_rounded, 'Your school account, kept safe',
      'Sign in with the same email and password you use on the Eldermin web portal.'),
];

/// First-launch carousel (3 slides), shown once.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final IntroController c;
  final _pages = PageController();

  @override
  void initState() {
    super.initState();
    IntroBinding().dependencies();
    c = Get.find<IntroController>();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (c.isLast) {
      c.finish();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('intro_skip'),
                onPressed: c.finish,
                child: const CustomText(text: 'Skip', color: AppColors.muted, fontSize: 13),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => c.page.value = i,
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(
                              colors: [AppColors.primaryColor, AppColors.primaryColorLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          shape: BoxShape.circle),
                          child: Icon(s.icon, color: Colors.white, size: 60),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        CustomText(
                            text: s.title,
                            textAlign: TextAlign.center,
                            color: AppColors.primaryColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800),
                        const SizedBox(height: AppSpacing.md),
                        CustomText(
                            text: s.body,
                            textAlign: TextAlign.center,
                            color: AppColors.muted,
                            fontSize: 14,
                            height: 1.4),
                      ],
                    ),
                  );
                },
              ),
            ),
            Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: c.page.value == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.page.value == i ? AppColors.primaryColor : AppColors.line,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                  ],
                )),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Obx(() => CustomButton(
                    label: c.page.value == IntroController.slideCount - 1 ? 'Get started' : 'Next',
                    width: double.infinity,
                    color: AppColors.primaryColor,
                    onPressed: _next,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
