class ErrorParser {
  static String parse(dynamic error) {
    try {
      if (error is Map) {
        final msg = error['message'];
        if (msg != null) return msg.toString();
      }

      if (error is String) return error;

      return 'Unknown error occurred';
    } catch (_) {
      return 'Unknown error occurred';
    }
  }
}
