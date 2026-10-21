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

  // ---- Step 0 (D9): sheets and dialogs host the bar too; only keyboards without a return key get it ----
  Widget opener(Future<void> Function(BuildContext) open) => MaterialApp(
        home: EmScaffold(body: Builder(builder: (c) => Center(child: ElevatedButton(key: const Key('open'), onPressed: () => open(c), child: const Text('open'))))),
      );

  Future<void> openIt(WidgetTester t, TargetPlatform p, Future<void> Function(BuildContext) open, {double keyboard = 300}) async {
    await boot(t, p, keyboard: keyboard, app: opener(open));
    await t.tap(find.byKey(const Key('open')));
    await t.pumpAndSettle();
  }

  const numeric = TextField(key: Key('n'), keyboardType: TextInputType.numberWithOptions(decimal: true));

  Future<void> sheetShow(BuildContext c) => EmBottomSheet.show<void>(c, title: 'Sheet', child: numeric);
  Future<void> sheetPanel(BuildContext c) => EmBottomSheet.showPanel<void>(c, builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: numeric)); // a panel body pads itself for the keyboard (as SheetFrame does)
  Future<void> dialog(BuildContext c) => showDialog<void>(context: c, builder: (_) => const EmDialog(title: 'Dialog', content: numeric, actions: [EmDialogAction(label: 'OK', onPressed: null)]));

  for (final e in {'EmBottomSheet.show': sheetShow, 'EmBottomSheet.showPanel': sheetPanel, 'EmDialog': dialog}.entries) {
    testWidgets('iOS: a numeric field in ${e.key} gets the bar, docked on the keyboard, the field stays above it', (t) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await openIt(t, TargetPlatform.iOS, e.value);
        expect(find.byKey(const Key('kbd_toolbar')), findsNothing, reason: 'nothing focused yet');
        await t.tap(find.byKey(const Key('n')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('kbd_toolbar')), findsOneWidget);
        final bar = t.getRect(find.byKey(const Key('kbd_toolbar')));
        expect(bar.bottom, closeTo(700 - 300, 0.5));
        expect(t.getRect(find.byKey(const Key('n'))).bottom, lessThanOrEqualTo(bar.top + 0.5), reason: 'the field is not under the bar');
        await t.tap(find.byKey(const Key('kbd_done')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('kbd_toolbar')), findsNothing, reason: 'Done closes the keyboard and removes the bar');
        expect(find.byKey(const Key('n')), findsOneWidget, reason: 'the sheet / dialog stays open');
      });
    });

    testWidgets('Android: a numeric field in ${e.key} gets no bar', (t) async {
      await onPlatform(TargetPlatform.android, () async {
        await openIt(t, TargetPlatform.android, e.value);
        await t.tap(find.byKey(const Key('n')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
      });
    });
  }

  testWidgets('iOS: closing the sheet while the bar is up removes the bar', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await openIt(t, TargetPlatform.iOS, sheetPanel);
      await t.tap(find.byKey(const Key('n')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('kbd_toolbar')), findsOneWidget);
      await t.tapAt(const Offset(180, 20)); // the barrier
      await t.pumpAndSettle();
      expect(find.byKey(const Key('n')), findsNothing);
      expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
    });
  });

  // keyboards that HAVE a return key never get the bar: in the screen body, a sheet and a dialog
  const returnKeyFields = <String, TextField>{
    'text': TextField(key: Key('n'), keyboardType: TextInputType.text),
    'email': TextField(key: Key('n'), keyboardType: TextInputType.emailAddress),
    'url': TextField(key: Key('n'), keyboardType: TextInputType.url),
    'password': TextField(key: Key('n'), obscureText: true),
    'multiline': TextField(key: Key('n'), keyboardType: TextInputType.multiline, minLines: 2, maxLines: 4),
    'name': TextField(key: Key('n'), keyboardType: TextInputType.name),
  };
  for (final f in returnKeyFields.entries) {
    testWidgets('iOS: a ${f.key} field never gets the bar (screen body, sheet, dialog)', (t) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await boot(t, TargetPlatform.iOS, app: MaterialApp(home: EmScaffold(body: ListView(children: [f.value]))));
        await t.tap(find.byKey(const Key('n')));
        await t.pump();
        expect(find.byKey(const Key('kbd_toolbar')), findsNothing, reason: 'screen body');
        for (final open in [
          (BuildContext c) => EmBottomSheet.show<void>(c, child: f.value),
          (BuildContext c) => showDialog<void>(context: c, builder: (_) => EmDialog(title: 'D', content: f.value, actions: const [])),
        ]) {
          await t.pumpWidget(opener(open));
          await t.tap(find.byKey(const Key('open')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('n')));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('kbd_toolbar')), findsNothing);
          await t.tapAt(const Offset(5, 5));
          await t.pumpAndSettle();
        }
      });
    });
  }

  testWidgets('iOS: a phone field gets the bar (no return key either)', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await boot(t, TargetPlatform.iOS, app: MaterialApp(home: EmScaffold(body: ListView(children: const [TextField(key: Key('n'), keyboardType: TextInputType.phone)]))));
      await t.tap(find.byKey(const Key('n')));
      await t.pump();
      expect(find.byKey(const Key('kbd_toolbar')), findsOneWidget);
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
