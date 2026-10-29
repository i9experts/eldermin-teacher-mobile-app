import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/widgets/detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Widget _host(DetailSheetData d, {void Function(String)? open}) =>
    GetMaterialApp(home: Scaffold(body: SizedBox(height: 700, child: DetailBottomSheet(data: d, onOpenAttachment: open))));

void main() {
  testWidgets('renders title, status chip and fields', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(
      title: 'Museum trip',
      statusLabel: 'Pending',
      statusTone: EmTone.warning,
      fields: [DetailField('Category', 'Field trip'), DetailField('Due', '12 Nov 2026')],
    )));
    expect(find.text('Museum trip'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Field trip'), findsOneWidget);
    expect(find.text('12 Nov 2026'), findsOneWidget);
  });

  testWidgets('fields with null / blank values are hidden', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(
      title: 'T',
      fields: [DetailField('Has', 'yes'), DetailField('Null', null), DetailField('Blank', '   '), DetailField('Empty', '')],
    )));
    expect(find.text('Has'), findsOneWidget);
    expect(find.text('Null'), findsNothing);
    expect(find.text('Blank'), findsNothing);
    expect(find.text('Empty'), findsNothing);
  });

  testWidgets('no status chip, notice, long text, sections or attachments when not given', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(title: 'T', sections: [DetailSection('Response', [DetailField('By', null)])])));
    expect(find.byType(EmChip), findsNothing);
    expect(find.byKey(const Key('detail_notice')), findsNothing);
    expect(find.byKey(const Key('detail_long_text')), findsNothing);
    expect(find.byKey(const Key('detail_section_Response')), findsNothing);
    expect(find.text('Attachments'), findsNothing);
  });

  testWidgets('long text (plain and rich) and a section render', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(
      title: 'T',
      longTextLabel: 'Description',
      longText: 'Hello <b>there</b><div>second line</div>',
      longTextIsRich: true,
      sections: [DetailSection('Your response', [DetailField('Decision', 'Granted')])],
    )));
    expect(find.text('Description'), findsOneWidget);
    expect(find.textContaining('Hello there', findRichText: true), findsOneWidget);
    expect(find.textContaining('<b>'), findsNothing);
    expect(find.text('Your response'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);

    await tester.pumpWidget(_host(const DetailSheetData(title: 'T', longText: 'Plain <b>text</b>')));
    expect(find.byKey(const Key('detail_long_text')), findsOneWidget);
    expect(find.text('Plain <b>text</b>'), findsOneWidget); // plain mode never interprets markup
  });

  testWidgets('footer is shown when given and hidden when null', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(title: 'T', footer: Text('ACTIONS'))));
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.byKey(const Key('detail_sheet_footer')), findsOneWidget);

    await tester.pumpWidget(_host(const DetailSheetData(title: 'T')));
    expect(find.text('ACTIONS'), findsNothing);
    expect(find.byKey(const Key('detail_sheet_footer')), findsNothing);
  });

  testWidgets('notice is shown', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(title: 'T', notice: 'This request has expired')));
    expect(find.text('This request has expired'), findsOneWidget);
  });

  testWidgets('attachments are listed and open through the callback', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(_host(const DetailSheetData(title: 'T', attachments: [DetailAttachment('Slip 1', 'https://x.example/1.png'), DetailAttachment('Slip 2', 'https://x.example/2.png')]), open: opened.add));
    expect(find.text('Slip 1'), findsOneWidget);
    expect(find.text('Slip 2'), findsOneWidget);
    await tester.tap(find.text('Slip 2'));
    expect(opened, ['https://x.example/2.png']);
  });

  testWidgets('loading state shows a spinner and hides content and footer', (tester) async {
    await tester.pumpWidget(_host(const DetailSheetData(title: 'T', state: DetailSheetState.loading, footer: Text('ACTIONS'))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('T'), findsNothing);
    expect(find.text('ACTIONS'), findsNothing);
  });

  testWidgets('error state shows the message and Retry calls onRetry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(_host(DetailSheetData(title: 'T', state: DetailSheetState.error, errorMessage: 'No connection', onRetry: () => retried++)));
    expect(find.text('No connection'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('long content scrolls and the footer stays pinned', (tester) async {
    await tester.pumpWidget(_host(DetailSheetData(title: 'T', longText: List.filled(80, 'A long paragraph of text.').join('\n\n'), footer: const Text('ACTIONS'))));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('T'), findsNothing); // header scrolled away
  });

  testWidgets('show() opens a draggable modal sheet', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: Builder(builder: (ctx) => Scaffold(body: TextButton(onPressed: () => DetailBottomSheet.show<void>(ctx, data: () => const DetailSheetData(title: 'Opened', footer: Text('F'))), child: const Text('go'))))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Opened'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });

  group('fitContent sizing (show)', () {
    const day = DetailSheetData(title: 'Tue 27 Oct 2026', statusLabel: 'Present', fields: [DetailField('Check-in', '08:02')], footer: SizedBox(key: Key('foot_btn'), height: 48, width: double.infinity));

    Future<double> open(WidgetTester t, DetailSheetData d, {required bool fit, double w = 390, double h = 844, double scale = 1.0, bool settle = true}) async {
      await t.binding.setSurfaceSize(Size(w, h));
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        t.binding.setSurfaceSize(null);
        t.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await t.pumpWidget(GetMaterialApp(home: Builder(builder: (ctx) => Scaffold(body: TextButton(onPressed: () => DetailBottomSheet.show<void>(ctx, data: () => d, fitContent: fit), child: const Text('go'))))));
      await t.tap(find.text('go'));
      settle ? await t.pumpAndSettle() : await t.pump(const Duration(milliseconds: 500));
      return t.getSize(find.byKey(const Key('detail_sheet'))).height;
    }

    testWidgets('default stays the 75% draggable sheet', (t) async {
      final hDefault = await open(t, day, fit: false);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(hDefault, closeTo(844 * 0.75, 40));
    });

    testWidgets('fitContent hugs a short sheet, footer visible and tappable', (t) async {
      final hFit = await open(t, day, fit: true);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(hFit, lessThan(300));
      expect(hFit, greaterThan(120));
      expect(t.getRect(find.byKey(const Key('foot_btn'))).bottom, lessThanOrEqualTo(844));
      await t.tap(find.byKey(const Key('foot_btn')), warnIfMissed: true);
    });

    testWidgets('fitContent caps at 85% and scrolls long content', (t) async {
      final hFit = await open(t, DetailSheetData(title: 'T', longText: List.filled(80, 'A long paragraph of text.').join('\n\n'), footer: const Text('ACTIONS')), fit: true);
      expect(hFit, lessThanOrEqualTo(844 * 0.85));
      expect(hFit, greaterThan(844 * 0.6));
      expect(t.takeException(), isNull);
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pump();
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('T'), findsNothing);
    });

    testWidgets('fitContent at 320dp x 1.3 text scale has no overflow', (t) async {
      await open(t, day, fit: true, w: 320, scale: 1.3);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('foot_btn')), findsOneWidget);
    });

    testWidgets('fitContent loading state works', (t) async {
      await open(t, const DetailSheetData(title: 'T', state: DetailSheetState.loading), fit: true, settle: false);
      expect(t.takeException(), isNull);
      expect(find.byType(EmLoading), findsOneWidget);
    });
  });
}
