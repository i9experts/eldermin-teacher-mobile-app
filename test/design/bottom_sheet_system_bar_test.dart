import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';

/// Android gesture / 3-button bar: the app draws edge-to-edge, so a modal sheet must lift its content above the bottom system inset.
const _bar = 48.0;

Widget _app(Widget Function(BuildContext) opener) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24, bottom: _bar),
          viewPadding: const EdgeInsets.only(top: 24, bottom: _bar),
        ),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: opener)),
    );

void main() {
  const footerKey = Key('sheet_footer');

  testWidgets('EmBottomSheet.show keeps the footer above the system bar', (tester) async {
    await tester.pumpWidget(_app((c) => TextButton(
          onPressed: () => EmBottomSheet.show<void>(c, title: 'T', child: const Text('body'), footer: const SizedBox(key: footerKey, height: 40)),
          child: const Text('open'),
        )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(find.byKey(footerKey)).dy, lessThanOrEqualTo(screenH - _bar));
  });

  testWidgets('EmBottomSheet.showPanel keeps its content above the system bar', (tester) async {
    await tester.pumpWidget(_app((c) => TextButton(
          onPressed: () => EmBottomSheet.showPanel<void>(c, builder: (_) => const SizedBox(key: footerKey, height: 40)),
          child: const Text('open'),
        )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(find.byKey(footerKey)).dy, lessThanOrEqualTo(screenH - _bar));
  });
}
