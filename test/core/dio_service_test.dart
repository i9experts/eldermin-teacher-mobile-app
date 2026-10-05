import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:eldermin_teacher_app/core/constants/api_constants.dart';
import 'package:eldermin_teacher_app/core/network/api_exception.dart';
import 'package:eldermin_teacher_app/core/network/dio_exception_handler.dart';
import 'package:eldermin_teacher_app/core/network/dio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusAdapter implements HttpClientAdapter {
  final int status;
  int calls = 0;
  String? lastAuthHeader;
  _StatusAdapter(this.status);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    lastAuthHeader = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(jsonEncode({'message': 'x'}), status,
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
}
