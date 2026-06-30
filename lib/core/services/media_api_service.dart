import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';
import 'package:poultryos_farmer_app/core/utils/dio_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class MediaApiService {
  static final Dio _dio = _initDio();

  static Dio _initDio() {
    final dio = Dio();

    DioConfig.applyRobustSettings(dio);

    // ✅ Add logger ONLY in debug mode
    if (kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 120,
        ),
      );
    }

    return dio;
  }

  /// Retrieves POS ERP auth tokens, performing login if necessary.
  static Future<Map<String, String>> _getPosAuthTokens() async {
    // 1. Try to get from local storage first
    String? cToken = LocalStorageService.getString('pos_c_token');
    String? accessToken = LocalStorageService.getString('pos_x_access_token');

    if (cToken != null &&
        accessToken != null &&
        cToken.isNotEmpty &&
        accessToken.isNotEmpty) {
      debugPrint('[MediaApiService] Using cached POS tokens');
      return {
        'c-token': cToken,
        'x-access-token': accessToken,
      };
    }

    debugPrint(
        '[MediaApiService] POS tokens not found/invalid, performing login...');

    final serverLink =
        (dotenv.env['POS_ERP_LINK'] ?? 'https://api.poultryos.in')
            .trim();
    if (serverLink.endsWith('/')) {
      // Ensure no trailing slash for endpoint concatenation if needed,
      // but here we use it as base.
    }

    final baseUrl = serverLink.endsWith('/')
        ? serverLink.substring(0, serverLink.length - 1)
        : serverLink;
    final companyCode = dotenv.env['POS_ERP_COMPANY_CODE'] ?? '';
    final username = dotenv.env['POS_ERP_MOBILE'] ?? '';
    final password = dotenv.env['POS_ERP_PASSWORD'] ?? '';

    try {
      // Step 1: Validate Company
      debugPrint('[MediaApiService] Validating company: $companyCode');
      final validateRes = await _dio.post(
        '$baseUrl/login/validatecompany',
        data: {'companycode': companyCode},
      );

      if (validateRes.statusCode != 200) {
        throw Exception('Company validation failed: ${validateRes.statusCode}');
      }

      final validateData = validateRes.data;
      final String initialToken = validateData['token'] ?? '';
      final dynamic companyId = validateData['companyid'];

      await LocalStorageService.setString(
        'pos_company_id',
        companyId.toString(),
      );

      if (initialToken.isEmpty) {
        throw Exception('No token received from validatecompany');
      }

      // Step 2: Login User
      debugPrint('[MediaApiService] Logging in user: $username');
      debugPrint('Initial Token: $initialToken');
      debugPrint('Company ID: $companyId');
      debugPrint('Company Code: $companyCode');
      debugPrint('Password: $password');
      final loginRes = await _dio.post(
        '$baseUrl/login/user',
        data: {
          "username": username,
          "pwd": password,
          "companycode": companyCode,
          "companyid": companyId,
          "token": initialToken,
          "userkey": ""
        },
      );

      if (loginRes.statusCode != 200) {
        throw Exception('User login failed: ${loginRes.statusCode}');
      }

      final loginData = loginRes.data;
      final String finalAccessToken = loginData['token'] ?? '';
      final String finalCToken = loginData['ctoken'] ?? initialToken;

      if (finalAccessToken.isEmpty) {
        throw Exception('No access token received from login/user');
      }

      // 3. Cache tokens
      await LocalStorageService.setString('pos_c_token', finalCToken);
      await LocalStorageService.setString(
          'pos_x_access_token', finalAccessToken);

      debugPrint('[MediaApiService] POS ERP Login successful');

      return {
        'c-token': finalCToken,
        'x-access-token': finalAccessToken,
      };
    } catch (e) {
      debugPrint('[MediaApiService] POS Login Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> uploadMedia(
    File file, {
    required Map<String, dynamic> fields,
    String? customFileName,
  }) async {
    // Validate file exists
    if (!await file.exists()) {
      throw Exception('File does not exist: ${file.path}');
    }

    final fileName =
        customFileName ?? file.path.split(Platform.pathSeparator).last;
    final fileSize = await file.length();
    File fileToUpload = file;

    debugPrint('[MediaApiService] Starting upload...');
    debugPrint(
        '[MediaApiService] File: $fileName (original size: $fileSize bytes)');

    // Always compress images over 2MB to stay within server 10MB limit
    if (_isImageFile(file.path) && fileSize > 2 * 1024 * 1024) {
      debugPrint(
          '[MediaApiService] Image is large ($fileSize bytes). Compressing...');
      try {
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          final newSize = await fileToUpload.length();
          debugPrint('[MediaApiService] Compressed to $newSize bytes');
        }
      } catch (e) {
        debugPrint(
            '[MediaApiService] Warning: Compression failed: $e. Proceeding with original file.');
      }
    }

    debugPrint('[MediaApiService] Final file: ${fileToUpload.path}');

    final serverLink =
        dotenv.env['POS_ERP_LINK'] ?? 'https://api.poultryos.in';
    final uploadPath = '${serverLink}factormaster/upload/media';

    debugPrint('[MediaApiService] Upload endpoint: $uploadPath');
    debugPrint('[MediaApiService] Fields: $fields');

    try {
      // Create FormData with all fields
      final formData = FormData.fromMap({
        ...fields,
        'file': await MultipartFile.fromFile(
          fileToUpload.path,
          filename: fileName,
        ),
      });

      debugPrint('[MediaApiService] FormData created successfully');

      // Get mandatory POS auth tokens
      final authHeaders = await _getPosAuthTokens();

      final response = await _dio.post(
        uploadPath,
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'c-token': authHeaders['c-token'],
            'x-access-token': authHeaders['x-access-token'],
          },
        ),
        onSendProgress: (int sent, int total) {
          final progress = (sent / total * 100).toStringAsFixed(2);
          debugPrint(
              '[MediaApiService] Upload progress: $progress% ($sent/$total bytes)');
        },
      );

      debugPrint('[MediaApiService] Response status: ${response.statusCode}');
      debugPrint('[MediaApiService] Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[MediaApiService] ✅ Upload successful');
        return Map<String, dynamic>.from(response.data ?? {});
      } else {
        throw Exception(
          'Upload failed with status: ${response.statusCode}\n'
          'Response: ${response.data}',
        );
      }
    } on DioException catch (e) {
      debugPrint('[MediaApiService] ❌ Dio Error: ${e.type}');
      debugPrint('[MediaApiService] Message: ${e.message}');
      debugPrint('[MediaApiService] Response: ${e.response?.data}');
      debugPrint('[MediaApiService] Status Code: ${e.response?.statusCode}');

      // If unauthorized, clear cached tokens
      if (e.response?.statusCode == 401) {
        await LocalStorageService.remove('pos_c_token');
        await LocalStorageService.remove('pos_x_access_token');
        debugPrint('[MediaApiService] 401 Unauthorized: Cleared POS tokens');
      }

      // Provide more specific error messages
      String errorMsg;
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Connection timeout - server not responding';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMsg = 'Receive timeout - slow connection';
      } else if (e.type == DioExceptionType.sendTimeout) {
        errorMsg = 'Send timeout - file too large or slow connection';
      } else if (e.response != null) {
        errorMsg = 'Server error: ${e.response?.statusCode}';
      } else {
        errorMsg = 'Network error: ${e.message}';
      }

      throw Exception('Upload failed: $errorMsg');
    } catch (e) {
      debugPrint('[MediaApiService] ❌ Unexpected error: $e');
      throw Exception('Unexpected upload error: $e');
    } finally {
      // Clean up temporary compressed file if one was created
      if (fileToUpload.path != file.path) {
        try {
          if (await fileToUpload.exists()) {
            await fileToUpload.delete();
            debugPrint('[MediaApiService] Temporary compressed file deleted');
          }
        } catch (_) {}
      }
    }
  }

  static bool _isImageFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp');
  }

  static Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/C_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Compress to JPEG with 80% quality and resize if it's huge
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
    );

    if (result == null) return null;
    return File(result.path);
  }

  static Future<List<String>> fetchTagsByScreenName(String screenName) async {
    final serverLink =
        (dotenv.env['POS_ERP_LINK'] ?? 'https://api.poultryos.in')
            .trim();
    final baseUrl = serverLink.endsWith('/')
        ? serverLink.substring(0, serverLink.length - 1)
        : serverLink;

    try {
      final authHeaders = await _getPosAuthTokens();
      final response = await _dio.get(
        '$baseUrl/factormaster/searchactionmasterbyscreenname/$screenName',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'c-token': authHeaders['c-token'],
            'x-access-token': authHeaders['x-access-token'],
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data is List && data.isNotEmpty && data[0] is List) {
          final List<Map<String, dynamic>> list =
              List<Map<String, dynamic>>.from(data[0]);

          return list
              .map((e) => (e['ActionName'] ??
                      e['name'] ??
                      e['actionname'] ??
                      e['Action'] ??
                      e['action'] ??
                      '')
                  .toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        return [];
      }
    } catch (e) {
      debugPrint('[MediaApiService] fetchTagsByScreenName error: $e');
      return [];
    }

    // ✅ REQUIRED fallback
    return [];
  }

  /// Fetches action tag objects `{id, name}` for a given screen from the
  /// POS ERP action master API. Use this to populate `actionInfo` in upload
  /// payloads with real server-side action IDs instead of placeholder `1`.
  static Future<List<Map<String, dynamic>>> fetchActionsByScreenName(
      String screenName) async {
    final serverLink =
        (dotenv.env['POS_ERP_LINK'] ?? 'https://api.poultryos.in')
            .trim();
    final baseUrl = serverLink.endsWith('/')
        ? serverLink.substring(0, serverLink.length - 1)
        : serverLink;

    try {
      final authHeaders = await _getPosAuthTokens();
      final response = await _dio.get(
        '$baseUrl/factormaster/searchactionmasterbyscreenname/$screenName',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'c-token': authHeaders['c-token'],
            'x-access-token': authHeaders['x-access-token'],
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data[0] is List) {
          final List<Map<String, dynamic>> list =
              List<Map<String, dynamic>>.from(data[0]);
          return list
              .map((e) => {
                    'id': e['id'] ?? e['actionid'] ?? e['ActionId'] ?? 1,
                    'name': (e['ActionName'] ??
                            e['name'] ??
                            e['actionname'] ??
                            e['Action'] ??
                            e['action'] ??
                            '')
                        .toString(),
                  })
              .where((e) => (e['name'] as String).isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[MediaApiService] fetchActionsByScreenName error: $e');
      return [];
    }
  }
}
