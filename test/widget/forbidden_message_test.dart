// Backend task 9: a teacher token without a campus gets 403 {statusCode, message: "No campus assigned — contact your administrator", error: "Forbidden"}
// on events / circulars / calendar. The screens show that server message instead of the generic "You don't have access"; stock texts
// ("Forbidden resource") keep the generic wording. Real repositories + real DioExceptionHandler on a fake network.
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/calendar_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/controllers/circulars_controller.dart';
import 'package:eldermin_teacher_app/app/modules/calendar/views/calendar_screen.dart';
import 'package:eldermin_teacher_app/app/modules/events/controllers/events_controller.dart';
import 'package:eldermin_teacher_app/app/modules/events/views/events_screen.dart';
import 'package:eldermin_teacher_app/app/modules/home/models/section_state.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/services/events_repository.dart';
import 'package:eldermin_teacher_app/core/services/school_calendar_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import '../support/auth_harness.dart';
import '../support/failing_client.dart';

const noCampus = 'No campus assigned — contact your administrator';
const generic = "You don't have access";

Future<AuthController> _boot(WidgetTester t) async {
  Get.reset();
  Get.testMode = true;
  final h = (await t.runAsync(() async {
    final h = await signedIn();
    await h.auth.refreshProfile(force: true);
    return h;
  }))!;
  return h.auth;
}

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _pump(WidgetTester t, Widget w) async {
  await t.binding.setSurfaceSize(const Size(430, 1600));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(GetMaterialApp(home: w));
  await t.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('SectionState', () {
    test('keeps a specific 403 message, drops stock / blank ones', () {
      expect(SectionState<int>.fromError(ApiException(noCampus, statusCode: 403)).forbiddenDetail, noCampus);
      expect(SectionState<int>.fromError(ApiException('Your account has no campus assigned. Contact your administrator.', statusCode: 403)).forbiddenDetail, isNotNull);
      for (final m in ['Forbidden resource', 'Forbidden', '  ', '', 'Something went wrong. Please try again.']) {
        final s = SectionState<int>.fromError(ApiException(m, statusCode: 403));
        expect(s.status, SectionStatus.forbidden);
        expect(s.forbiddenDetail, isNull, reason: m);
        expect(s.message, generic);
      }
      expect(SectionState<int>.fromError(ApiException('x' * 300, statusCode: 403)).forbiddenDetail, isNull);
      expect(const SectionState<int>.forbidden().forbiddenDetail, isNull);
    });
  });

  group('403 with the campus message', () {
    testWidgets('Events screen shows the server message, not the generic text', (t) async {
      final auth = await _boot(t);
      expect(auth.status.value, AuthStatus.authenticated);
      final net = FailingClient(NetFail.http403)..message403 = noCampus;
      final c = Get.put(EventsController(repository: EventsRepository(net)));
      await _pump(t, const EventsScreen());
      await t.runAsync(() => c.load(userInitiated: true));
      await _settle(t);
      expect(find.byKey(const Key('screen_forbidden')), findsOneWidget);
      expect(find.text(noCampus), findsOneWidget);
      expect(find.text(generic), findsNothing);
    });

    testWidgets('Calendar tab and Circulars tab show the server message', (t) async {
      final auth = await _boot(t);
      final net = FailingClient(NetFail.http403)..message403 = noCampus;
      final repo = SchoolCalendarRepository(net);
      final cal = Get.put(CalendarController(repository: repo));
      final circ = Get.put(CircularsController(repository: repo, auth: auth));
      await _pump(t, const CalendarScreen());
      await t.runAsync(() => cal.reload());
      await t.runAsync(() => circ.load(userInitiated: true));
      await _settle(t);
      expect(find.text(noCampus), findsOneWidget, reason: 'calendar tab');
      expect(find.text(generic), findsNothing);
      await t.tap(find.textContaining('Circulars').first);
      await _settle(t);
      expect(find.text(noCampus), findsOneWidget, reason: 'circulars tab');
      expect(find.text(generic), findsNothing);
    });

    testWidgets('a stock 403 ("Forbidden resource") still reads "You don\'t have access"', (t) async {
      await _boot(t);
      final net = FailingClient(NetFail.http403); // message403 = Forbidden resource
      final c = Get.put(EventsController(repository: EventsRepository(net)));
      await _pump(t, const EventsScreen());
      await t.runAsync(() => c.load(userInitiated: true));
      await _settle(t);
      expect(find.text(generic), findsOneWidget);
      expect(find.text('Forbidden resource'), findsNothing);
    });
  });
}
