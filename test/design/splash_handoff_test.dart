// ignore_for_file: prefer_const_literals_to_create_immutables (the gate logs into the list it is given)
import 'package:eldermin_teacher_app/app/modules/splash/views/splash_screen.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';

/// Mirrors `_AuthGate`: the destination under a splash overlay that is told
/// when init is ready and removed when it has exited.
class _Gate extends StatefulWidget {
  const _Gate({required this.ready, required this.flyToHeader, this.withAnchor = true, required this.log});
  final ValueNotifier<bool> ready;
  final bool flyToHeader;
  final bool withAnchor;
  final List<String> log;
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _overlay = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.ready,
      builder: (context, ready, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Scaffold(
              key: const Key('destination'),
              body: Align(
                alignment: const Alignment(0, -0.5),
                child:
                    widget.withAnchor ? const EmLogoAnchor(child: EmLogoTile(size: 72)) : const SizedBox.shrink(),
              ),
            ),
          if (_overlay)
            SplashScreen(
              ready: ready,
              flyToHeader: widget.flyToHeader,
              onExited: () {
                widget.log.add('exited');
                setState(() => _overlay = false);
              },
            ),
        ],
      ),
    );
  }
}

Future<void> _pump(WidgetTester t, Widget gate, {bool reduce = false}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  addTearDown(EmLogoHandoff.reset);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduce), child: c!),
    home: gate,
  ));
}

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('init ready at 0: waits for the end of beat 1 (700 ms), flies onto the anchor, reveals the real logo', (t) async {
    final ready = ValueNotifier(false);
    final log = <String>[];
    await _pump(t, _Gate(ready: ready, flyToHeader: true, log: log));

    // splash only; nothing moves before init is ready
    expect(find.byKey(const Key('destination')), findsNothing);
    ready.value = true;
    await t.pump();
    await t.pump(ms(600));
    expect(EmLogoHandoff.flying.value, isFalse, reason: 'still inside beat 1');
    expect(t.getCenter(find.byType(EmLogomark).last), const Offset(195, 422));

    await t.pump(ms(150)); // 750: exit started
    await t.pump(ms(16));
    expect(EmLogoHandoff.flying.value, isTrue);

    // end of the flight (700 + 560 + a frame): overlay gone, destination logo visible and in place
    await t.pump(ms(700));
    expect(log, ['exited']);
    expect(find.byType(SplashScreen), findsNothing);
    expect(EmLogoHandoff.flying.value, isFalse);
    final logo = find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark));
    expect(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(Opacity)), findsNothing, reason: 'visible at rest');
    expect(t.getSize(logo).height, closeTo(72 * EmLogoTile.logoShare, 0.01));
  });

  testWidgets('mid-flight the flying logo is between the centre and the anchor, destination logo hidden', (t) async {
    final ready = ValueNotifier(false);
    await _pump(t, _Gate(ready: ready, flyToHeader: true, log: []));
    await t.pump(ms(1600)); // intro over: the exit starts at once
    ready.value = true;
    await t.pump();
    await t.pump(ms(20));
    await t.pump(ms(16));
    expect(EmLogoHandoff.flying.value, isTrue);
    await t.pump(ms(250));
    final flying = t.getRect(find.byType(EmLogomark).last);
    final anchor = t.getRect(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark)));
    expect(flying.height, lessThan(EmLogomark.splashHeight));
    expect(flying.height, greaterThan(anchor.height));
    expect(flying.center.dy, lessThan(422));
    expect(flying.center.dy, greaterThan(anchor.center.dy));
    expect(t.widget<Opacity>(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(Opacity)).first).opacity, 0,
        reason: 'hidden while the overlay flies');
    await t.pump(ms(700));
    // lands on the anchor: while landing both are the same rect (checked at the last frame before removal)
  });

  testWidgets('the flight ends exactly on the anchor rect', (t) async {
    final ready = ValueNotifier(false);
    await _pump(t, _Gate(ready: ready, flyToHeader: true, log: []));
    await t.pump(ms(1600));
    ready.value = true;
    await t.pump();
    await t.pump(ms(20));
    await t.pump(ms(16));
    await t.pump(ms(540)); // 1 frame before the 560 ms end
    final flying = t.getRect(find.byType(EmLogomark).last);
    final anchor = t.getRect(find.descendant(of: find.byType(EmLogoAnchor), matching: find.byType(EmLogomark)));
    expect(flying.center.dx, closeTo(anchor.center.dx, 1.5));
    expect(flying.center.dy, closeTo(anchor.center.dy, 1.5));
    expect(flying.height, closeTo(anchor.height, 1.5));
    await t.pump(ms(100));
  });

  testWidgets('init slower than the intro: exit starts immediately, total after init < 1.6 s', (t) async {
    final ready = ValueNotifier(false);
    final log = <String>[];
    await _pump(t, _Gate(ready: ready, flyToHeader: true, log: log));
    await t.pump(ms(3000));
    expect(t.getCenter(find.byType(EmLogomark)), const Offset(195, 422), reason: 'idle: still centred while waiting');
    ready.value = true;
    await t.pump();
    await t.pump(ms(20));
    await t.pump(ms(16));
    await t.pump(ms(600));
    expect(log, ['exited']);
  });

  testWidgets('no anchor and no header (home): fades in place, no flight', (t) async {
    final ready = ValueNotifier(false);
    final log = <String>[];
    await _pump(t, _Gate(ready: ready, flyToHeader: false, withAnchor: false, log: log));
    await t.pump(ms(1600));
    ready.value = true;
    await t.pump();
    await t.pump(ms(20));
    await t.pump(ms(16));
    await t.pump(ms(100));
    expect(EmLogoHandoff.flying.value, isFalse);
    expect(t.getCenter(find.byType(EmLogomark)).dy, closeTo(422, 0.5));
    await t.pump(ms(400));
    expect(log, ['exited']);
  });

  bool hasRings(WidgetTester t) => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is EmRippleRings).evaluate().isNotEmpty;

  testWidgets('reduce motion: no rings, no link motion, crossfade only (no flight), still exits', (t) async {
    final ready = ValueNotifier(false);
    final log = <String>[];
    await _pump(t, _Gate(ready: ready, flyToHeader: true, log: log), reduce: true);
    expect(hasRings(t), isFalse);
    await t.pump(ms(800));
    final drive = t.widget<EmLogomark>(find.byType(EmLogomark)).drive!;
    expect([drive.charge, drive.dashPhase, drive.pulse, drive.ripple], everyElement(isNull), reason: 'only the palette change, nothing travels or pulses');
    expect(hasRings(t), isFalse);
    ready.value = true;
    await t.pump();
    await t.pump(ms(16));
    await t.pump(ms(16));
    expect(EmLogoHandoff.flying.value, isFalse);
    expect(t.getCenter(find.byType(EmLogomark).last), const Offset(195, 422));
    await t.pump(ms(300));
    expect(log, ['exited']);
  });

  testWidgets('normal motion: two accent rings ripple out of the tile, the mark is animated, no constellation', (t) async {
    await _pump(t, _Gate(ready: ValueNotifier(false), flyToHeader: true, log: []));
    await t.pump(ms(900));
    expect(hasRings(t), isTrue);
    expect(EmRippleRings.count, 2);
    final drive = t.widget<EmLogomark>(find.byType(EmLogomark)).drive!;
    expect(drive.charge, isNotNull);
    expect(drive.pulse, isNotNull);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  group('slow-init caption', () {
    double captionOpacity(WidgetTester t) => t
        .widget<FadeTransition>(find.ancestor(of: find.byKey(const Key('splash_connecting')), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    testWidgets('fast init (exit well before 3 s): the caption never shows', (t) async {
      final ready = ValueNotifier(false);
      final log = <String>[];
      await _pump(t, _Gate(ready: ready, flyToHeader: true, log: log));
      await t.pump(ms(950)); // the minimum hold
      expect(captionOpacity(t), 0);
      ready.value = true;
      for (var i = 0; i < 200; i++) {
        await t.pump(ms(16));
        if (find.byKey(const Key('splash_connecting')).evaluate().isNotEmpty) expect(captionOpacity(t), 0);
      }
      expect(log, ['exited']);
    });

    testWidgets('slow init: appears at ~3 s, stays; the Loading label is there throughout', (t) async {
      final handle = t.ensureSemantics();
      final ready = ValueNotifier(false);
      await _pump(t, _Gate(ready: ready, flyToHeader: true, log: []));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await t.pump(ms(2900));
      expect(captionOpacity(t), 0);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await t.pump(ms(200)); // 3.1 s: fading in
      await t.pump(ms(400));
      expect(captionOpacity(t), 1);
      expect(t.widget<Text>(find.byKey(const Key('splash_connecting'))).data, 'Connecting…');
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      // AA on navy, from the token pair
      final style = t.widget<Text>(find.byKey(const Key('splash_connecting'))).style!;
      expect(style.color, EmColors.primaryLight);
      expect(contrastRatio(EmColors.primaryLight, EmColors.primaryDark), greaterThanOrEqualTo(4.5));
      // init finally completes: the caption goes with the rest of the text and the splash exits as usual
      ready.value = true;
      await t.pump();
      await t.pump(ms(20));
      await t.pump(ms(16));
      await t.pump(ms(700));
      expect(find.byType(SplashScreen), findsNothing);
      handle.dispose();
    });
  });
}
