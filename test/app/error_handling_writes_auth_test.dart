// Phase 8 error-handling audit, executable part 2: writes (ActionFailure), the sign-in / profile-load path, and the 401 -> sign-out wiring, all
// on the REAL network layer (Dio interceptor, DioExceptionHandler) or the REAL repositories on a failing client.
// ignore_for_file: invalid_use_of_protected_member
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/app/common/action_failure.dart';
import 'package:eldermin_teacher_app/app/modules/auth/controllers/auth_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_apply_controller.dart';
import 'package:eldermin_teacher_app/app/modules/leave/controllers/leave_controller.dart';
import 'package:eldermin_teacher_app/core/models/leave/leave_models.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/network/dio_exception_handler.dart';
import 'package:eldermin_teacher_app/core/network/dio_service.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/services/homework_repository.dart';
import 'package:eldermin_teacher_app/core/services/leave_repository.dart';
import 'package:eldermin_teacher_app/core/services/messaging_repository.dart';
import 'package:eldermin_teacher_app/core/services/permission_service.dart';
import 'package:eldermin_teacher_app/core/services/token_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:shared_preferences/shared_preferences.dart';
import '../support/auth_harness.dart';
import '../support/failing_client.dart';

DioException dioFail(NetFail m) {
  final ro = RequestOptions(path: '/x');
  Response? r(int c) => Response(requestOptions: ro, statusCode: c, data: {'statusCode': c, 'message': c == 403 ? 'Forbidden resource' : 'Internal server error'});
  switch (m) {
    case NetFail.offline:
      return DioException(requestOptions: ro, type: DioExceptionType.connectionError, error: kNoInternetMarker);
    case NetFail.connectTimeout:
      return DioException(requestOptions: ro, type: DioExceptionType.connectionTimeout);
    case NetFail.receiveTimeout:
      return DioException(requestOptions: ro, type: DioExceptionType.receiveTimeout);
    case NetFail.http403:
      return DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: r(403));
    case NetFail.http404:
      return DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: r(404));
    case NetFail.http500:
      return DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: r(500));
    case NetFail.http501:
      return DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: r(501));
    case NetFail.http401:
      return DioException(requestOptions: ro, type: DioExceptionType.badResponse, response: r(401));
  }
}

class _StatusAdapter implements HttpClientAdapter {
  final int status;
  int calls = 0;
  _StatusAdapter(this.status);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(jsonEncode({'statusCode': status, 'message': 'x'}), status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

class _Tokens implements TokenStore {
  String? token = 'tok';
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> saveToken(String t) async => token = t;
  @override
  Future<void> clearAll() async => token = null;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
  });
  tearDown(Get.reset);

  group('ActionFailure on the real error mapping (every failure a write can meet)', () {
    ActionFailure of(NetFail m, {bool upload = false}) => ActionFailure.from(DioExceptionHandler.handle(dioFail(m)), what: 'save this', upload: upload);

    test('offline / timeouts -> "offline" kind, own message + "kept" + reconnect hint, retry allowed', () {
      for (final m in [NetFail.offline, NetFail.connectTimeout, NetFail.receiveTimeout]) {
        final f = of(m);
        expect(f.kind, ActionFailureKind.offline, reason: m.name);
        expect(f.canRetry, isTrue);
        expect(f.message, contains('Your changes are kept.'));
        expect(f.message, contains('Reconnect and try again.'));
      }
      expect(of(NetFail.offline).message, startsWith('No internet connection.'));
      expect(of(NetFail.connectTimeout).message, startsWith('Connection timed out.'));
    });

    test('403 -> "You can\'t ..." without the raw stock text, never retried blindly', () {
      final f = of(NetFail.http403);
      expect(f.kind, ActionFailureKind.forbidden);
      expect(f.isForbidden, isTrue);
      expect(f.message, "You can't save this.");
      expect(f.message, isNot(contains('Forbidden')));
      expect(f.serverMessage, isEmpty);
      expect(f.canRetry, isFalse);
    });

    test('403 keeps a SPECIFIC server reason, but never Nest\'s stock texts or blanks', () {
      ActionFailure with403(String m) => ActionFailure.from(ApiException(m, statusCode: 403), what: 'save this');
      expect(with403('You can only edit Tarbiyah assessments you recorded yourself').message, "You can't save this. You can only edit Tarbiyah assessments you recorded yourself");
      for (final m in [
        'Forbidden resource', 'Forbidden', '  ', '', 'Access denied', 'Something went wrong. Please try again.',
        'Access denied. Your role does not have manage access to teaching:fixtures.', // the real role-guard text (backend 0ed3d8d)
        'Your role does not have view access to behaviour.',
      ]) {
        expect(with403(m).message, "You can't save this.", reason: '"$m"');
      }
    });

    test('500 -> a calm server message with "kept" and retry; 501 / 404 are not retried', () {
      final f = of(NetFail.http500);
      expect(f.kind, ActionFailureKind.server);
      expect(f.canRetry, isTrue);
      expect(f.message, contains('The server had a problem'));
      expect(f.message, contains('Your changes are kept.'));
      expect(of(NetFail.http404).kind, ActionFailureKind.notFound);
      expect(of(NetFail.http404).canRetry, isFalse);
      expect(of(NetFail.http501).kind, ActionFailureKind.server);
    });

    test('503 on an upload = storage not configured (no retry); 503 elsewhere is a plain server failure', () {
      final up = ActionFailure.from(ApiException('File uploads are not available on this server (storage is not configured).', statusCode: 503), what: 'attach', upload: true);
      expect(up.kind, ActionFailureKind.uploadUnavailable);
      expect(up.canRetry, isFalse);
      expect(ActionFailure.from(ApiException('x', statusCode: 503), what: 'attach').kind, ActionFailureKind.server);
    });

    test('400 / 413 / 422 show the server validation text; 409 conflict; anything that is not an ApiException is "other" and retryable; nothing leaks type names', () {
      for (final code in [400, 413, 422]) {
        final f = ActionFailure.from(ApiException('Reason must be at least 10 characters', statusCode: code), what: 'send');
        expect(f.kind, ActionFailureKind.validation);
        expect(f.message, 'Reason must be at least 10 characters');
      }
      expect(ActionFailure.from(ApiException('', statusCode: 409), what: 'send').kind, ActionFailureKind.conflict);
      final odd = ActionFailure.from(StateError('boom'), what: 'send this');
      expect(odd.kind, ActionFailureKind.other);
      expect(odd.canRetry, isTrue);
      expect(odd.message, isNot(contains('StateError')));
      expect(odd.message, isNot(contains('boom')));
    });
  });

  group('writes through the real repositories on a failing network', () {
    test('leave application: offline / 500 keep every field and allow a retry; 403 shows the server text', () async {
      final net = FailingClient(NetFail.offline);
      final c = LeaveApplyController(repository: LeaveRepository(net));
      c.setType(StaffLeaveType.annual);
      c.setFrom(DateTime(2026, 11, 2));
      c.setTo(DateTime(2026, 11, 4));
      c.reasonC.text = 'Family wedding out of town';
      for (final m in [NetFail.offline, NetFail.connectTimeout, NetFail.http500, NetFail.http403]) {
        net.mode = m;
        final r = await c.submit();
        expect(r, isA<ApplyFailed>(), reason: m.name);
        expect(c.failure.value, isNotNull);
        expect(c.failureText.value, isNotEmpty);
        expect(c.reasonC.text, 'Family wedding out of town', reason: 'the form is kept');
        expect(c.from.value, DateTime(2026, 11, 2));
        expect(c.saving.value, isFalse);
      }
      expect(net.calls, 4, reason: 'one request per attempt, no hidden retries');
      c.onClose();
    });
  });

  group('sign-in / profile load on the real AuthApiService + failing network', () {
    Future<AuthController> make(FailingClient net, {String? token = 'tok'}) async {
      final tokens = _Tokens()..token = token;
      final auth = AuthController(
        api: AuthApiService(net),
        permissions: PermissionService(),
        tokenStore: tokens,
        minSplash: Duration.zero,
        resetScopedControllers: () async {},
        notify: (_) {},
      );
      return auth;
    }

    test('restore at launch with a stored token: offline / timeout / 500 / 403 keep the session and show a Retry message (never a logout)', () async {
      final expected = {
        NetFail.offline: 'No internet connection. Check your network and try again.',
        NetFail.connectTimeout: 'Connection timed out. Check your internet and try again.',
        NetFail.http500: 'Internal server error',
        NetFail.http403: "You don't have access to Eldermin Teacher with this account. Ask your school administrator if you think this is a mistake.",
      };
      for (final e in expected.entries) {
        final auth = await make(FailingClient(e.key));
        await auth.bootstrap();
        expect(auth.status.value, AuthStatus.authenticated, reason: '${e.key.name}: the session is kept');
        expect(auth.profileError.value, e.value, reason: e.key.name);
        expect(auth.staffMe.value, isNull);
      }
    });

    test('profile retry sends a new request and an unchanged failure keeps the message', () async {
      final net = FailingClient(NetFail.offline);
      final auth = await make(net);
      await auth.bootstrap();
      final before = net.calls;
      expect(await auth.retryRestore(), isFalse);
      expect(net.calls, greaterThan(before));
      expect(auth.profileError.value, isNotNull);
    });

    test('login: offline / timeout / 500 / 403 / 401 are thrown as ApiException with a readable message (form shows it)', () async {
      for (final m in [NetFail.offline, NetFail.connectTimeout, NetFail.http500, NetFail.http403, NetFail.http401]) {
        final auth = await make(FailingClient(m), token: null);
        await expectLater(auth.login(email: 'a@s.test', password: 'secret-pass'), throwsA(isA<ApiException>()), reason: m.name);
        expect(auth.status.value, isNot(AuthStatus.authenticated), reason: m.name);
      }
    });
  });

  group('401 on any authenticated call ends the session (real Dio interceptor -> AuthController)', () {
    setUp(() {
      DioService.hasConnection = () async => true;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'read' ? 'tok123' : null,
      );
    });

    test('a 401 on a read, a write and a message send signs the user out; a 401 from login does not', () async {
      final h = await signedIn();
      await h.auth.refreshProfile(force: true);
      DioService.onUnauthorized = h.auth.handleUnauthorized; // what InitialBinding wires
      final adapter = _StatusAdapter(401);
      DioService.getDio().httpClientAdapter = adapter;
      final client = BaseClient();

      // login 401: invalid credentials, session untouched
      await expectLater(AuthApiService(client).login(email: 'a@s.test', password: 'x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
      expect(h.auth.status.value, AuthStatus.authenticated);

      // an authenticated READ (a list screen's repository)
      await expectLater(HomeworkRepository(client).fetchMine('64a0000000000000000000a1'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
      await pumpEventQueue();
      expect(h.auth.status.value, AuthStatus.unauthenticated, reason: 'read 401 -> signed out');
      expect(h.auth.staffMe.value, isNull);
      expect(h.perms.role, isNull, reason: 'permissions are cleared');

      // a WRITE while signed in again
      final h2 = await signedIn();
      DioService.onUnauthorized = h2.auth.handleUnauthorized;
      await expectLater(HomeworkRepository(client).delete('64a0000000000000000000a1'), throwsA(isA<ApiException>()));
      await pumpEventQueue();
      expect(h2.auth.status.value, AuthStatus.unauthenticated, reason: 'write 401 -> signed out');

      // a message send
      final h3 = await signedIn();
      DioService.onUnauthorized = h3.auth.handleUnauthorized;
      await expectLater(MessagingRepository(client).sendMessage('64a0000000000000000000c1', 'hello'), throwsA(isA<ApiException>()));
      await pumpEventQueue();
      expect(h3.auth.status.value, AuthStatus.unauthenticated);
      expect(adapter.calls, 4);
      DioService.onUnauthorized = null;
    });
  });

  test('LeaveController on a real offline repository: both sections carry the offline message', () async {
    final net = FailingClient(NetFail.offline);
    final c = LeaveController(repository: LeaveRepository(net));
    await c.reload(userInitiated: true);
    expect(c.balance.value.message, contains('No internet'));
    expect(c.history.value.message, contains('No internet'));
  });
}
