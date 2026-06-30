import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

class DioConfig {
  /// Applies robust networking settings to a Dio instance to prevent
  /// "Connection closed before full header was received" errors,
  /// especially common with SAP Business One Service Layer.
  static void applyRobustSettings(Dio dio) {
    dio.options.persistentConnection = false;
    dio.options.connectTimeout = const Duration(seconds: 60);
    dio.options.receiveTimeout = const Duration(seconds: 120);
    dio.options.sendTimeout = const Duration(seconds: 60);
    
    // Set standard headers
    dio.options.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Flutter-Dio/${dio.options.headers['User-Agent'] ?? '5.9.2'}',
      'Connection': 'close',
    });

    // Configure HttpClient adapter
    if (dio.httpClientAdapter is IOHttpClientAdapter) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        
        // Disable SSL certificate verification (needed for many SAP installations)
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

        // Force fresh connections but allow a small pool for concurrency
        client.idleTimeout = Duration.zero;
        client.maxConnectionsPerHost = 5; // Increased from 1 to avoid queueing timeouts
        client.connectionTimeout = const Duration(seconds: 60);

        return client;
      };
    }

    // Add robustness interceptors if not already present
    bool hasHttpRetry = dio.interceptors.any((i) => i is _HttpExceptionRetryInterceptor);
    if (!hasHttpRetry) {
      dio.interceptors.add(_HttpExceptionRetryInterceptor(dio));
    }
  }
}

/// Interceptor that specifically catches connection reset errors
/// and retries the request once with a fresh connection.
class _HttpExceptionRetryInterceptor extends Interceptor {
  final Dio _dio;
  _HttpExceptionRetryInterceptor(this._dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final errorMessage = err.message?.toLowerCase() ?? '';
    final errorString = err.error?.toString().toLowerCase() ?? '';

    // Check for connection reset OR connection timeout
    bool shouldRetry =
        errorMessage.contains('connection closed before full header') ||
        errorString.contains('connection closed before full header') ||
        errorMessage.contains('connection reset by peer') ||
        errorString.contains('connection reset by peer') ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (shouldRetry) {
      int retryCount = err.requestOptions.extra['connectionRetryCount'] ?? 0;
      
      if (retryCount < 2) {
        err.requestOptions.extra['connectionRetryCount'] = retryCount + 1;
        debugPrint('[DioConfig] 🔄 Retrying due to ${err.type} (attempt ${retryCount + 1})');
        
        await Future.delayed(const Duration(milliseconds: 1000));
        
        try {
          final response = await _dio.fetch(err.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          return handler.next(err);
        }
      }
    }
    
    return handler.next(err);
  }
}
