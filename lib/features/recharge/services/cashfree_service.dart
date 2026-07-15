// lib/features/recharge/services/cashfree_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CashfreeOrderResult {
  final bool success;
  final String? orderId;
  final String? paymentSessionId;
  final bool isProduction;
  final String? error;

  CashfreeOrderResult({
    required this.success,
    this.orderId,
    this.paymentSessionId,
    this.isProduction = false,
    this.error,
  });
}

class CashfreeService {
  static String get _apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  static Future<CashfreeOrderResult> createOrder({
    required double amount,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    List<Map<String, dynamic>>? cart,
    String? couponCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/v1/payments/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_email': customerEmail,
          'cart': cart,
          'coupon_code': couponCode,
        }),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return CashfreeOrderResult(
          success: true,
          orderId: json['order_id'] as String?,
          paymentSessionId: json['payment_session_id'] as String?,
          isProduction: json['is_production'] as bool? ?? false,
        );
      }
      return CashfreeOrderResult(
          success: false,
          error: json['detail']?.toString() ?? 'Order creation failed');
    } catch (e) {
      return CashfreeOrderResult(success: false, error: e.toString());
    }
  }
}
