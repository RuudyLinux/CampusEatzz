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
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 12),
            sendTimeout: const Duration(seconds: 12),
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
    final candidates = ApiConfig.allBaseUrls(savedBase);
    final normalizedPath = path.startsWith('/') ? path : '/$path';

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

    final attemptedBases = candidates.join(', ');
    final lastErrorText = (lastError ?? '').toString().trim();
    throw Exception(
      lastErrorText.isEmpty
          ? 'Unable to reach backend server. Please start backend_api.bat and ensure phone + PC are on same Wi-Fi. Tried: $attemptedBases'
          : 'Unable to reach backend server. Please start backend_api.bat and ensure phone + PC are on same Wi-Fi. Tried: $attemptedBases. Last error: $lastErrorText',
    );
  }
}
