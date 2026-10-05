import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../services/app_preferences.dart';

/// Marker placed in [DioException.error] when a request is rejected before
/// leaving the device because there is no network at all.
const String kNoInternetMarker = 'eldermin_no_internet';

/// Builds the single shared [Dio] instance every network call goes
/// through - timeouts, the bearer token, no-internet detection and the
/// "session died" 401 handling all live here so [BaseClient] stays a thin
/// HTTP wrapper.
///
/// Kept free of any dependency on GetX controllers (core must not depend
/// on features): [InitialBinding] wires [onUnauthorized] to the session
/// controller's logout once it's registered.
class DioService {
  DioService._();

  static void Function()? onUnauthorized;
  static Dio? _dio;

  /// Overridable in tests. Returns true when at least one network
  /// transport is available.
  static Future<bool> Function() hasConnection = _defaultHasConnection;

  static Future<bool> _defaultHasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // If the plugin itself fails, don't block the request - let Dio decide.
      return true;
    }
  }

  /// A 401 means "session expired" ONLY for an authenticated request that
  /// is not one of the public auth calls. A 401 from `POST /auth/login`
  /// (invalid credentials) or `/auth/reset-password` (bad token) must reach
  /// the form untouched.
  static bool shouldLogoutOn(RequestOptions options, int? statusCode) {
    if (statusCode != 401) return false;
    if (ApiConstants.isPublicAuthUrl(options.path)) return false;
    final requiresAuth = options.extra['requiresAuth'] ?? false;
    return requiresAuth == true;
  }

  static Dio getDio() => _dio ??= createDio();

  /// Public for tests; app code uses [getDio].
  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        sendTimeout: const Duration(milliseconds: ApiConstants.sendTimeout),
        headers: {'Accept': 'application/json'},
      ),
    );

    // Never stack interceptors (hot restart / re-creation safe).
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!await hasConnection()) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: kNoInternetMarker,
              ),
            );
          }
          final requiresAuth = options.extra['requiresAuth'] ?? false;
          if (requiresAuth == true) {
            final token = await AppPreferences.getAccessTokenAsync();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (shouldLogoutOn(error.requestOptions, error.response?.statusCode)) {
            debugPrint('401 on ${error.requestOptions.path} - ending session');
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
    return dio;
  }
}
