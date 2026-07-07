import 'dart:convert';
import 'package:http/http.dart' as http;

class FarmerApiService {
  static const String baseUrl = 'https://fastapi.poultryos.in';

  /// CREATE FARMER PROFILE
  static Future<Map<String, dynamic>> createFarmer({
    required String farmerName,
    required String mobile,
    String? email,
    String? address,
    int? countryId,
    String? state,
    String? city,
    String? pincode,
    String? gstNumber,
    String? panNumber,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/farmers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'farmer_name': farmerName,
          'mobile_number': mobile,
          if (email != null) 'email_address': email,
          if (address != null) 'address': address,
          if (countryId != null) 'country_id': countryId,
          if (state != null) 'state': state,
          if (city != null) 'city': city,
          if (pincode != null) 'pincode': pincode,
          if (gstNumber != null) 'gst_number': gstNumber,
          if (panNumber != null) 'pan_number': panNumber,
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

  /// GET FARMER
  static Future<Map<String, dynamic>> getFarmer(int id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/farmers/$id'),
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
