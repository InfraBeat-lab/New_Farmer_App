import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get posErpBaseUrl {
    final url = dotenv.env['POS_ERP_LINK'] ?? 'https://api.poultryos.in';

    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static bool get isProduction =>
      posErpBaseUrl.contains('api.poultryos.in') &&
      !posErpBaseUrl.contains('staging');

  static String get sapHealthUrl => '$posErpBaseUrl/api/health/sap-b1';

  static String get posHealthUrl => 'https://api.poultryos.in/api/health/info';

  static String get otpHealthUrl =>
      'http://otp.poultryos.in/api/v1/get_language';
}
