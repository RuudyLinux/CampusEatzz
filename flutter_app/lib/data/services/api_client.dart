import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/constants/api_config.dart';
import 'app_preferences.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'session_expired';
}

class ApiClient {
  ApiClient(this._preferences)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 35),
            sendTimeout: const Duration(seconds: 30),
            headers: const <String, dynamic>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

  final AppPreferences _preferences;
  final Dio _dio;

  Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    dynamic data,
    bool authenticated = true,
    Map<String, dynamic>? headers,
    String? bearerTokenOverride,
  }) async {
    final savedBase = await _preferences.getApiBase();
    final allCandidates = ApiConfig.allBaseUrls(savedBase);
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    // FormData is consumed (finalized) after first send — never retry with fallback URLs.
    // Multipart uploads must only attempt the primary/saved base.
    final candidates = data is FormData ? [allCandidates.first] : allCandidates;

    Object? lastError;
    Response<dynamic>? lastFallbackResponse;

    for (final base in candidates) {
      final url = '$base$normalizedPath';
      try {
        final requestHeaders = <String, dynamic>{
          ...?headers,
        };
        if (authenticated) {
          final overrideToken = (bearerTokenOverride ?? '').trim();
          if (overrideToken.isNotEmpty) {
            requestHeaders['Authorization'] = 'Bearer $overrideToken';
          } else {
            final session = await _preferences.getSession();
            if (session != null && session.token.trim().isNotEmpty) {
              requestHeaders['Authorization'] = 'Bearer ${session.token}';
            }
          }
        }

        final response = await _dio.request<dynamic>(
          url,
          data: data,
          queryParameters: queryParameters,
          options: Options(method: method, headers: requestHeaders),
        );

        await _preferences.setApiBase(base);
        return response;
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;

        if (status == 401) {
          // Token expired or invalid — clear saved session so next restoreSession forces re-login
          await _preferences.clearSession();
          throw const SessionExpiredException();
        }

        if (status == 404 || status == 405 || status == 0) {
          lastFallbackResponse = e.response;
          lastError = e;
          continue;
        }

        if (e.response != null) {
          await _preferences.setApiBase(base);
          return e.response!;
        }

        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastFallbackResponse != null) {
      return lastFallbackResponse;
    }

    // Determine if this looks like a pure connectivity failure or a cold-start timeout
    final lastErrorText = (lastError ?? '').toString().toLowerCase();
    final isConnectionRefused = lastErrorText.contains('connection refused')
        || lastErrorText.contains('connection error')
        || lastErrorText.contains('socketexception')
        || lastErrorText.contains('failed host lookup')
        || lastErrorText.contains('network is unreachable');
    final isTimeout = lastErrorText.contains('timeout') || lastErrorText.contains('timed out');

    if (isTimeout) {
      throw Exception(
        'Server is waking up after a period of inactivity. Please wait 30 seconds and try again.',
      );
    }

    if (isConnectionRefused) {
      throw Exception(
        'No internet connection or server unreachable. Please check your connection and try again.',
      );
    }

    throw Exception('Unable to reach the server. Please check your internet connection and try again.');
  }
}
