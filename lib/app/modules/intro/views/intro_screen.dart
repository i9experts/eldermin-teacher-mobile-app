import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// First-launch carousel (3 slides), shown once: a full-bleed photo per slide
/// under the navy overlay. Swiping scrubs a crossfade between the photos with a
/// slight parallax (the PageController offset drives it); the text, dots and
/// buttons sit on the dark part of the overlay. Reduce motion: the photos just
/// crossfade when the page settles.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final IntroController c;
  final _pages = PageController();

  /// Logo tile (the splash logo lands here) and the controls under the text.
  static const double _tile = 64;
  static const double _dotsHeight = 8;
  static const double _buttonHeight = 52;

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

  /// Page offset as the backdrop / dots input: the live PageController offset
  /// (scrubbed by the finger) or, with reduce motion, the settled page.
  late final PageOffset _offset = PageOffset(_pages);
  final _settled = FixedProgress(0);

  static const _titleStyle = EmType.photoTitle;

  TextStyle get _bodyStyle => EmType.bodyLarge.copyWith(color: EmColors.primaryContainer, fontWeight: FontWeight.w400, height: 1.5);

  /// Height of the tallest slide's text at the current width and text scale.
  double _textHeight(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    var tallest = 0.0;
    for (final s in _slides) {
      double h(String t, TextStyle st) => (TextPainter(
            // merged like a Text widget does, so the measured wrap is the real one
            text: TextSpan(text: t, style: DefaultTextStyle.of(context).style.merge(st)),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: width))
              .height;
      final total = h(s.title, _titleStyle) + h(s.body, _bodyStyle);
      if (total > tallest) tallest = total;
    }
    return tallest + EmSpacing.s12;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = EmReduceMotion.of(context);
    final ValueListenable<double> progress = reduced ? _settled : _offset;
    final mq = MediaQuery.of(context);
    return EmScaffold(
      extendBody: false,
      wash: false,
      backgroundColor: EmColors.primaryDark,
      systemOverlay: SystemUiOverlayStyle.light,
      body: LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth - 2 * EmSpacing.s24;
        final bottomPad = mq.padding.bottom + EmSpacing.s16;
        // dots (24) + gap + button, the text above them, and a gap between
        final controls = EmSpacing.s24 + _dotsHeight + EmSpacing.s24 + _buttonHeight + bottomPad;
        final blockHeight = controls + EmSpacing.s16 + _textHeight(context, width);
        // the overlay's strong line sits above the whole block, whatever the text size
        final safeTop = EmPhotoOverlay.safeTopFor((box.maxHeight - blockHeight) / box.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            EmPhotoCarouselBackdrop(
              key: const Key('intro_scene'),
              images: [for (final a in EmAuthPhotos.slides) EmAuthPhotos.provider(a)],
              progress: progress,
              safeTop: safeTop,
            ),
            // the splash logo lands here
            PositionedDirectional(
              top: mq.padding.top + EmSpacing.s12,
              end: EmSpacing.s24,
              child: const EmLogoAnchor(child: EmLogoTile(size: _tile)),
            ),
            // slide text: a PageView over the photos, so the text moves with the finger
            Positioned.fill(
              bottom: controls,
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  c.page.value = i;
                  _settled.value = i.toDouble();
                },
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  // bottom-aligned; scrolls only when the screen is too short for the text (keyboard-sized heights)
                  return LayoutBuilder(
                    builder: (context, page) => SingleChildScrollView(
                      reverse: true,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: page.maxHeight),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s24, 0, EmSpacing.s24, EmSpacing.s16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(s.title, key: Key('intro_title_$i'), style: _titleStyle.copyWith(color: EmColors.onPrimaryDark)),
                                ),
                                const SizedBox(height: EmSpacing.s12),
                                Text(s.body, key: Key('intro_body_$i'), style: _bodyStyle),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: controls,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(EmSpacing.s24, 0, EmSpacing.s24, bottomPad),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Obx(() => Semantics(
                            label: 'Page ${c.page.value + 1} of ${_slides.length}',
                            excludeSemantics: true,
                            child: EmPhotoDots(key: const Key('intro_indicator'), count: _slides.length, progress: progress),
                          )),
                    ),
                    const SizedBox(height: EmSpacing.s24),
                    // Skip on the left, Next -> Get started (accent fill, ink label) on the right
                    EmOnDark(
                      child: Row(
                        children: [
                          TextButton(
                            key: const Key('intro_skip'),
                            onPressed: c.finish,
                            style: TextButton.styleFrom(minimumSize: const Size(64, _buttonHeight)),
                            child: Text('Skip', style: EmType.bodyLarge.copyWith(color: EmColors.onPrimaryDark)),
                          ),
                          const SizedBox(width: EmSpacing.s16),
                          Expanded(
                            // the buttons crossfade (same size, so it reads as the label morphing)
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
