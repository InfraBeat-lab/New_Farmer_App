import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _boxName = 'app_preferences';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  /// Saves a string value.
  static Future<void> setString(String key, String value) async {
    await _box.put(key, value);
  }

  /// Retrieves a string value.
  static String? getString(String key) {
    final val = _box.get(key);
    if (val == null) return null;
    return val.toString();
  }

  /// Saves a boolean value.
  static Future<void> setBool(String key, bool value) async {
    await _box.put(key, value);
  }

  /// Retrieves a boolean value.
  static bool? getBool(String key) {
    final val = _box.get(key);
    if (val == null) return null;
    if (val is bool) return val;
    if (val is String) {
      return val.toLowerCase() == 'true' || val == '1';
    }
    if (val is int) {
      return val == 1;
    }
    return null;
  }

  /// Saves an integer value.
  static Future<void> setInt(String key, int value) async {
    await _box.put(key, value);
  }

  /// Retrieves an integer value.
  static int? getInt(String key) {
    final val = _box.get(key);
    if (val == null) return null;
    if (val is int) return val;
    if (val is String) return int.tryParse(val);
    return null;
  }

  /// Removes a value by key.
  static Future<void> remove(String key) async {
    await _box.delete(key);
  }

  /// Clears all stored values.
  static Future<void> clear() async {
    await _box.clear();
  }

  /// Checks if a key exists.
  static bool containsKey(String key) {
    return _box.containsKey(key);
  }
}
