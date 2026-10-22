import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/design/design.dart';
import '../bindings/intro_binding.dart';
import '../controllers/intro_controller.dart';

class _Slide {
  final String title;
  final String body;
  const _Slide(this.title, this.body);
}

const _slides = [
  _Slide('Your classroom, in your pocket', 'Timetable, classes, homework and marks - the tools you use every day, on your phone.'),
  _Slide('Stay close to families', 'Message parents, follow school notices and keep up with meetings and events.'),
  _Slide('Your school account, kept safe', 'Sign in with the same email and password you use on the Eldermin web portal.'),
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

  /// Page offset as the scene / indicator input: the live PageController
  /// offset (scrubbed by the finger) or, with reduce motion, the settled page.
  late final PageOffset _offset = PageOffset(_pages);
  final _settled = FixedProgress(0);

  @override
  Widget build(BuildContext context) {
    final reduced = EmReduceMotion.of(context);
    final ValueListenable<double> progress = reduced ? _settled : _offset;
    return EmScaffold(
      extendBody: false,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          // art takes what is left after header, text (>= 140), indicator and button; hidden when there is no room (keyboard-sized screens)
          final room = box.maxHeight - (56 + 140 + 24 + 84);
          final sceneHeight = room.clamp(0.0, math.min(300.0, box.maxHeight * 0.34)).toDouble();
          return Column(
            children: [
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // the splash logo lands here
                    const EmLogoAnchor(child: EmLogomark(height: 36, semanticLabel: 'Eldermin')),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: EmSpacing.s8),
                        child: TextButton(
                          key: const Key('intro_skip'),
                          onPressed: c.finish,
                          child: Text('Skip', style: EmType.body.copyWith(color: EmColors.textSecondary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (sceneHeight >= 96)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.screenH),
                  child: SizedBox(
                    height: sceneHeight,
                    child: EmHeroCard(
                      wave: true,
                      padding: const EdgeInsetsDirectional.all(EmSpacing.s16),
                      // scrubbed by the page offset; with reduce motion the art crossfades per page
                      child: reduced
                          ? Obx(() => AnimatedSwitcher(
                                duration: EmMotion.crossfade,
                                child: EmNodeScene(
                                  key: ValueKey(c.page.value),
                                  layouts: EmScenes.intro,
                                  roles: EmScenes.introRoles,
                                  progress: FixedProgress(c.page.value.toDouble()),
                                ),
                              ))
                          : EmNodeScene(
                              key: const Key('intro_scene'), layouts: EmScenes.intro, roles: EmScenes.introRoles, progress: progress),
                    ),
                  ),
                ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length,
                  onPageChanged: (i) {
                    c.page.value = i;
                    _settled.value = i.toDouble();
                  },
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
                              Semantics(
                                header: true,
                                child: Text(s.title, textAlign: TextAlign.center, style: EmType.title.copyWith(color: EmColors.ink)),
                              ),
                              const SizedBox(height: EmSpacing.s12),
                              Text(s.body,
                                  textAlign: TextAlign.center,
                                  style:
                                      EmType.bodyLarge.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400, height: 1.5)),
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
                    child: EmNodeIndicator(key: const Key('intro_indicator'), count: _slides.length, progress: progress),
                  )),
              Padding(
                padding: const EdgeInsetsDirectional.all(EmSpacing.screenH),
                // Next -> Get started: the buttons crossfade (same size, so it reads as the label morphing)
                child: Obx(() {
                  final last = c.page.value == IntroController.slideCount - 1;
                  return AnimatedSwitcher(
                    duration: EmMotion.normal,
                    child: EmPrimaryButton(
                      key: ValueKey(last),
                      label: last ? 'Get started' : 'Next',
                      icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}
