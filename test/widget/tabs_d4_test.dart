import 'package:eldermin_teacher_app/app/modules/classes/controllers/classes_controller.dart';
import 'package:eldermin_teacher_app/app/modules/classes/views/classes_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/controllers/home_badges_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/controllers/messages_controller.dart';
import 'package:eldermin_teacher_app/app/modules/messages/views/messages_screen.dart';
import 'package:eldermin_teacher_app/app/modules/more/controllers/more_controller.dart';
import 'package:eldermin_teacher_app/app/modules/more/views/more_screen.dart';
import 'package:eldermin_teacher_app/app/routes/app_routes.dart';
import 'package:eldermin_teacher_app/core/design/design.dart';
import 'package:eldermin_teacher_app/core/models/home/messaging.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/fake_home_repository.dart';
import '../support/fake_messaging_repository.dart';

const _cls5a = {'gradeLevel': 'Grade 5', 'sectionName': 'A', 'subjectName': 'Mathematics'};
const _cls6b = {'gradeLevel': 'Grade 6', 'sectionName': 'B', 'subjectName': 'Science'};

final _sizes = [for (final w in [320.0, 360.0, 375.0, 430.0]) Size(w, w < 400 ? 667 : 844)];

/// Height of one line of [style] at [scale] (generous: line-height included).
double _oneLine(TextStyle s, double scale) => (s.fontSize ?? 14) * (s.height ?? 1.3) * scale + 2;

void main() {
  setUpAll(loadDesignFonts);
  tearDown(Get.reset);

  /// A signed-in app hosting [screen] in the usual themed app with text scale, direction and size.
  Future<dynamic> host(
    WidgetTester t,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    TextDirection dir = TextDirection.ltr,
    bool classTeacher = true,
    List<String>? permissions,
    List<Map<String, Object?>> assignments = const [_cls5a],
  }) async {
    Get.reset();
    Get.testMode = true;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = (await t.runAsync(() async {
      final h = await signedIn(classTeacher: classTeacher, permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
    Get.put(ClassesController());
    Get.put(MoreController());
    await t.pumpWidget(GetMaterialApp(
      theme: AppTheme.light,
      getPages: [for (final r in [...Routes.all, Routes.homeMessages]) GetPage(name: r, page: () => Scaffold(body: Text('went:$r')))],
      builder: (context, c) => Directionality(textDirection: dir, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: c!)),
      home: Scaffold(body: screen),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    return h;
  }

  void noErrors(WidgetTester t, String where) {
    final e = t.takeException();
    expect(e, isNull, reason: '$where: ${e?.toString().split('\n').first}');
  }

  group('Classes tab', () {
    testWidgets('layout matrix: widths 320-430 x text 1.0/1.3 x LTR/RTL (class teacher with two classes)', (t) async {
      final problems = <String>{};
      for (final size in _sizes) {
        for (final scale in [1.0, 1.3]) {
          for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
            await host(t, const ClassesScreen(), size: size, scale: scale, dir: dir, assignments: const [_cls5a, _cls6b]);
            final e = t.takeException();
            if (e != null) problems.add('${size.width.toInt()} x$scale ${dir.name}: ${e.toString().split('\n').first}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    testWidgets('module cards: icon circle, title and subtitle, titles never wrap beyond two lines; my-class chips stay on one line', (t) async {
      for (final scale in [1.0, 1.3]) {
        await host(t, const ClassesScreen(), size: const Size(360, 800), scale: scale, assignments: const [_cls5a, _cls6b]);
        expect(find.byKey(const Key('classes_grid')), findsOneWidget);
        for (final id in ['students', 'attendance', 'homework', 'assessments']) {
          final card = find.byKey(ValueKey('module_$id'));
          expect(card, findsOneWidget, reason: id);
          final title = find.descendant(of: card, matching: find.byType(Text)).evaluate().map((e) => e.widget as Text).first;
          final para = t.renderObject<RenderParagraph>(find.descendant(of: card, matching: find.text(title.data!)).first);
          expect(para.size.height, lessThanOrEqualTo(_oneLine(EmType.bodyLarge.copyWith(fontSize: 15), scale) * 2), reason: '$id title lines at x$scale');
        }
        // "My classes" chips: one line each ("Grade 5 - A" and the "Class teacher" note)
        final chip = find.text('Grade 5 - A');
        expect(chip, findsOneWidget);
        expect(t.renderObject<RenderParagraph>(chip).size.height, lessThanOrEqualTo(_oneLine(EmType.label, scale)));
        expect(find.text(' · Class teacher'), findsOneWidget);
        expect(t.renderObject<RenderParagraph>(find.text(' · Class teacher')).size.height, lessThanOrEqualTo(_oneLine(EmType.caption, scale)));
        noErrors(t, 'classes x$scale');
      }
    });

    testWidgets('permission-driven visibility is unchanged: subject teacher has no attendance card; nothing allowed -> Em empty state', (t) async {
      await host(t, const ClassesScreen(), classTeacher: false);
      expect(find.byKey(const ValueKey('module_attendance')), findsNothing);
      expect(find.byKey(const ValueKey('module_homework')), findsOneWidget);
      await host(t, const ClassesScreen(), permissions: const []);
      expect(find.text('Nothing available yet'), findsOneWidget);
      expect(find.byType(EmEmptyState), findsOneWidget);
    });

    testWidgets('tapping a module opens its route', (t) async {
      await host(t, const ClassesScreen());
      await t.tap(find.byKey(const ValueKey('module_homework')));
      await t.pumpAndSettle();
      expect(Get.currentRoute, Routes.homework);
    });
  });

  group('More tab', () {
    testWidgets('layout matrix: widths 320-430 x text 1.0/1.3 x LTR/RTL', (t) async {
      final problems = <String>{};
      for (final size in _sizes) {
        for (final scale in [1.0, 1.3]) {
          for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
            await host(t, const MoreScreen(), size: size, scale: scale, dir: dir);
            final e = t.takeException();
            if (e != null) problems.add('${size.width.toInt()} x$scale ${dir.name}: ${e.toString().split('\n').first}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    testWidgets('profile summary card: avatar initials, name, campus/department, email; tap opens Profile', (t) async {
      await host(t, const MoreScreen());
      final card = find.byKey(const Key('more_profile_card'));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Tess Teacher')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Main Campus · Science')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('t@s.test')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('TT')), findsOneWidget);
      await t.tap(card);
      await t.pumpAndSettle();
      expect(Get.currentRoute, Routes.profile);
    });

    testWidgets('grouped rows: Modules then Account; existing entries, keys and flows kept', (t) async {
      await host(t, const MoreScreen(), size: const Size(390, 2600)); // tall: the whole list is built
      expect(find.text('Modules'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      final ys = [for (final l in ['Modules', 'Timetable', 'Account', 'Notifications', 'Help', 'About']) t.getTopLeft(find.text(l).first).dy];
      expect(ys, [...ys]..sort(), reason: 'Modules, its rows, Account, then the account rows (top to bottom)');
      await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('more_sign_out')), findsOneWidget);
      expect(find.byKey(const Key('more_delete_account')), findsNothing, reason: 'no in-app account-deletion request');
    });

    testWidgets('destructive rows are tinted with the error container (icon), titles stay ink', (t) async {
      await host(t, const MoreScreen());
      await t.scrollUntilVisible(find.byKey(const Key('more_sign_out')), 200, scrollable: find.byType(Scrollable).first);
      final row = find.byKey(const Key('more_sign_out'));
      final circle = t.widgetList<Container>(find.descendant(of: row, matching: find.byType(Container))).where((c) => (c.decoration is BoxDecoration) && (c.decoration as BoxDecoration).color == EmColors.errorContainer);
      expect(circle, isNotEmpty);
      expect(t.widget<Text>(find.descendant(of: row, matching: find.text('Sign out'))).style!.color, EmColors.ink);
    });

    testWidgets('row titles and subtitles stay within two lines at 1.3x on 320dp', (t) async {
      await host(t, const MoreScreen(), size: const Size(320, 667), scale: 1.3);
      for (final l in ['Notifications', 'Help', 'About']) {
        await t.scrollUntilVisible(find.text(l), 200, scrollable: find.byType(Scrollable).first);
        expect(t.renderObject<RenderParagraph>(find.text(l)).size.height, lessThanOrEqualTo(_oneLine(EmType.bodyLarge, 1.3) * 2), reason: l);
      }
    });
  });

  group('Messages tab', () {
    late FakeMessagingRepository repo;
    late FakeHomeRepository home;
    final now = DateTime.utc(2026, 10, 5, 9);

    ThreadsResult threads() => ThreadsResult(items: [
          thread('a', guardian: 'Mrs Malik', student: 'Zara Malik', subject: 'Homework', preview: "Thank you ma'am", unread: true, at: DateTime.utc(2026, 10, 5, 8, 48)),
          thread('b', guardian: 'Mr Ali', preview: 'See you Thursday', at: DateTime.utc(2026, 10, 4, 9)),
          thread('c', guardian: 'Mrs Alexandrina Montgomery-Featherstonehaugh', student: 'Bartholomew Montgomery-Featherstonehaugh', subject: 'A very long subject line about the school trip', preview: 'A long reply that goes on and on about the arrangements for the trip so it has to wrap', unread: true, at: DateTime.utc(2026, 10, 5, 7)),
          thread('d', guardian: 'Ms Rahman', preview: 'Closed with thanks', status: 'closed', at: DateTime.utc(2026, 9, 30, 9)),
        ]);

    Future<MessagesController> boot(
      WidgetTester t, {
      ThreadsResult? open,
      Object? error,
      Size size = const Size(390, 844),
      double scale = 1,
      TextDirection dir = TextDirection.ltr,
    }) async {
      repo = FakeMessagingRepository();
      home = FakeHomeRepository();
      final h = await host(t, const SizedBox(), size: size, scale: scale, dir: dir);
      final badges = Get.put(HomeBadgesController(repository: home, auth: h.auth, autoPoll: false));
      home.threads = () async => error != null ? throw error : (open ?? const ThreadsResult());
      final c = Get.put(MessagesController(repository: repo, badges: badges, clock: () => now));
      await t.pumpWidget(GetMaterialApp(
        theme: AppTheme.light,
        builder: (context, w) => Directionality(textDirection: dir, child: MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: w!)),
        home: const Scaffold(body: MessagesScreen(embedded: true)),
        getPages: [for (final r in [...Routes.all, Routes.homeMessages]) GetPage(name: r, page: () => Scaffold(body: Text('went:$r')))],
      ));
      await t.runAsync(() => badges.refreshThreads());
      await t.pump();
      await t.pump(const Duration(milliseconds: 350));
      return c;
    }

    testWidgets('layout matrix: widths 320-430 x text 1.0/1.3 x LTR/RTL with long names, subjects and previews', (t) async {
      final problems = <String>{};
      for (final size in _sizes) {
        for (final scale in [1.0, 1.3]) {
          for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
            await boot(t, open: threads(), size: size, scale: scale, dir: dir);
            final e = t.takeException();
            if (e != null) problems.add('${size.width.toInt()} x$scale ${dir.name}: ${e.toString().split('\n').first}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    testWidgets('short labels never wrap: time, "Closed" tag, segmented labels (320dp, text 1.3x)', (t) async {
      await boot(t, open: threads(), size: const Size(320, 800), scale: 1.3);
      for (final label in ['12 min ago', 'Yesterday']) {
        final f = find.text(label);
        expect(f, findsOneWidget, reason: label);
        expect(t.renderObject<RenderParagraph>(f).size.height, lessThanOrEqualTo(_oneLine(EmType.caption, 1.3)), reason: '"$label" wrapped');
      }
      for (final label in ['Open', 'Closed']) {
        final f = find.descendant(of: find.byKey(const Key('messages_filter')), matching: find.text(label));
        expect(t.renderObject<RenderParagraph>(f).size.height, lessThanOrEqualTo(_oneLine(EmType.label.copyWith(fontSize: 15), 1.3)), reason: '"$label" wrapped');
      }
    });

    testWidgets('rows: initials avatar, guardian, re-line, preview, unread dot, relative time; keys kept', (t) async {
      await boot(t, open: threads());
      expect(find.byKey(const Key('thread_a')), findsOneWidget);
      expect(find.text('Mrs Malik'), findsOneWidget);
      expect(find.text('re Zara Malik · Homework'), findsWidgets);
      expect(find.text("Thank you ma'am"), findsOneWidget);
      expect(find.byKey(const Key('unread_a')), findsOneWidget);
      expect(find.byKey(const Key('unread_b')), findsNothing);
      expect(find.text('12 min ago'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('M'), findsWidgets); // "Mrs Malik" -> honorific dropped -> "M"
      expect(find.text('AM'), findsOneWidget); // "Mrs Alexandrina Montgomery-..." -> first + last initial
      // the unread name is bolder than the read one
      final a = t.widget<Text>(find.text('Mrs Malik'));
      final b = t.widget<Text>(find.text('Mr Ali'));
      expect(a.style!.fontWeight!.index, greaterThan(b.style!.fontWeight!.index));
    });

    testWidgets('New message button: 48dp circle, spoken label, opens the new-message route', (t) async {
      final sem = t.ensureSemantics();
      await boot(t, open: threads());
      final b = find.byKey(const Key('messages_new'));
      expect(t.getSize(b).width, greaterThanOrEqualTo(48));
      expect(t.getSemantics(b).label, 'New message', reason: 'its own semantics node, not merged into the heading');
      expect(t.getSemantics(b).flagsCollection.isButton, isTrue);
      await t.tap(b);
      await t.pumpAndSettle();
      expect(Get.currentRoute, Routes.messageNew);
      sem.dispose();
    });

    testWidgets('Open / Closed tabs: selected state, switching, and the Em empty / error states with their keys', (t) async {
      final sem = t.ensureSemantics();
      final c = await boot(t, open: const ThreadsResult());
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text('No open conversations'), findsOneWidget);
      expect(find.byType(EmEmptyState), findsOneWidget);
      expect(t.getSemantics(find.bySemanticsLabel('Open')).flagsCollection.isSelected, isTrue);
      repo.threads = (_) async => const ThreadsResult();
      await t.tap(find.text('Closed'));
      await t.runAsync(() => c.loadClosed());
      await t.pump(const Duration(milliseconds: 350));
      expect(find.text('No closed conversations'), findsOneWidget);
      sem.dispose();

      await boot(t, error: ApiException('Server down', statusCode: 500));
      expect(find.byKey(const Key('screen_error')), findsOneWidget);
      expect(find.byType(EmErrorState), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
