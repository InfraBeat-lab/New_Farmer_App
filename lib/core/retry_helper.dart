import 'package:flutter/foundation.dart';

Future<T> withRetry<T>({
  required Future<T> Function() action,
  required T fallback,
  int retries      = 3,
  int delaySeconds = 2,
  required String tag,
}) async {
  for (int attempt = 1; attempt <= retries; attempt++) {
    try {
      debugPrint("⏳ $tag attempt $attempt/$retries");
      return await action();
    } catch (e) {
      debugPrint("❌ $tag attempt $attempt failed: $e");
      if (attempt == retries) {
        debugPrint("❌ $tag — all retries exhausted");
        return fallback;
      }
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }
  return fallback;
}







