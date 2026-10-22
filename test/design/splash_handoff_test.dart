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
                    widget.withAnchor ? const EmLogoAnchor(child: EmLogomark(height: 72, semanticLabel: 'Dest')) : const SizedBox.shrink(),
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
    expect(t.getSize(logo).height, 72);
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

  testWidgets('reduce motion: static mark, no constellation, crossfade only (no flight), still exits', (t) async {
    final ready = ValueNotifier(false);
    final log = <String>[];
    await _pump(t, _Gate(ready: ready, flyToHeader: true, log: log), reduce: true);
    expect(find.byType(EmConstellation), findsNothing);
    await t.pump(ms(800));
    expect(t.widget<EmLogomark>(find.byType(EmLogomark)).drive, isNull, reason: 'static SVG, nothing animates');
    expect(find.byType(EmConstellation), findsNothing);
    ready.value = true;
    await t.pump();
    await t.pump(ms(16));
    await t.pump(ms(16));
    expect(EmLogoHandoff.flying.value, isFalse);
    expect(t.getCenter(find.byType(EmLogomark).last), const Offset(195, 422));
    await t.pump(ms(300));
    expect(log, ['exited']);
  });

  testWidgets('normal motion draws the constellation and the animated mark', (t) async {
    await _pump(t, _Gate(ready: ValueNotifier(false), flyToHeader: true, log: []));
    await t.pump(ms(500));
    expect(find.byType(EmConstellation), findsOneWidget);
    expect(t.widget<EmLogomark>(find.byType(EmLogomark)).drive, isNotNull);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });
}
