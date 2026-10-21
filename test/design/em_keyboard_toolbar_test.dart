import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';
import '../support/layout_probe.dart';

/// Step 0 of D8: the iOS number pad has no return key, so [EmKeyboardAccessory] (inside `EmScaffold`) docks Prev / Next / Done
/// above the keyboard on iOS only, for numeric-only fields only.
void main() {
  setUpAll(loadDesignFonts);

  Widget screen({TextInputType first = TextInputType.number}) => MaterialApp(
        home: EmScaffold(
          body: ListView(children: [
            TextField(key: const Key('f1'), keyboardType: first, textInputAction: TextInputAction.next),
            const ExcludeFocus(child: TextButton(onPressed: null, child: Text('toggle'))),
            const TextField(key: Key('f2'), keyboardType: TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.next),
            const TextField(key: Key('f3'), keyboardType: TextInputType.number),
            const TextField(key: Key('text'), keyboardType: TextInputType.text),
          ]),
        ),
      );

  Future<void> boot(WidgetTester t, TargetPlatform platform, {double keyboard = 300, double width = 360, double scale = 1.0, Widget? app}) async {
    debugDefaultTargetPlatformOverride = platform;
    t.view.physicalSize = Size(width * 3, 700 * 3);
    t.view.devicePixelRatio = 3;
    t.platformDispatcher.textScaleFactorTestValue = scale;
    t.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await t.pumpWidget(app ?? screen());
    await t.pump();
  }

  bool hasFocus(WidgetTester t, String key) => t.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).focusNode.hasFocus;

  Future<void> focus(WidgetTester t, String key) async {
    await t.tap(find.byKey(Key(key)));
    await t.pump();
  }

  Future<void> onPlatform(TargetPlatform p, Future<void> Function() body) async {
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('iOS: the toolbar appears above the keyboard when a numeric field has focus', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS);
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing, reason: 'nothing focused yet');
      await focus(t, 'f1');
      expect(find.byKey(const Key('kbd_toolbar')), findsOneWidget);
      final bar = t.getRect(find.byKey(const Key('kbd_toolbar')));
      expect(bar.bottom, closeTo(700 - 300, 0.5), reason: 'docked directly on the keyboard');
      expect(bar.height, greaterThanOrEqualTo(EmSpacing.minTouch));
      for (final k in ['kbd_prev', 'kbd_next', 'kbd_done']) {
        expect(t.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(EmSpacing.minTouch), reason: k);
      }
      expect(find.byTooltip('Previous field'), findsOneWidget);
      expect(find.byTooltip('Next field'), findsOneWidget);
    });
  });

  testWidgets('iOS: the focused field stays above the toolbar (the scaffold sees the bar as keyboard inset)', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS, keyboard: 520);
      await focus(t, 'f3');
      await t.pumpAndSettle();
      final bar = t.getRect(find.byKey(const Key('kbd_toolbar')));
      expect(t.getRect(find.byKey(const Key('f3'))).bottom, lessThanOrEqualTo(bar.top + 0.5));
    });
  });

  testWidgets('Android: no toolbar for the same field and keyboard', (t) async {
    await onPlatform(TargetPlatform.android, () async {
      await boot(t, TargetPlatform.android);
      await focus(t, 'f1');
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
    });
  });

  testWidgets('iOS: not shown for a text field, nor when the keyboard is closed', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS);
      await focus(t, 'text');
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
      await focus(t, 'f1');
      expect(find.byKey(const Key('kbd_toolbar')), findsOneWidget);
      t.view.viewInsets = FakeViewPadding.zero;
      await t.pump();
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
    });
  });

  testWidgets('iOS: Next / Prev follow the field order and skip the ExcludeFocus toggle; focus (and the keyboard) is kept', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS);
      await focus(t, 'f1');
      await t.tap(find.byKey(const Key('kbd_next')));
      await t.pump();
      expect(hasFocus(t, 'f2'), isTrue, reason: 'the toggle between f1 and f2 is skipped');
      expect(find.byKey(const Key('kbd_toolbar')), findsOneWidget, reason: 'the bar stays while a numeric field has focus');
      await t.tap(find.byKey(const Key('kbd_next')));
      await t.pump();
      expect(hasFocus(t, 'f3'), isTrue);
      await t.tap(find.byKey(const Key('kbd_prev')));
      await t.pump();
      expect(hasFocus(t, 'f2'), isTrue);
      await t.tap(find.byKey(const Key('kbd_prev')));
      await t.pump();
      expect(hasFocus(t, 'f1'), isTrue);
    });
  });

  testWidgets('iOS: Done unfocuses the field and the bar goes away', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS);
      await focus(t, 'f2');
      await t.tap(find.byKey(const Key('kbd_done')));
      await t.pump();
      expect(hasFocus(t, 'f2'), isFalse);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>(), isNull);
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
    });
  });

  testWidgets('iOS: a dialog above the screen with its own numeric field does not get the screen\'s toolbar', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS);
      showDialog<void>(context: t.element(find.byKey(const Key('f1'))), builder: (_) => const AlertDialog(content: TextField(key: Key('dlg'), keyboardType: TextInputType.number)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('dlg')));
      await t.pump();
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
    });
  });

  for (final w in probeWidths) {
    testWidgets('iOS: the toolbar fits at ${w.toInt()} dp x 1.3 (no overflow, buttons inside the screen)', (t) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await boot(t, TargetPlatform.iOS, width: w, scale: 1.3);
        await focus(t, 'f1');
        expectNoLayoutError(t);
        for (final k in ['kbd_prev', 'kbd_next', 'kbd_done']) {
          expectInsideScreen(t, find.byKey(Key(k)), w);
        }
      });
    });
  }
}
