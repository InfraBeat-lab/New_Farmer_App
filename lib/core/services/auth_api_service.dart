import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result wrapper returned by every AuthApiService call.
class AuthApiResult {
  final bool success;
  final String? token;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  AuthApiResult({
    required this.success,
    this.token,
    this.user,
    this.errorMessage,
  });
}

/// Talks to the FastAPI auth backend (see /backend in this delivery).
class AuthApiService {
  // Android emulator -> host machine: 10.0.2.2
  // iOS simulator / desktop -> localhost
  // Physical device -> your machine's LAN IP
  // Replace with your deployed API URL for production builds.
  static const String baseUrl = 'https://fastapi.poultryos.in';

  static Future<AuthApiResult> signup({
    required String name,
    String? email,
    String? mobile,
    String? password,
    String? pin,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (password != null && password.isNotEmpty) 'password': password,
          if (pin != null && pin.isNotEmpty) 'pin': pin,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 201) {
        return AuthApiResult(
          success: true,
          token: body['access_token'] as String?,
          user: body['user'] as Map<String, dynamic>?,
        );
      }

      return AuthApiResult(
        success: false,
        errorMessage: _extractError(body),
      );
    } catch (e) {
      return AuthApiResult(success: false, errorMessage: 'Network error: $e');
    }
  }

  static Future<AuthApiResult> login({
    required String identifier,
    required String credential,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'credential': credential,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        return AuthApiResult(
          success: true,
          token: body['access_token'] as String?,
          user: body['user'] as Map<String, dynamic>?,
        );
      }

      return AuthApiResult(
        success: false,
        errorMessage: _extractError(body),
      );
    } catch (e) {
      return AuthApiResult(success: false, errorMessage: 'Network error: $e');
    }
  }

  static String _extractError(Map<String, dynamic> body) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      // FastAPI/pydantic validation error format
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return first['msg'].toString();
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
