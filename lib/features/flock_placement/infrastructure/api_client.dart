import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/utils/dio_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  ApiClient() {
    _dio = Dio();
    _dio.options.baseUrl =
        dotenv.env['SAP_BASE_URL'] ?? 'https://175.100.181.203:50000/b1s/v2/';
    DioConfig.applyRobustSettings(_dio);

    // Add interceptor for better error handling and response body management
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );

    // Add specific custom interceptors
    _dio.interceptors.add(_RequestCounterInterceptor());
    _dio.interceptors.add(_ConnectionHealthInterceptor());
  }

  late Dio _dio;
  String? _sessionId;
  String? _currentTempLink;

  /// Load session ID from SharedPreferences and set cookie header
  /// Also sets the baseUrl dynamically if tempLink is available
  Future<void> _loadSession() async {
    // Dynamically set baseUrl if tempLink exists from successful OTP/SAP login
    final tempLink = LocalStorageService.getString('tempLink');
    if (tempLink != null && tempLink.isNotEmpty) {
      String dynamicBaseUrl = tempLink;
      if (!dynamicBaseUrl.endsWith('/')) {
        dynamicBaseUrl += '/';
      }
      // Ensure it points to the Service Layer b1s path
      if (!dynamicBaseUrl.contains('b1s/v2')) {
        dynamicBaseUrl += 'b1s/v2/';
      }

      if (_dio.options.baseUrl != dynamicBaseUrl) {
        _dio.options.baseUrl = dynamicBaseUrl;
        _currentTempLink = tempLink;
        debugPrint('[ApiClient] Using dynamic baseUrl: $dynamicBaseUrl');
      }
    } else {
      // Fallback to initial baseUrl if tempLink is cleared
      final defaultBaseUrl =
          dotenv.env['SAP_BASE_URL'] ?? 'https://175.100.181.203:50000/b1s/v2/';
      if (_dio.options.baseUrl != defaultBaseUrl) {
        _dio.options.baseUrl = defaultBaseUrl;
        _currentTempLink = null;
      }
    }

    // Load session ID from AuthToken (dynamic login) or fallback to session_id (static login)
    _sessionId = LocalStorageService.getString('AuthToken') ??
        LocalStorageService.getString('session_id');

    if (_sessionId != null) {
      _dio.options.headers['Cookie'] = 'B1SESSION=$_sessionId';
      debugPrint('[ApiClient] Session loaded and cookie set');
    }
  }

  /// Login to SAP B1 and store session in SharedPreferences
  Future<String?> login() async {
    try {
      debugPrint('[ApiClient.login] Attempting SAP B1 login');
      final response = await _dio.post(
        'Login',
        data: {
          'UserName': dotenv.env['SAP_USER_NAME'] ?? 'manager',
          'Password': dotenv.env['SAP_PASSWORD'] ?? 'Office2016',
          'CompanyDB': dotenv.env['SAP_COMPANY_DB'] ?? 'kkcklive070623',
        },
      );

      if (response.statusCode == 200) {
        _sessionId = response.data['SessionId'];

        // ✅ Save session ID to LocalStorage
        await LocalStorageService.setString('session_id', _sessionId!);
        await LocalStorageService.setInt('IsLogin', 1);

        // ✅ Set cookie for all future requests
        _dio.options.headers['Cookie'] = 'B1SESSION=$_sessionId';

        debugPrint(
          '[ApiClient.login] Login successful. Session ID: $_sessionId',
        );
      }
    } catch (e) {
      debugPrint('[ApiClient.login] Login failed: $e');
      rethrow;
    }
    return null;
  }


  /// Verify if current session is valid
  Future<bool> isSessionValid() async {
    try {
      await _loadSession();
      if (_sessionId == null) {
        return false;
      }

      // Quick check by making a simple request
      final response = await _dio.get(
        'CompanyInfo',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiClient.isSessionValid] Session validation failed: $e');
      return false;
    }
  }

  /// Clear all stored sessions and preferences
  Future<void> clearSession() async {
    try {
      await LocalStorageService.remove('tempLink');
      await LocalStorageService.remove('AuthToken');
      await LocalStorageService.remove('session_id');
      await LocalStorageService.remove('IsLogin');

      _sessionId = null;
      _currentTempLink = null;

      debugPrint('[ApiClient] Session cleared');
    } catch (e) {
      debugPrint('[ApiClient] Failed to clear session: $e');
    }
  }

  /// Generic GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // ✅ Always load session from SharedPreferences first
      await _loadSession();

      if (_sessionId == null) {
        await login();
      }

      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Session expired — re-login and retry
        debugPrint('[ApiClient.get] Session expired, attempting re-login');
        await login();
        return await _dio.get(path, queryParameters: queryParameters);
      }
      rethrow;
    }
  }

  Future<Response> getView(
    String viewName, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      await _loadSession();

      if (_sessionId == null) {
        await login();
      }

      // ── Build view.svc URL from existing baseUrl ───────────────
      final baseUri = Uri.parse(_dio.options.baseUrl);
      final viewSvcUrl =
          '${baseUri.scheme}://${baseUri.host}:${baseUri.port}/b1s/v2/view.svc/$viewName';

      debugPrint('[ApiClient.getView] URL: $viewSvcUrl');
      debugPrint('[ApiClient.getView] Params: $queryParameters');

      // ── Use same session cookie ────────────────────────────────
      return await _dio.get(
        viewSvcUrl,
        queryParameters: queryParameters,
        options: Options(headers: {'Cookie': 'B1SESSION=$_sessionId'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[ApiClient.getView] Session expired, re-login');
        await login();
        final baseUri = Uri.parse(_dio.options.baseUrl);
        final viewSvcUrl =
            '${baseUri.scheme}://${baseUri.host}:${baseUri.port}/b1s/v2/view.svc/$viewName';
        return await _dio.get(
          viewSvcUrl,
          queryParameters: queryParameters,
          options: Options(headers: {'Cookie': 'B1SESSION=$_sessionId'}),
        );
      }
      rethrow;
    }
  }

  /// Generic POST request
  Future<Response> post(
    String path,
    dynamic data, {
    Map<String, String>? headers,
  }) async {
    try {
      // ✅ Always load session from SharedPreferences first
      await _loadSession();

      if (_sessionId == null) {
        await login();
      }

      final options = headers != null ? Options(headers: headers) : null;

      return await _dio.post(path, data: data, options: options);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Session expired — re-login and retry
        debugPrint('[ApiClient.post] Session expired, attempting re-login');
        await login();
        final options = headers != null ? Options(headers: headers) : null;
        return await _dio.post(path, data: data, options: options);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadAttachment(File file) async {
    await _loadSession();

    if (_sessionId == null) {
      await login();
    }

    // 🔥 Use dynamic base URL (same as rest of API client)
    final baseUrl = _dio.options.baseUrl;
    final uri = Uri.parse(
      '$baseUrl/Attachments2'
          .replaceFirst('Attachments2Attachments2', 'Attachments2'),
    );

    final HttpClient client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    final request = await client.postUrl(uri);

    // 🔑 SAP session (dynamic)
    request.headers.set(
      HttpHeaders.cookieHeader,
      'B1SESSION=$_sessionId',
    );

    // 🔥 FIXED boundary (manual safe boundary)
    const boundary = "SAPBoundary12345";

    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    final fileName = file.path.split(Platform.pathSeparator).last;
    final bytes = await file.readAsBytes();

    final body = StringBuffer();

    body.writeln('--$boundary');
    body.writeln(
      'Content-Disposition: form-data; name="files"; filename="$fileName"',
    );
    body.writeln('Content-Type: application/octet-stream');
    body.writeln();
    body.write(utf8.decode(bytes, allowMalformed: true));
    body.writeln();
    body.writeln('--$boundary--');

    request.add(utf8.encode(body.toString()));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed: $responseBody');
    }

    return jsonDecode(responseBody);
  }

  /// Generic PATCH request with timeout options
  Future<Response> patch(
    String path,
    dynamic data, {
    Map<String, String>? headers,
    Duration? receiveTimeout,
    Duration? sendTimeout,
  }) async {
    try {
      await _loadSession();

      if (_sessionId == null) {
        await login();
      }

      final options = Options(
        headers: headers,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
      );

      return await _dio.patch(path, data: data, options: options);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[ApiClient.patch] Session expired, attempting re-login');
        await login();
        final options = Options(
          headers: headers,
          receiveTimeout: receiveTimeout,
          sendTimeout: sendTimeout,
        );
        return await _dio.patch(path, data: data, options: options);
      }
      rethrow;
    }
  }

  /// Generic PUT request
  Future<Response> put(
    String path,
    dynamic data, {
    Map<String, String>? headers,
  }) async {
    try {
      await _loadSession();

      if (_sessionId == null) {
        await login();
      }

      final options = headers != null ? Options(headers: headers) : null;

      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[ApiClient.put] Session expired, attempting re-login');
        await login();
        final options = headers != null ? Options(headers: headers) : null;
        return await _dio.put(path, data: data, options: options);
      }
      rethrow;
    }
  }

  /// Generic DELETE request
  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      await _loadSession();

      if (_sessionId == null) {
        await login();
      }

      return await _dio.delete(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[ApiClient.delete] Session expired, attempting re-login');
        await login();
        return await _dio.delete(path, queryParameters: queryParameters);
      }
      rethrow;
    }
  }

  /// Logout from SAP B1 and clear session from SharedPreferences
  Future<void> logout() async {
    try {
      debugPrint('[ApiClient.logout] Attempting logout');
      await _dio.post('Logout');
      await clearSession();
    } catch (e) {
      debugPrint('[ApiClient.logout] Logout failed: $e');
      // Clear session anyway
      await clearSession();
    }
  }

  /// Get current session info (for debugging)
  Map<String, dynamic> getSessionInfo() {
    return {
      'sessionId': _sessionId,
      'tempLink': _currentTempLink,
      'baseUrl': _dio.options.baseUrl,
      'isLoggedIn': _sessionId != null,
    };
  }
}

/// Request interceptor to initialize retry tracking
class _RequestCounterInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Initialize retry count for this request
    options.extra['retryCount'] = options.extra['retryCount'] ?? 0;
    return handler.next(options);
  }
}

/// Response interceptor to ensure proper connection health
class _ConnectionHealthInterceptor extends Interceptor {
  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // Ensure response data is consumed to prevent connection state issues
    try {
      if (response.data is String && (response.data as String).isNotEmpty) {
        debugPrint(
          '[ConnectionHealthInterceptor] Response consumed: ${(response.data as String).length} bytes',
        );
      } else if (response.data is Map) {
        // Data is already parsed as map
      }
    } catch (e) {
      debugPrint('[ConnectionHealthInterceptor] Error consuming response: $e');
    }
    return handler.next(response);
  }
}
