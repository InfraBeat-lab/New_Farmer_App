import 'dart:convert';
import 'package:http/http.dart' as http;

class FarmSettingsApiService {
  static const String baseUrl = 'https://fastapi.poultryos.in';

  static Future<Map<String, dynamic>> createSettings({
    required int farmerId,
    String? currencyCode,
    String? languageCode,
    String? timezone,
    String? weightUnit,
    String? feedUnit,
    String? tempUnit,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/farm-settings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'farmer_id': farmerId,
          if (currencyCode != null) 'currency_code': currencyCode,
          if (languageCode != null) 'language_code': languageCode,
          if (timezone != null) 'timezone': timezone,
          if (weightUnit != null) 'weight_unit': weightUnit,
          if (feedUnit != null) 'feed_unit': feedUnit,
          if (tempUnit != null) 'temp_unit': tempUnit,
        }),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        return {
          'success': false,
          'message': 'Server error: ${res.statusCode}',
        };
      }

      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSettings(int farmerId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/farm-settings/$farmerId'),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      return {
        'success': false,
        'message': 'Server error: ${res.statusCode}',
      };
    }

    return jsonDecode(res.body);
  }
}
