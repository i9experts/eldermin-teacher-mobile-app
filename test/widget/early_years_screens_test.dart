// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';
import 'package:eldermin_teacher_app/app/modules/early_years/controllers/early_years_controller.dart';
import 'package:eldermin_teacher_app/app/modules/early_years/views/early_years_screen.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/design_harness.dart' show loadDesignFonts;
import '../support/fake_early_years_repository.dart';
import '../support/layout_probe.dart';

const nurseryA = {'gradeLevel': 'Nursery', 'sectionName': 'A', 'subjectName': 'All'};
const kg1 = {'gradeLevel': 'KG-1', 'sectionName': '', 'subjectName': 'All'};

void main() {
  late FakeEarlyYearsRepository repo;

  setUpAll(loadDesignFonts);

  setUp(() {
    Get.reset();
    Get.testMode = true;
    repo = FakeEarlyYearsRepository();
  });
  tearDown(Get.reset);
  tearDown(ProbeEnv.reset);

  Future<dynamic> signIn(WidgetTester t, {List<Map<String, Object?>> assignments = const [nurseryA], List<String>? permissions}) async {
    return (await t.runAsync(() async {
      final h = await signedIn(permissions: permissions);
      h.api.assignments = assignments;
      await h.auth.refreshProfile(force: true);
      return h;
    }))!;
  }

  Future<void> open(WidgetTester t, Widget screen, {Size size = const Size(430, 3000)}) async {
    await t.binding.setSurfaceSize(probeSize(size));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: const Scaffold(body: Text('root'))));
    unawaited(Get.to(() => probeHome(screen)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<EarlyYearsController> boot(WidgetTester t, {List<Map<String, Object?>> assignments = const [nurseryA], List<String>? permissions, Size size = const Size(430, 3000)}) async {
    final h = await signIn(t, assignments: assignments, permissions: permissions);
    final c = Get.put(EarlyYearsController(repository: repo, auth: h.auth, permissions: h.perms));
    await open(t, const EarlyYearsScreen(), size: size);
    await c.load();
    await settle(t);
    return c;
  }

  group('Early Years list', () {
    testWidgets('shows only the children of my classes with class and student id; others never appear', (t) async {
      repo.children = () async => [child(1, first: 'Zara'), child(2, first: 'Amy'), child(3, first: 'Other', section: 'B'), child(4, first: 'Far', grade: 'Grade 9', section: 'Z')];
      await boot(t);
      expect(find.text('Amy2 Khan'), findsOneWidget);
      expect(find.text('Zara1 Khan'), findsOneWidget);
      expect(find.text('Other3 Khan'), findsNothing);
      expect(find.text('Far4 Khan'), findsNothing);
      expect(find.text('Nursery - A · ST-1'), findsOneWidget);
      expect(find.byKey(const Key('ey_count')), findsOneWidget);
      expect(find.text('2 children in your classes'), findsOneWidget);
    });

    testWidgets('the app bar and caption are the module\'s own', (t) async {
      repo.children = () async => [child(1)];
      await boot(t);
      expect(find.text('Early Years'), findsWidgets);
      expect(find.text('Observations and portfolios'), findsOneWidget);
    });

    testWidgets('class chips appear with several classes and narrow the list; search narrows by name', (t) async {
      repo.children = () async => [child(1, first: 'Zara'), child(2, first: 'Kay', grade: 'KG-1', section: 'C')];
      await boot(t, assignments: [nurseryA, kg1]);
      expect(find.text('Zara1 Khan'), findsOneWidget);
      expect(find.text('Kay2 Khan'), findsOneWidget);
      await t.tap(find.byKey(const Key('cls_1')));
      await settle(t);
      expect(find.text('Zara1 Khan'), findsNothing);
      expect(find.text('Kay2 Khan'), findsOneWidget);
      await t.tap(find.byKey(const Key('cls_all')));
      await t.enterText(find.byKey(const Key('ey_search')), 'zara');
      await settle(t);
      expect(find.text('Kay2 Khan'), findsNothing);
      expect(find.text('Zara1 Khan'), findsOneWidget);
      await t.enterText(find.byKey(const Key('ey_search')), 'nobody');
      await settle(t);
      expect(find.byKey(const Key('ey_filter_empty')), findsOneWidget);
    });

    testWidgets('no class assigned: an honest message, nothing requested', (t) async {
      await boot(t, assignments: const []);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      expect(find.text("You aren't assigned to a class yet"), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a class with no Early Years child: explains how a child gets here', (t) async {
      repo.children = () async => [child(9, grade: 'Grade 9', section: 'Z')];
      await boot(t);
      expect(find.text('No Early Years children in your classes'), findsOneWidget);
      expect(find.textContaining('programme is set to Early Years'), findsOneWidget);
      expect(find.textContaining('Only children in classes assigned to you are shown'), findsOneWidget);
      expect(find.textContaining('Pull down to refresh'), findsOneWidget);
    });

    testWidgets('a visible note says the list is limited to my classes', (t) async {
      repo.children = () async => [child(1)];
      await boot(t);
      expect(find.byKey(const Key('ey_scope_note')), findsOneWidget);
      expect(find.text('Showing only the children in the classes assigned to you.'), findsOneWidget);
      expect(find.byKey(const Key('cls_all')), findsNothing, reason: 'a single class needs no class chips');
    });

    testWidgets('a whole-grade assignment shows every section of the grade; grade spelling drift is tolerated', (t) async {
      repo.children = () async => [child(1, first: 'Amy', grade: 'GRADE-3', section: 'a'), child(2, first: 'Bea', grade: 'Grade 3', section: 'B'), child(3, first: 'Cat', grade: 'Grade 4', section: 'A')];
      await boot(t, assignments: const [{'gradeLevel': 'Grade 3', 'sectionName': '', 'subjectName': 'Maths'}]);
      expect(find.text('Amy1 Khan'), findsOneWidget);
      expect(find.text('Bea2 Khan'), findsOneWidget);
      expect(find.text('Cat3 Khan'), findsNothing);
    });

    testWidgets('pull-to-refresh works from the empty state', (t) async {
      repo.children = () async => [];
      await boot(t);
      expect(find.byKey(const Key('screen_empty')), findsOneWidget);
      final before = repo.calls.length;
      repo.children = () async => [child(1, first: 'Zara')];
      await t.binding.setSurfaceSize(null);
      await t.pump();
      await t.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 300));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      }
      expect(repo.calls.length, greaterThan(before));
      expect(find.text('Zara1 Khan'), findsOneWidget);
    });

    testWidgets('a custom role without early-years:view sees "You don\'t have access" and nothing is requested', (t) async {
      await boot(t, permissions: const ['teaching:view']);
      expect(find.text("You don't have access"), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('server error: message + Retry; Retry recovers', (t) async {
      var fail = true;
      repo.children = () async {
        if (fail) throw ApiException('boom', statusCode: 500);
        return [child(1, first: 'Zara')];
      };
      await boot(t);
      expect(find.text('Try again'), findsOneWidget);
      fail = false;
      await t.tap(find.text('Try again'));
      await settle(t);
      expect(find.text('Zara1 Khan'), findsOneWidget);
    });

    testWidgets('loading shows the shimmer first', (t) async {
      final gate = Completer<void>();
      repo.children = () async {
        await gate.future;
        return [child(1)];
      };
      final h = await signIn(t);
      final c = Get.put(EarlyYearsController(repository: repo, auth: h.auth, permissions: h.perms));
      await open(t, const EarlyYearsScreen());
      unawaited(c.load());
      await t.pump();
      expect(find.byKey(const Key('screen_loading')), findsOneWidget);
      gate.complete();
      await settle(t);
      expect(find.byKey(const Key('screen_loading')), findsNothing);
    });

    for (final w in [320.0, 430.0]) {
      testWidgets('lays out at ${w.toInt()} dp with large text, in RTL too', (t) async {
        repo.children = () async => [child(1, first: 'A very long first name indeed'), child(2)];
        await boot(t, size: Size(w, 3000));
        expectNoLayoutError(t);
        for (final dir in probeDirs) {
          await t.pumpWidget(GetMaterialApp(theme: AppTheme.light, home: probeWrap(const EarlyYearsScreen(), scale: 1.3, dir: dir)));
          await settle(t);
          expectNoLayoutError(t);
        }
      });
    }
  });
}
