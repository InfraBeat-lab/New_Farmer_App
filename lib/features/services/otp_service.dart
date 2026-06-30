import 'dart:io'; // ← REQUIRED for HttpClient, X509Certificate
import 'package:dio/dio.dart';
import 'package:dio/io.dart'; // ← REQUIRED for IOHttpClientAdapter
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/utils/dio_config.dart';
import 'package:poultryos_farmer_app/models/about_app_model.dart';
import 'package:poultryos_farmer_app/models/about_company_model.dart';

class OtpService {
  final Dio _dio = Dio();
  final String serverLink;
  final int companyCode;

  OtpService({required this.serverLink, required this.companyCode}) {
    DioConfig.applyRobustSettings(_dio);
  }

  Future<String> generateOtp(String mobileNumber, String imeiNo) async {
    try {
      final response = await _dio.post(
        '$serverLink/get_otp',
        options: Options(headers: {'content-length': '0'}),
        queryParameters: {
          'mob_no': mobileNumber,
          'imei_no': imeiNo,
          'company_code': companyCode,
        },
      );
      return response.data.toString();
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw e.response!.data.toString();
      }
      throw "Failed to generate OTP. Please try again.";
    }
  }

  Future<Map<String, dynamic>> verifyOtp(
    String mobileNumber,
    String otp,
    String imeiNo,
    String version,
  ) async {
    try {
      final response = await _dio.post(
        '$serverLink/get_verify_user',
        options: Options(headers: {'content-length': '0'}),
        queryParameters: {
          'mob_no': mobileNumber,
          'otp_no': otp,
          'apk_version': version,
          'imei_no': imeiNo,
          'company_code': companyCode,
        },
      );
      return response.data;
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw e.response!.data.toString();
      }
      throw "Failed to verify OTP. Please try again.";
    }
  }

  Future<Map<String, dynamic>> resendOtp(
    String mobileNumber,
    String imeiNo,
  ) async {
    try {
      final response = await _dio.post(
        '$serverLink/get_otp',
        options: Options(headers: {'content-length': '0'}),
        queryParameters: {
          'mob_no': mobileNumber,
          'imei_no': imeiNo,
          'company_code': companyCode,
        },
      );
      return response.data;
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw e.response!.data.toString();
      }
      throw "Failed to resend OTP. Please try again.";
    }
  }

  Future<Map<String, dynamic>> getAppVersion(
    String apkVersion,
    int companyCode,
  ) async {
    try {
      final response = await _dio.post(
        '$serverLink/get_apk_version',
        options: Options(headers: {'content-length': '0'}),
        queryParameters: {
          'apk_version': apkVersion,
          'company_code': companyCode,
        },
      );
      return response.data;
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw e.response!.data.toString();
      }
      throw "Failed to get APK Version. Please try again.";
    }
  }

  /// =====================================================
  /// SAP Login - Integrated with ApiClient pattern
  /// Handles dynamic tempLink storage and session management
  /// =====================================================
  Future<Map<String, dynamic>> sapLogin(
    String tempLink,
    String mobileNumber,
    String imeiNo,
    String deviceId,
    String version,
  ) async {
    try {
      debugPrint('[sapLogin] Starting SAP login for mobile: $mobileNumber');

      // Step 1: Validate and construct SAP Service Layer URL
      final sapServiceUrl = _constructSapUrl(tempLink);
      debugPrint('[sapLogin] Using SAP URL: $sapServiceUrl');

      // Step 2: Create query parameters for SAP B1SL query
      final queryParameters = {
        r'$filter':
            "mobile eq '$mobileNumber' or pager eq '$mobileNumber' or homeTel eq '$mobileNumber'",
      };

      // Step 3: Fetch user data from SAP B1SL
      final userList = await _fetchUserFromSap(sapServiceUrl, queryParameters);

      if (userList.isEmpty) {
        throw "No user found for mobile number: $mobileNumber";
      }

      final user = userList.first as Map<String, dynamic>;

      // Step 4: Store tempLink for future ApiClient requests
      await _storeTempLink(tempLink);

      debugPrint('[sapLogin] Login successful for user: ${user['CardCode']}');
      return user;
    } catch (e) {
      debugPrint('[sapLogin] Login failed: $e');
      throw "SAP login failed: $e";
    }
  }

  /// Constructs proper SAP B1SL Service Layer URL
  String _constructSapUrl(String tempLink) {
    final uri = Uri.parse(tempLink);
    String url = '${uri.scheme}://${uri.host}:${uri.port}/b1s/v2/view.svc/';

    // Ensure proper format
    url = url.replaceAll('///', '//');
    return url;
  }

  /// Fetches user from SAP B1SL using custom Dio instance with SSL bypass
  Future<List<dynamic>> _fetchUserFromSap(
    String sapUrl,
    Map<String, dynamic> queryParams,
  ) async {
    try {
      final url = Uri.parse(
        '${sapUrl}B1_LoginViewB1SLQuery',
      ).replace(queryParameters: queryParams);

      debugPrint('[_fetchUserFromSap] Requesting: $url');

      // Create a Dio instance for this request (avoids interference with ApiClient's session)
      final tempDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Force fresh connections and robust settings (handles SSL bypass and timeouts)
      DioConfig.applyRobustSettings(tempDio);
      
      final response = await tempDio.get(url.toString());

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData is Map<String, dynamic> && jsonData['value'] != null) {
          return jsonData['value'] as List<dynamic>;
        }
        return [];
      } else {
        throw "Failed to fetch user. Status: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint('[_fetchUserFromSap] Error: $e');
      rethrow;
    }
  }

  /// Stores tempLink for later use by ApiClient
  Future<void> _storeTempLink(String tempLink) async {
    try {
      await LocalStorageService.setString('tempLink', tempLink);
      debugPrint('[sapLogin] tempLink stored in LocalStorage');
    } catch (e) {
      debugPrint('[sapLogin] Failed to store tempLink: $e');
      throw "Failed to store session: $e";
    }
  }

  Future<AboutCompanyModel> getAboutCompany() async {
    try {
      debugPrint("getAboutCompany");
      final response = await _dio.post(
        '$serverLink/about_company',
        options: Options(headers: {'content-length': '0'}),
        queryParameters: {'company_code': companyCode},
      );
      return AboutCompanyModel.fromJson(response.data);
    } catch (e) {
      debugPrint("getAboutCompany-e");
      debugPrint(e.toString());
      throw Exception('Failed to load about company data: $e');
    }
  }

  Future<AboutAppModel> getAboutApp() async {
    try {
      final version = LocalStorageService.getString('version') ?? '';

      final response = await _dio.post(
        '$serverLink/about_app',
        options: Options(headers: {'content-length': '0'}),
        queryParameters: {'apk_version': version},
      );

      if (response.statusCode == 200) {
        return AboutAppModel.fromJson(response.data);
      } else {
        throw Exception(
          'Failed to load about app data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching about app data: $e');
    }
  }
}
