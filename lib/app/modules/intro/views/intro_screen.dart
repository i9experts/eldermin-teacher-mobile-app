import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
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
    return EmScaffold(
      extendBody: false,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: EmSpacing.s8, top: EmSpacing.s4),
                child: TextButton(
                  key: const Key('intro_skip'),
                  onPressed: c.finish,
                  child: Text('Skip', style: EmType.label.copyWith(color: EmColors.textSecondary, fontSize: 14)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => c.page.value = i,
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.screenH),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            EmHeroCard(
                              wave: true,
                              padding: const EdgeInsetsDirectional.symmetric(vertical: 36, horizontal: 24),
                              child: Center(
                                child: Container(
                                  width: 112,
                                  height: 112,
                                  decoration: const BoxDecoration(color: EmColors.surface, shape: BoxShape.circle),
                                  child: ExcludeSemantics(child: Icon(s.icon, color: EmColors.primary, size: 52)),
                                ),
                              ),
                            ),
                            const SizedBox(height: EmSpacing.s32),
                            Semantics(
                              header: true,
                              child: Text(s.title, textAlign: TextAlign.center, style: EmType.title.copyWith(color: EmColors.ink, fontSize: 24)),
                            ),
                            const SizedBox(height: EmSpacing.s12),
                            Text(s.body, textAlign: TextAlign.center, style: EmType.bodyLarge.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, fontSize: 15, height: 1.5)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Obx(() => Semantics(
                  label: 'Page ${c.page.value + 1} of ${_slides.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: EmMotion.normal,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: c.page.value == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.page.value == i ? EmColors.primary : EmColors.primaryLight,
                            borderRadius: EmRadius.pillAll,
                          ),
                        ),
                    ],
                  ),
                )),
            Padding(
              padding: const EdgeInsetsDirectional.all(EmSpacing.screenH),
              child: Obx(() => EmPrimaryButton(
                    label: c.page.value == IntroController.slideCount - 1 ? 'Get started' : 'Next',
                    onPressed: _next,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
