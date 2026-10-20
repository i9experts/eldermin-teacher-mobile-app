import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';

/// D5: the migrated app-bar / dialog / sheet layer at the widths and text scales the owner asked for.
void main() {
  setUpAll(loadDesignFonts);

  const longTitle = 'A very long screen title that has to truncate instead of pushing the actions away';
  Widget bar({bool withTabs = false}) => Material(
        child: EmScaffold(
          appBar: EmAppBar(
            title: longTitle,
            onBack: () {},
            actions: [EmIconCircleButton(icon: Icons.upload_file_rounded, semanticLabel: 'Upload', tooltip: 'Upload', onTap: () {})],
            trailing: EmIconCircleButton(icon: Icons.done_all_rounded, semanticLabel: 'Mark all read', tooltip: 'Mark all read', onTap: () {}),
            bottom: withTabs ? const PreferredSize(preferredSize: Size.fromHeight(48), child: SizedBox(height: 48)) : null,
          ),
          body: const SizedBox.expand(),
        ),
      );

  group('EmAppBar matrix', () {
    for (final w in [320.0, 360.0, 375.0, 430.0]) {
      for (final s in [1.0, 1.3]) {
        for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
          testWidgets('width $w, scale $s, $dir: title ellipsizes, both actions stay on screen', (t) async {
            await pumpEm(t, bar(), width: w, textScale: s, dir: dir, scaffold: false);
            expectNoLayoutErrors(t);
            for (final label in ['Upload', 'Mark all read']) {
              final r = t.getRect(find.byTooltip(label));
              expect(r.left >= 0 && r.right <= w, isTrue, reason: '$label at $r is inside the $w dp screen');
              expect(r.width >= 48 && r.height >= 48, isTrue);
            }
            final title = t.widget<Text>(find.text(longTitle));
            expect(title.maxLines, 1);
            expect(title.overflow, TextOverflow.ellipsis);
          });
        }
      }
    }
    testWidgets('bottom slot (tabs) is counted in the bar height', (t) async {
      await pumpEm(t, bar(withTabs: true), scaffold: false);
      expectNoLayoutErrors(t);
      expect(const EmAppBar(title: 'x', bottom: PreferredSize(preferredSize: Size.fromHeight(48), child: SizedBox())).preferredSize.height, 72 + 48);
    });
  });

  group('EmDialog', () {
    for (final s in [1.0, 1.3]) {
      testWidgets('320 dp, scale $s: long title + message + two actions lay out', (t) async {
        await pumpEm(
          t,
          Builder(
            builder: (c) => TextButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (_) => EmDialog(
                  title: 'Discard unsaved marks for the whole class register?',
                  message: 'You have attendance marks that are not saved yet. This cannot be undone once you leave this screen.',
                  actions: [
                    EmDialogAction(label: 'Keep editing', onPressed: () {}),
                    EmDialogAction(label: 'Discard', tone: EmDialogTone.destructive, onPressed: () {}),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
          width: 320,
          textScale: s,
        );
        await t.tap(find.text('open'));
        await t.pump(const Duration(seconds: 1));
        expectNoLayoutErrors(t);
        expect(find.byType(AlertDialog), findsOneWidget);
        expectMinTouch(t, find.widgetWithText(TextButton, 'Discard'));
      });
    }
  });

  group('EmBottomSheet.showPanel', () {
    testWidgets('fixed-height panel with an Expanded list, then dismissed', (t) async {
      await pumpEm(
        t,
        Builder(
          builder: (c) => TextButton(
            onPressed: () => EmBottomSheet.showPanel<void>(c, heightFactor: 0.85, builder: (_) => ListView(children: [for (var i = 0; i < 30; i++) ListTile(title: Text('row $i'))])),
            child: const Text('open'),
          ),
        ),
        width: 320,
        textScale: 1.3,
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expectNoLayoutErrors(t);
      expect(find.text('row 0'), findsOneWidget);
      await t.tapAt(const Offset(160, 20));
      await t.pumpAndSettle();
      expect(find.text('row 0'), findsNothing);
    });
  });
}
