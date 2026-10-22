import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';

/// The accent submit buttons: their label / spinner / check must read AA on the accent fill.
/// (The navy `onAccent` is 4.43:1 on it and is for icons / large text only: never used here.)
void main() {
  setUpAll(loadDesignFonts);

  test('the content colour is ink: >= 4.5:1 (AA, normal text) and not the navy onAccent', () {
    expect(EmMorphButton.fill, EmColors.accent);
    expect(EmMorphButton.content, EmColors.ink);
    expect(EmMorphButton.content, isNot(EmColors.onAccent));
    expect(contrastRatio(EmMorphButton.content, EmMorphButton.fill), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(EmColors.onAccent, EmColors.accent), lessThan(4.5), reason: 'the reason onAccent must not label a button');
  });

  testWidgets('what is actually painted: label, spinner and check on the fill, every phase', (t) async {
    for (final phase in EmMorphPhase.values) {
      await pumpEm(t, EmMorphButton(label: 'Sign in', phase: phase, onPressed: () {}), settle: false);
      await t.pump(const Duration(milliseconds: 600));
      final fill = (t.widget<AnimatedContainer>(find.descendant(of: find.byType(EmMorphButton), matching: find.byType(AnimatedContainer))).decoration! as BoxDecoration).color!;
      expect(fill, EmColors.accent, reason: '$phase');
      switch (phase) {
        case EmMorphPhase.idle:
          final label = t.widget<Text>(find.text('Sign in')).style!;
          expect(contrastRatio(label.color!, fill), greaterThanOrEqualTo(4.5));
          expect(label.fontWeight, FontWeight.w700);
        case EmMorphPhase.loading:
          expect(contrastRatio(t.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).color!, fill), greaterThanOrEqualTo(4.5));
        case EmMorphPhase.success:
          expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is CheckPainter), findsOneWidget);
      }
    }
  });

  testWidgets('the accent primary button on the blue card (EmPrimaryButton under EmOnDark) uses the same pair', (t) async {
    await pumpEm(t, const EmOnDark(child: EmPrimaryButton(label: 'Send reset link', onPressed: null)), settle: false);
    // disabled shows the disabled colours (exempt); enabled is checked below
    await pumpEm(t, EmOnDark(child: EmPrimaryButton(label: 'Send reset link', onPressed: () {})), settle: false);
    final style = t.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
    final bg = style.backgroundColor!.resolve({})!;
    final fg = style.foregroundColor!.resolve({})!;
    expect(bg, EmColors.accent);
    expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5));
  });
}
