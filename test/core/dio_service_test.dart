import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/constants/api_constants.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/base_client.dart';
import 'package:eldermin_teacher_app/core/services/auth_api_service.dart';
import 'package:eldermin_teacher_app/core/network/dio_exception_handler.dart';
import 'package:eldermin_teacher_app/core/network/dio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusAdapter implements HttpClientAdapter {
  final int status;
  Map<String, Object?> body = {'message': 'x'};
  int calls = 0;
  String? lastAuthHeader;
  _StatusAdapter(this.status);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    lastAuthHeader = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(jsonEncode(body), status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage has no platform in unit tests: serve a token.
  setUpAll(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'tok123' : null,
    );
  });

  late int logouts;
  setUp(() {
    logouts = 0;
    DioService.onUnauthorized = () => logouts++;
    DioService.hasConnection = () async => true;
  });

  test('createDio clears interceptors (exactly one of ours)', () {
    final dio = DioService.createDio();
    // Dio's own ImplyContentTypeInterceptor + ours; creating again must not stack.
    final first = dio.interceptors.length;
    final again = DioService.createDio();
    expect(again.interceptors.length, first);
  });

  group('shouldLogoutOn', () {
    RequestOptions req(String path, {bool auth = true}) =>
        RequestOptions(path: path, extra: {'requiresAuth': auth});

    test('401 on authenticated request logs out', () {
      expect(DioService.shouldLogoutOn(req(ApiConstants.staffMe), 401), isTrue);
    });
    test('401 from POST /auth/login never logs out (invalid credentials)', () {
      expect(DioService.shouldLogoutOn(req(ApiConstants.login, auth: false), 401), isFalse);
      expect(DioService.shouldLogoutOn(req(ApiConstants.login, auth: true), 401), isFalse);
    });
    test('401 from forgot-password / reset-password never logs out (invalid/expired token)', () {
      for (final url in [ApiConstants.forgotPassword, ApiConstants.resetPassword]) {
        expect(DioService.shouldLogoutOn(req(url, auth: false), 401), isFalse);
        expect(DioService.shouldLogoutOn(req(url, auth: true), 401), isFalse);
      }
    });
    test('unauthenticated requests and other statuses do not log out', () {
      expect(DioService.shouldLogoutOn(req('/x', auth: false), 401), isFalse);
      expect(DioService.shouldLogoutOn(req(ApiConstants.staffMe), 403), isFalse);
      expect(DioService.shouldLogoutOn(req(ApiConstants.staffMe), 500), isFalse);
    });
  });

  test('interceptor: login 401 does not call onUnauthorized, /me 401 does', () async {
    final dio = DioService.createDio();
    dio.httpClientAdapter = _StatusAdapter(401);

    await expectLater(
      dio.post(ApiConstants.login, options: Options(extra: {'requiresAuth': false})),
      throwsA(isA<DioException>()),
    );
    expect(logouts, 0);

    await expectLater(
      dio.get(ApiConstants.staffMe, options: Options(extra: {'requiresAuth': true})),
      throwsA(isA<DioException>()),
    );
    expect(logouts, 1);
  });

  group('account states on authenticated calls (A1 item 6)', () {
    late List<String> suspended;
    late int inactive;
    setUp(() {
      suspended = [];
      inactive = 0;
      DioService.onSchoolSuspended = suspended.add;
      DioService.onAccountInactive = () => inactive++;
    });
    tearDown(() {
      DioService.onSchoolSuspended = null;
      DioService.onAccountInactive = null;
    });

    Future<void> call(_StatusAdapter a, {String url = ApiConstants.staffMe, bool auth = true}) async {
      final dio = DioService.createDio()..httpClientAdapter = a;
      await expectLater(dio.get(url, options: Options(extra: {'requiresAuth': auth})), throwsA(isA<DioException>()));
    }

    test('403 with the server\'s suspended wording (the filter drops the code) -> onSchoolSuspended with that message', () async {
      await call(_StatusAdapter(403)..body = {'statusCode': 403, 'message': "Your school's account is currently suspended. Please contact your school administration."});
      expect(suspended, ["Your school's account is currently suspended. Please contact your school administration."]);
      expect(logouts, 0);
    });

    test('403 carrying code SCHOOL_SUSPENDED is recognised even with other wording', () async {
      await call(_StatusAdapter(403)..body = {'message': 'Blocked', 'code': 'SCHOOL_SUSPENDED'});
      expect(suspended, ['Blocked']);
    });

    test('an ordinary 403 (Forbidden resource) and a suspended-looking 403 on login do not trigger it', () async {
      await call(_StatusAdapter(403)..body = {'message': 'Forbidden resource'});
      await call(_StatusAdapter(403)..body = {'message': "This school's account is suspended — please contact your school"}, url: ApiConstants.login, auth: false);
      await call(_StatusAdapter(403)..body = {'message': "This school's account is suspended — please contact your school"}, url: ApiConstants.login, auth: true);
      expect(suspended, isEmpty);
    });

    test('401 "This account is no longer active." -> onAccountInactive, not the generic onUnauthorized', () async {
      await call(_StatusAdapter(401)..body = {'statusCode': 401, 'message': 'This account is no longer active.'});
      expect(inactive, 1);
      expect(logouts, 0);
    });

    test('any other 401 (session ended, invalid token) still ends the session the generic way', () async {
      await call(_StatusAdapter(401)..body = {'message': 'Your session has ended. Please sign in again.'});
      expect(inactive, 0);
      expect(logouts, 1);
    });

    test('without an inactive hook the generic 401 handler runs (never a stuck session)', () async {
      DioService.onAccountInactive = null;
      await call(_StatusAdapter(401)..body = {'message': 'This account is no longer active.'});
      expect(logouts, 1);
    });
  });

  test('interceptor adds Bearer token from secure storage', () async {
    final adapter = _StatusAdapter(200);
    final dio = DioService.createDio()..httpClientAdapter = adapter;
    await dio.get(ApiConstants.staffMe, options: Options(extra: {'requiresAuth': true}));
    expect(adapter.lastAuthHeader, 'Bearer tok123');
    await dio.get(ApiConstants.login, options: Options(extra: {'requiresAuth': false}));
    expect(adapter.lastAuthHeader, isNull);
  });

  test('no internet is rejected before sending and mapped to a clear message', () async {
    DioService.hasConnection = () async => false;
    final adapter = _StatusAdapter(200);
    final dio = DioService.createDio()..httpClientAdapter = adapter;
    try {
      await dio.get(ApiConstants.staffMe, options: Options(extra: {'requiresAuth': true}));
      fail('should throw');
    } on DioException catch (e) {
      expect(adapter.calls, 0);
      final api = DioExceptionHandler.handle(e);
      expect(api, isA<ApiException>());
      expect(api.message, contains('No internet'));
    }
    expect(logouts, 0);
  });

  test('token deep-link check sends the supplied JWT (not the stored one) and a 401 is not a session expiry', () async {
    final adapter = _StatusAdapter(401);
    DioService.getDio().httpClientAdapter = adapter;
    final api = AuthApiService(BaseClient());
    await expectLater(api.fetchAuthMe(token: 'link.jwt.value'), throwsA(isA<ApiException>()));
    expect(adapter.lastAuthHeader, 'Bearer link.jwt.value');
    expect(logouts, 0);
  });

  test('reset-password 401 reaches the caller with the server message and does not log out', () async {
    final adapter = _StatusAdapter(401);
    DioService.getDio().httpClientAdapter = adapter;
    final api = AuthApiService(BaseClient());
    try {
      await api.resetPassword(token: 'tttttttttt', newPassword: 'secret1');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.statusCode, 401);
    }
    expect(logouts, 0);
  });
}
