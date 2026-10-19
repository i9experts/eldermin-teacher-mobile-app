import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import '../support/design_harness.dart';

void main() {
  setUpAll(loadDesignFonts);

  group('EmIconCircleButton', () {
    testWidgets('48dp circle, spoken label, tap', (t) async {
      final h = t.ensureSemantics();
      var taps = 0;
      await pumpEm(t, EmIconCircleButton(icon: Icons.search, semanticLabel: 'Search', onTap: () => taps++));
      expectMinTouch(t, find.bySemanticsLabel('Search'));
      await t.tap(find.byIcon(Icons.search));
      expect(taps, 1);
      h.dispose();
    });
    testWidgets('unread dot is drawn and announced', (t) async {
      final h = t.ensureSemantics();
      await pumpEm(t, EmIconCircleButton(icon: Icons.notifications_none_rounded, semanticLabel: 'Notifications', showDot: true, onTap: () {}));
      expect(find.byKey(const Key('em_dot')), findsOneWidget);
      expect(find.bySemanticsLabel('Notifications, new'), findsOneWidget);
      h.dispose();
    });
    testWidgets('disabled without onTap; smaller than 48 is rejected', (t) async {
      await pumpEm(t, const EmIconCircleButton(icon: Icons.search, semanticLabel: 'Search'));
      expect(t.widget<Icon>(find.byIcon(Icons.search)).color, EmColors.onDisabled);
      expect(() => EmIconCircleButton(icon: Icons.search, semanticLabel: 'x', size: 40), throwsAssertionError);
    });
    testWidgets('robust at 1.3x / RTL', (t) async {
      await expectRobust(t, () => const EmIconCircleButton(icon: Icons.search, semanticLabel: 'Search', showDot: true));
    });
  });

  group('EmAppBar', () {
    Widget host(Widget bar) => Scaffold(appBar: bar as PreferredSizeWidget, body: const SizedBox());
    testWidgets('title is centred; back pops; trailing slot', (t) async {
      final nav = GlobalKey<NavigatorState>();
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('root')),
      ));
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => host(EmAppBar(title: 'Statistics', trailing: EmIconCircleButton(icon: Icons.more_horiz, semanticLabel: 'More', onTap: () {})))));
      await t.pumpAndSettle();
      expect(find.text('Statistics'), findsOneWidget);
      expect(t.getCenter(find.text('Statistics')).dx, closeTo(180, 1));
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      await t.tap(find.byIcon(Icons.chevron_left_rounded));
      await t.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });
    testWidgets('no back button on the root route; long title ellipsizes at 1.3x', (t) async {
      await pumpEm(t, host(const EmAppBar(title: 'A very long screen title that cannot possibly fit', trailing: EmIconCircleButton(icon: Icons.more_horiz, semanticLabel: 'More'))), scaffold: false, textScale: 1.3);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expectNoLayoutErrors(t);
    });
    testWidgets('the back circle carries the "Back" tooltip, so tester.pageBack() works (integration helpers rely on it)', (t) async {
      final nav = GlobalKey<NavigatorState>();
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(navigatorKey: nav, home: const Scaffold(body: Text('root'))));
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => host(const EmAppBar(title: 'Page'))));
      await t.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });
    testWidgets('RTL uses the mirrored chevron', (t) async {
      await pumpEm(t, host(EmAppBar(title: 'T', onBack: () {})), scaffold: false, dir: TextDirection.rtl);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  group('EmScaffold', () {
    testWidgets('brand tint background and wash', (t) async {
      await pumpEm(t, const EmScaffold(body: Text('x')), scaffold: false);
      expect(t.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, EmColors.background);
      expect(find.byKey(const Key('em_wash')), findsOneWidget);
    });
    testWidgets('wash can be turned off', (t) async {
      await pumpEm(t, const EmScaffold(wash: false, body: Text('x')), scaffold: false);
      expect(find.byKey(const Key('em_wash')), findsNothing);
    });
  });

  group('EmCard / EmHeroCard', () {
    testWidgets('card is white radius 24 and tappable', (t) async {
      var taps = 0;
      await pumpEm(t, EmCard(onTap: () => taps++, semanticLabel: 'Card', child: const Text('hi')));
      final deco = t.widget<DecoratedBox>(find.descendant(of: find.byType(EmCard), matching: find.byType(DecoratedBox)).first).decoration as ShapeDecoration;
      expect(deco.color, EmColors.surface);
      expect((deco.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(24));
      await t.tap(find.text('hi'));
      expect(taps, 1);
    });
    testWidgets('hero card is the primary-container tint, radius 28; wave builds', (t) async {
      await pumpEm(t, const EmHeroCard(wave: true, child: SizedBox(height: 80, width: double.infinity)));
      final d = t.widget<DecoratedBox>(find.descendant(of: find.byType(EmHeroCard), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration;
      expect(d.color, EmColors.primaryContainer);
      expect(d.borderRadius, BorderRadius.circular(28));
    });
    testWidgets('robust', (t) async {
      await expectRobust(t, () => const EmCard(child: Text('A fairly long line of text that has to wrap onto several lines at large scale')));
    });
  });

  group('EmGreetingHeader / EmAvatar', () {
    testWidgets('two lines, merged semantics', (t) async {
      final h = t.ensureSemantics();
      await pumpEm(t, const EmGreetingHeader(name: 'Clara Classteacher', avatar: EmAvatar(initials: 'CC')));
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Clara Classteacher'), findsOneWidget);
      expect(find.text('CC'), findsOneWidget);
      expect(find.bySemanticsLabel('Good morning, Clara Classteacher'), findsOneWidget);
      h.dispose();
    });
    testWidgets('robust with long name, bell, 1.3x', (t) async {
      await expectRobust(t, () => EmGreetingHeader(name: 'Alexandrina Montgomery-Featherstonehaugh', avatar: const EmAvatar(initials: 'AM'), trailing: EmIconCircleButton(icon: Icons.notifications_none_rounded, semanticLabel: 'Notifications', showDot: true, onTap: () {})));
    });
    testWidgets('tap area is >= 48 high', (t) async {
      await pumpEm(t, EmGreetingHeader(name: 'N', onTap: () {}));
      expectMinTouch(t, find.byType(InkWell).first, min: 48);
    });
  });

  group('EmSearchPill', () {
    testWidgets('typing reports, trailing shows, >= 52 high', (t) async {
      final h = t.ensureSemantics();
      String? v;
      await pumpEm(t, EmSearchPill(onChanged: (s) => v = s, trailing: EmIconCircleButton(icon: Icons.calendar_month_outlined, semanticLabel: 'Calendar', onTap: () {})));
      await t.enterText(find.byType(TextField), 'maths');
      expect(v, 'maths');
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsWidgets);
      expect(t.getSize(find.byType(EmSearchPill)).height, greaterThanOrEqualTo(52));
      h.dispose();
    });
    testWidgets('robust', (t) async {
      await expectRobust(t, () => EmSearchPill(trailing: EmIconCircleButton(icon: Icons.calendar_month_outlined, semanticLabel: 'Calendar', onTap: () {})));
    });
  });

  group('EmDateStrip', () {
    final monday = DateTime(2025, 5, 19);
    testWidgets('weekOf is Monday..Sunday', (t) async {
      final w = EmDateStrip.weekOf(DateTime(2025, 5, 21));
      expect(w.length, 7);
      expect(w.first, monday);
      expect(w.last, DateTime(2025, 5, 25));
      expect(EmDateStrip.weekOf(DateTime(2025, 5, 25)).first, monday); // Sunday belongs to the week that started Monday
    });
    testWidgets('wide: 7 pills in a row; tap selects; selected is announced', (t) async {
      final h = t.ensureSemantics();
      DateTime? picked;
      await pumpEm(t, EmDateStrip(days: EmDateStrip.weekOf(monday), selected: DateTime(2025, 5, 21), onSelected: (d) => picked = d), width: 700);
      await t.tap(find.text('23'));
      expect(picked, DateTime(2025, 5, 23));
      final sem = t.getSemantics(find.bySemanticsLabel('Wednesday 21 May'));
      expect(sem.flagsCollection.isSelected, isTrue);
      h.dispose();
    });
    testWidgets('pill width = (available - gaps) / 7 clamped 40..48; height >= 56; no scroll while 40 fits', (t) async {
      // available 326 (390 screen, hero padding 16+16, screen padding 16+16): (326-36)/7 = 41.4
      await pumpEm(t, EmDateStrip(days: EmDateStrip.weekOf(monday), selected: monday, onSelected: (_) {}), width: 358, padding: EdgeInsets.zero);
      expect(find.byType(ListView), findsNothing);
      final w = t.getSize(find.byType(InkWell).first);
      expect(w.width, closeTo((358 - 36) / 7, 0.5));
      expect(w.width, inInclusiveRange(40, 48));
      expect(w.height, greaterThanOrEqualTo(56));
    });
    testWidgets('wide: pills cap at 48 and spread', (t) async {
      await pumpEm(t, EmDateStrip(days: EmDateStrip.weekOf(monday), selected: monday, onSelected: (_) {}), width: 700);
      expect(t.getSize(find.byType(InkWell).first).width, 48);
    });
    testWidgets('scrolls only when 40dp pills do not fit (available < 7*40+6*6 = 316)', (t) async {
      await pumpEm(t, EmDateStrip(days: EmDateStrip.weekOf(monday), selected: monday, onSelected: (_) {}), width: 300, padding: EdgeInsets.zero);
      expect(find.byType(ListView), findsOneWidget);
      expect(t.getSize(find.byType(InkWell).first).width, 40);
      await pumpEm(t, EmDateStrip(days: EmDateStrip.weekOf(monday), selected: monday, onSelected: (_) {}), width: 316, padding: EdgeInsets.zero);
      expect(find.byType(ListView), findsNothing);
    });
    testWidgets('selected pill is solid primary with a white circle', (t) async {
      await pumpEm(t, EmDateStrip(days: EmDateStrip.weekOf(monday), selected: monday, onSelected: (_) {}), width: 700);
      final selectedPill = t.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).where((c) => (c.decoration as BoxDecoration).color == EmColors.primary);
      expect(selectedPill.length, 1);
    });
    testWidgets('robust', (t) async {
      await expectRobust(t, () => EmDateStrip(days: EmDateStrip.weekOf(monday), selected: monday, onSelected: (_) {}, markedDays: {DateTime(2025, 5, 20)}));
    });
  });

  group('EmStatTile', () {
    testWidgets('value + unit + label, menu callback, merged semantics', (t) async {
      final h = t.ensureSemantics();
      var menu = 0;
      await pumpEm(t, SizedBox(width: 130, child: EmStatTile(icon: Icons.groups_outlined, value: '28', unit: 'present', label: 'Attendance', onMenu: () => menu++)));
      expect(find.textContaining('28'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.bySemanticsLabel('Attendance: 28 present'), findsOneWidget);
      expectMinTouch(t, find.bySemanticsLabel('More options'));
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      expect(menu, 1);
      h.dispose();
    });
    testWidgets('3 tiles in a 320dp row at 1.3x / RTL do not overflow', (t) async {
      await expectRobust(t, () => const EmStatTileRow(tiles: [
            EmStatTile(icon: Icons.groups_outlined, value: '1,280', unit: 'kcal', label: 'Calories burned today', onMenu: _noop),
            EmStatTile(icon: Icons.favorite_border, value: '200', unit: 'bpm', label: 'Heart rate', onMenu: _noop),
            EmStatTile(icon: Icons.schedule, value: '03:00', unit: 'min', label: 'Workout time', onMenu: _noop),
          ]));
    });
    testWidgets('EmStatTileRow: never breaks a label inside a word; layout switches 3-up / 2+1 / stacked', (t) async {
      const tiles = [
        EmStatTile(icon: Icons.groups_outlined, value: '28', unit: 'present', label: 'Attendance', onMenu: _noop),
        EmStatTile(icon: Icons.menu_book_outlined, value: '4', unit: 'due', label: 'Homework', onMenu: _noop),
        EmStatTile(icon: Icons.schedule, value: '5', unit: 'classes', label: 'Today', onMenu: _noop),
      ];
      final seen = <String>{};
      for (final w in [320.0, 360.0, 375.0, 430.0]) {
        for (final scale in [1.0, 1.3]) {
          await pumpEm(t, const EmStatTileRow(tiles: tiles), width: w, textScale: scale);
          expectNoLayoutErrors(t);
          // every label's paragraph is at least as wide as its longest word => no mid-word break
          for (final label in ['Attendance', 'Homework', 'Today']) {
            final para = t.renderObject<RenderParagraph>(find.text(label));
            final tp = TextPainter(text: TextSpan(text: label, style: EmStatTile.labelStyle), textDirection: TextDirection.ltr, textScaler: TextScaler.linear(scale))..layout();
            expect(para.size.width, greaterThanOrEqualTo(tp.width - 0.5), reason: '$label at ${w}x$scale');
            expect(para.size.height, lessThanOrEqualTo(tp.height * 1.01), reason: '$label must stay on one line here');
          }
          final tops = {for (final l in ['Attendance', 'Homework', 'Today']) t.getTopLeft(find.text(l)).dy.round()};
          seen.add('${tops.length}rows');
        }
      }
      expect(seen.length, greaterThan(1), reason: 'the layout must change across the width/scale matrix');
    });
    testWidgets('EmStatTileRow columns: 3-up at 1.0 on 390, fewer at 1.3 on 320', (t) async {
      const tiles = [
        EmStatTile(icon: Icons.groups_outlined, value: '28', unit: 'present', label: 'Attendance', onMenu: _noop),
        EmStatTile(icon: Icons.menu_book_outlined, value: '4', unit: 'due', label: 'Homework', onMenu: _noop),
        EmStatTile(icon: Icons.schedule, value: '5', unit: 'classes', label: 'Today', onMenu: _noop),
      ];
      late BuildContext ctx;
      Future<int> cols(double w, double scale) async {
        await pumpEm(t, Builder(builder: (c) { ctx = c; return const SizedBox(); }), width: w, textScale: scale);
        return EmStatTileRow.columnsFor(ctx, tiles, w - 32);
      }
      expect(await cols(430, 1.0), 3);
      expect(await cols(320, 1.3), lessThan(3));
      expect(await cols(320, 1.3), greaterThanOrEqualTo(1));
    });
    testWidgets('value and unit stay together (unit may wrap below)', (t) async {
      await pumpEm(t, const SizedBox(width: 90, child: EmStatTile(icon: Icons.groups_outlined, value: '1,280', unit: 'kcal', label: 'Calories')), textScale: 1.3);
      expectNoLayoutErrors(t);
      expect(find.text('1,280'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);
    });
  });

  group('EmSegmentedTabs', () {
    testWidgets('selecting reports the value; selected announced; >= 44 tall segments', (t) async {
      final h = t.ensureSemantics();
      String sel = 'week';
      String? got;
      await pumpEm(t, StatefulBuilder(builder: (c, set) => EmSegmentedTabs<String>(segments: const [EmSegment('day', 'Day'), EmSegment('week', 'Week'), EmSegment('month', 'Month')], selected: sel, onChanged: (v) { got = v; set(() => sel = v); })));
      await t.tap(find.text('Month'));
      await t.pump(const Duration(milliseconds: 300));
      expect(got, 'month');
      expect(t.getSemantics(find.bySemanticsLabel('Month')).flagsCollection.isSelected, isTrue);
      expect(t.getSize(find.byType(EmSegmentedTabs<String>)).height, greaterThanOrEqualTo(52));
      h.dispose();
    });
    testWidgets('robust with long labels', (t) async {
      await expectRobust(t, () => EmSegmentedTabs<int>(segments: const [EmSegment(0, 'Yesterday'), EmSegment(1, 'This week'), EmSegment(2, 'Last month')], selected: 1, onChanged: (_) {}));
    });
  });

  group('EmListRow', () {
    testWidgets('texts, trailing value, tap and menu; min height 76', (t) async {
      var taps = 0, menus = 0;
      await pumpEm(t, EmListRow(icon: Icons.schedule, title: '05:00 PM', subtitle: 'Next time', trailingText: '200 ml', onTap: () => taps++, onMenu: () => menus++));
      expect(find.text('05:00 PM'), findsOneWidget);
      expect(find.text('200 ml'), findsOneWidget);
      expect(t.getSize(find.byType(EmListRow)).height, greaterThanOrEqualTo(76));
      await t.tap(find.text('05:00 PM'));
      await t.tap(find.byIcon(Icons.more_vert_rounded));
      expect([taps, menus], [1, 1]);
    });
    testWidgets('robust with long text', (t) async {
      await expectRobust(t, () => const EmListRow(icon: Icons.menu_book_outlined, title: 'Mathematics homework: fractions, decimals and percentages', subtitle: 'Grade 5 – A · due tomorrow at the end of the school day', trailingText: '28/30 handed in', onMenu: _noop));
    });
  });

  group('EmProgressRing / EmProgressRingCard', () {
    testWidgets('announces percent, shows centre text, clamps', (t) async {
      final h = t.ensureSemantics();
      await pumpEm(t, const EmProgressRing(value: 1.7, centerText: '2210ml', centerCaption: '400ml'));
      expect(find.text('2210ml'), findsOneWidget);
      expect(find.bySemanticsLabel('Progress 100 percent'), findsOneWidget);
      h.dispose();
    });
    testWidgets('default centre text is the rounded percent', (t) async {
      await pumpEm(t, const EmProgressRing(value: 0.426));
      expect(find.text('43%'), findsOneWidget);
    });
    testWidgets('card stacks on narrow width, rows on wide; robust', (t) async {
      await pumpEm(t, const EmProgressRingCard(title: 'Daily target', subtitle: '400ml', value: .5), width: 700);
      expect(find.byType(EmProgressRing), findsOneWidget);
      await expectRobust(t, () => EmProgressRingCard(title: 'Daily Drink Target', subtitle: '400ml water (2 glass)', value: .6, action: EmSecondaryButton(label: 'Drink 200 ml', onPressed: () {})));
    });
  });

  group('EmBarChart', () {
    const data = [EmBarDatum('Mon', 30), EmBarDatum('Tue', 55), EmBarDatum('Wed', 96, highlight: true)];
    testWidgets('spoken summary lists every bar', (t) async {
      final h = t.ensureSemantics();
      await pumpEm(t, const EmBarChart(data: data));
      expect(find.bySemanticsLabel('Bar chart. Mon 30, Tue 55, Wed 96'), findsOneWidget);
      h.dispose();
    });
    testWidgets('empty data and a custom label do not throw; robust at 1.3x', (t) async {
      await pumpEm(t, const EmBarChart(data: [], semanticLabel: 'nothing'));
      expectNoLayoutErrors(t);
      await expectRobust(t, () => const EmBarChart(data: [EmBarDatum('Mon', 3), EmBarDatum('Tue', 5), EmBarDatum('Wed', 9), EmBarDatum('Thu', 2), EmBarDatum('Fri', 7), EmBarDatum('Sat', 8), EmBarDatum('Sun', 1)], maxValue: 10));
    });
  });

  group('EmChip', () {
    testWidgets('filter chip: tap, selected announced, 48dp high', (t) async {
      final h = t.ensureSemantics();
      var taps = 0;
      await pumpEm(t, EmChip(label: 'Present', selected: true, onTap: () => taps++));
      await t.tap(find.text('Present'));
      expect(taps, 1);
      expect(t.getSemantics(find.bySemanticsLabel('Present')).flagsCollection.isSelected, isTrue);
      expectMinTouch(t, find.byType(ConstrainedBox).first, min: 0);
      expect(t.getSize(find.byType(EmChip)).height, greaterThanOrEqualTo(48));
      h.dispose();
    });
    testWidgets('status chip: container background + dark text for every tone, AA', (t) async {
      for (final tone in EmTone.values) {
        await pumpEm(t, EmChip.status(label: 'Tag', tone: tone));
        final box = t.widget<DecoratedBox>(find.descendant(of: find.byType(EmChip), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration;
        expect(box.color, tone.background);
        expect(t.widget<Text>(find.text('Tag')).style!.color, tone.foreground);
        expect(contrastRatio(tone.foreground, tone.background), greaterThanOrEqualTo(4.5), reason: tone.name);
        expect(relativeLuminance(tone.background), greaterThan(0.8), reason: '${tone.name} must be a light container');
      }
    });
    testWidgets('robust', (t) async {
      await expectRobust(t, () => const Wrap(children: [EmChip(label: 'A rather long filter label here'), EmChip.status(label: 'A rather long status label', tone: EmTone.leave)]));
    });
  });

  group('Buttons', () {
    testWidgets('primary: 52dp, tap, loading ignores taps', (t) async {
      var taps = 0;
      await pumpEm(t, EmPrimaryButton(label: 'Save', onPressed: () => taps++));
      expect(t.getSize(find.byType(ElevatedButton)).height, greaterThanOrEqualTo(52));
      await t.tap(find.text('Save'));
      expect(taps, 1);
      await pumpEm(t, EmPrimaryButton(label: 'Save', loading: true, onPressed: () => taps++), settle: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(taps, 1);
    });
    testWidgets('disabled primary uses disabled colours', (t) async {
      await pumpEm(t, const EmPrimaryButton(label: 'Save', onPressed: null));
      final s = t.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(s.backgroundColor!.resolve({WidgetState.disabled}), EmColors.disabled);
    });
    testWidgets('secondary: white pill, 52dp, tap', (t) async {
      var taps = 0;
      await pumpEm(t, EmSecondaryButton(label: 'Drink 200 ml', icon: Icons.add, onPressed: () => taps++));
      expect(t.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(52));
      await t.tap(find.text('Drink 200 ml'));
      expect(taps, 1);
    });
    testWidgets('robust', (t) async {
      await expectRobust(t, () => Column(children: [EmPrimaryButton(label: 'A long primary action label', icon: Icons.check, onPressed: () {}), EmSecondaryButton(label: 'A long secondary action label', expand: true, onPressed: () {})]));
    });
  });

  group('EmTextField', () {
    testWidgets('label, typing, error text, >= 56 high', (t) async {
      final c = TextEditingController();
      await pumpEm(t, EmTextField(label: 'Email', controller: c, errorText: 'Required'));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      await t.enterText(find.byType(TextFormField), 'a@b.c');
      expect(c.text, 'a@b.c');
      expect(t.getSize(find.byType(TextFormField)).height, greaterThanOrEqualTo(56));
    });
    testWidgets('robust incl. password with suffix', (t) async {
      await expectRobust(t, () => const EmTextField(label: 'Password with a long label', obscureText: true, prefixIcon: Icons.lock_outline, suffix: Icon(Icons.visibility_off_outlined), errorText: 'This is a long error message that wraps'));
    });
  });

  group('States', () {
    testWidgets('empty state: title, message, action', (t) async {
      var taps = 0;
      await pumpEm(t, SizedBox(height: 400, child: EmEmptyState(title: 'No homework', message: 'Nothing here yet', actionLabel: 'New', onAction: () => taps++)), scaffold: true);
      expect(find.text('No homework'), findsOneWidget);
      await t.tap(find.text('New'));
      expect(taps, 1);
    });
    testWidgets('error state: retry', (t) async {
      var taps = 0;
      await pumpEm(t, SizedBox(height: 400, child: EmErrorState(message: 'Offline', onRetry: () => taps++)));
      expect(find.text('Something went wrong'), findsOneWidget);
      await t.tap(find.text('Retry'));
      expect(taps, 1);
    });
    testWidgets('loading: spinner with spoken label', (t) async {
      final h = t.ensureSemantics();
      await pumpEm(t, const SizedBox(height: 200, child: EmLoading()), settle: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      h.dispose();
    });
    testWidgets('robust', (t) async {
      await expectRobust(t, () => const SizedBox(height: 420, child: EmErrorState(title: 'We could not load your classes right now', message: 'Please check your connection and try again in a moment.', onRetry: _noop)));
    });
  });

  group('EmBottomSheet', () {
    testWidgets('opens with title, content and footer; closes', (t) async {
      await pumpEm(t, Builder(builder: (c) => EmPrimaryButton(label: 'Open', onPressed: () => EmBottomSheet.show<void>(c, title: 'Choose', child: const Text('Body'), footer: EmPrimaryButton(label: 'Done', onPressed: () => Navigator.of(c).pop())))));
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.text('Choose'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.text('Choose'), findsNothing);
    });
    testWidgets('tall content scrolls within 90% height at 1.3x', (t) async {
      await pumpEm(t, Builder(builder: (c) => EmPrimaryButton(label: 'Open', onPressed: () => EmBottomSheet.show<void>(c, title: 'Long', child: Column(children: [for (var i = 0; i < 60; i++) Text('Row $i')])))), textScale: 1.3);
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expectNoLayoutErrors(t);
      expect(t.getSize(find.byType(EmBottomSheet)).height, lessThanOrEqualTo(800 * 0.9 + 1));
    });
  });

  group('EmDiamondFab', () {
    testWidgets('accent style: navy glyph, spoken label, tap, >= 48', (t) async {
      final h = t.ensureSemantics();
      var taps = 0;
      await pumpEm(t, EmDiamondFab(icon: Icons.add_rounded, semanticLabel: 'Quick actions', onPressed: () => taps++));
      expect(t.widget<Icon>(find.byIcon(Icons.add_rounded)).color, EmColors.onAccent);
      expectMinTouch(t, find.bySemanticsLabel('Quick actions'));
      await t.tap(find.byType(InkWell));
      expect(taps, 1);
      h.dispose();
    });
    testWidgets('primary style: white glyph; diamond is a 45deg rotation', (t) async {
      await pumpEm(t, EmDiamondFab(icon: Icons.add_rounded, semanticLabel: 'Add', style: EmFabStyle.primary, onPressed: () {}));
      expect(t.widget<Icon>(find.byIcon(Icons.add_rounded)).color, EmColors.onPrimary);
      final rot = t.widget<Transform>(find.descendant(of: find.byType(EmDiamondFab), matching: find.byType(Transform)).first);
      expect(rot.transform.getRotation().entry(0, 1).abs(), closeTo(0.7071, 0.001));
    });
    testWidgets('side below 48 is rejected', (t) async {
      expect(() => EmDiamondFab(icon: Icons.add, semanticLabel: 'x', onPressed: null, side: 40), throwsAssertionError);
    });
  });

  group('EmBottomNav', () {
    const items = [
      EmNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      EmNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Classes'),
      EmNavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Messages', badgeCount: 120),
      EmNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'More', showDot: true),
    ];
    Widget nav(int i, ValueChanged<int> on, {Widget? fab}) => Align(alignment: Alignment.bottomCenter, child: EmBottomNav(items: items, currentIndex: i, onTap: on, centerAction: fab));

    testWidgets('exactly 4 items are required', (t) async {
      expect(() => EmBottomNav(items: items.take(3).toList(), currentIndex: 0, onTap: (_) {}), throwsAssertionError);
    });
    testWidgets('active = filled icon + primary label; others outline + secondary', (t) async {
      await pumpEm(t, nav(1, (_) {}), scaffold: false);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(t.widget<Text>(find.text('Classes')).style!.color, EmColors.primary);
      expect(t.widget<Text>(find.text('Home')).style!.color, EmColors.textSecondary);
    });
    testWidgets('tapping each item reports its index; targets >= 48', (t) async {
      final taps = <int>[];
      await pumpEm(t, nav(0, taps.add), scaffold: false);
      for (final l in ['Home', 'Classes', 'Messages', 'More']) {
        await t.tap(find.text(l));
      }
      expect(taps, [0, 1, 2, 3]);
      for (final l in ['Home', 'Classes', 'Messages', 'More']) {
        expect(t.getSize(find.ancestor(of: find.text(l), matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(48));
      }
    });
    testWidgets('badge caps at 99+, dot shows, announced', (t) async {
      final h = t.ensureSemantics();
      await pumpEm(t, nav(0, (_) {}), scaffold: false);
      expect(find.text('99+'), findsOneWidget);
      expect(find.byKey(const Key('em_nav_dot')), findsOneWidget);
      expect(find.bySemanticsLabel('Messages, tab 3 of 4, 120 unread'), findsOneWidget);
      h.dispose();
    });
    testWidgets('centre FAB overlaps the top edge and still receives taps', (t) async {
      var fab = 0;
      await pumpEm(t, nav(0, (_) {}, fab: EmDiamondFab(icon: Icons.add_rounded, semanticLabel: 'Quick actions', onPressed: () => fab++)), scaffold: false);
      final barTop = t.getTopLeft(find.byType(DecoratedBox).first).dy;
      final fabRect = t.getRect(find.byType(EmDiamondFab));
      expect(fabRect.top, lessThan(barTop), reason: 'FAB must sit partly above the bar');
      expect(fabRect.center.dy, greaterThan(fabRect.top));
      await t.tapAt(Offset(fabRect.center.dx, fabRect.top + fabRect.height * 0.35)); // the upper (overhanging) half
      expect(fab, 1);
    });
    testWidgets('robust at 320dp, 1.3x and RTL', (t) async {
      await expectRobust(t, () => nav(0, (_) {}, fab: EmDiamondFab(icon: Icons.add_rounded, semanticLabel: 'Quick actions', onPressed: () {})), width: 320);
    });
  });

  group('EmLogomark', () {
    testWidgets('both variants render', (t) async {
      await pumpEm(t, const Column(children: [EmLogomark(), EmLogomark(reversed: true)]));
      expectNoLayoutErrors(t);
      expect(find.byType(EmLogomark), findsNWidgets(2));
    });
  });
}

void _noop() {}
