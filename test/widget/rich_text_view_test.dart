// Ported from eldermin-parent-mobile-app test/app/components/rich_text_view_test.dart — keep in sync.
import 'package:eldermin_teacher_app/app/components/external_link.dart';
import 'package:eldermin_teacher_app/app/components/rich_text_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Widget _host(String raw) => GetMaterialApp(home: Scaffold(body: SingleChildScrollView(child: RichTextView(raw))));

/// Taps the first link span of the rendered rich text.
void _tapLink(WidgetTester tester, String linkText) {
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    TextSpan? hit;
    w.text.visitChildren((s) {
      if (s is TextSpan && s.text == linkText) hit = s;
      return true;
    });
    if (hit != null) {
      final r = hit!.recognizer;
      if (r is! TapGestureRecognizer) fail('span "$linkText" is not tappable');
      r.onTap!();
      return;
    }
  }
  fail('no link span "$linkText"');
}

void main() {
  late List<Uri> launched;
  setUp(() {
    launched = [];
    ExternalLinks.launcher = (u) async {
      launched.add(u);
      return true;
    };
  });

  testWidgets('renders blocks from editor HTML with no raw tags', (tester) async {
    await tester.pumpWidget(_host('Hello<div>to <b>all</b></div><ul><li>one</li></ul><script>alert(1)</script>'));
    expect(find.textContaining('<'), findsNothing);
    expect(find.textContaining('alert'), findsNothing);
    expect(find.textContaining('to all', findRichText: true), findsOneWidget);
    expect(find.textContaining('one', findRichText: true), findsOneWidget);
  });

  testWidgets('a link asks first, then opens outside the app', (tester) async {
    await tester.pumpWidget(_host('<div>see <a href="https://school.edu/trip">the trip</a></div>'));
    _tapLink(tester, 'the trip');
    await tester.pumpAndSettle();
    expect(find.text('Open this link?'), findsOneWidget);
    expect(launched, isEmpty);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(launched.single.toString(), 'https://school.edu/trip');
  });

  testWidgets('cancelling the confirm opens nothing', (tester) async {
    await tester.pumpWidget(_host('<a href="https://school.edu/x">x link</a>'));
    _tapLink(tester, 'x link');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
  });

  testWidgets('a javascript: link is plain text, not tappable', (tester) async {
    await tester.pumpWidget(_host('<a href="javascript:alert(1)">bad</a>'));
    expect(find.textContaining('bad', findRichText: true), findsOneWidget);
    expect(() => _tapLink(tester, 'bad'), throwsA(isA<TestFailure>()));
  });

  testWidgets('mailto and tel links are allowed', (tester) async {
    await tester.pumpWidget(_host('<a href="mailto:office@school.edu">mail</a>'));
    _tapLink(tester, 'mail');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(launched.single.scheme, 'mailto');
  });
}
