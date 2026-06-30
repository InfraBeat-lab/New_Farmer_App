import 'package:flutter/material.dart';
import 'package:poultryos_farmer_app/core/config/app_config.dart';
import 'package:poultryos_farmer_app/features/home/data/api_status.model.dart';

import 'package:http/http.dart' as http;

class HealthCheckService {
  static Future<List<ApiStatus>> checkApis() async {
    final results = await Future.wait([
      _checkUrl(
        name: 'OTP API',
        url: AppConfig.otpHealthUrl,
      ),
      // _checkUrl(
      //   name: 'POS ERP API',
      //   url: AppConfig.posHealthUrl,
      // ),
    ]);

    return results;
  }

  static Future<ApiStatus> _checkUrl({
    required String name,
    required String url,
  }) async {
    try {
      debugPrint('🔍 Checking URL: $url');

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      debugPrint('✅ $name - Status: ${response.statusCode}');

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      return ApiStatus(
        name: name,
        url: url,
        isUp: isSuccess,
        error: isSuccess ? null : 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('❌ $name - Error: $e');

      return ApiStatus(
        name: name,
        url: url,
        isUp: false,
        error: e.toString(),
      );
    }
  }
}
