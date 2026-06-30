// lib/core/services/geo_fence_service.dart

import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:poultryos_farmer_app/core/utils/dio_config.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Data Models
// ──────────────────────────────────────────────────────────────────────────────

enum GeoFenceStatus {
  unknown, // Location not yet verified / services disabled
  inside, // User is inside the allowed zone
  outside, // User is outside the allowed zone
  permissionDenied, // Location permission denied
  gpsUnavailable, // GPS / location services disabled
  apiError, // Could not load geo-fence config from server
}

class GeoFenceConfig {
  final double lat;
  final double long;
  final double radius; // metres

  const GeoFenceConfig({
    required this.lat,
    required this.long,
    required this.radius,
  });

  factory GeoFenceConfig.fromJson(Map<String, dynamic> json) {
    double parseToDouble(dynamic value) {
      if (value is num) return value.toDouble();

      if (value is String) {
        // Try normal parsing first
        final normal = double.tryParse(value);
        if (normal != null) return normal;

        // Try DMS parsing
        return dmsToDecimal(value);
      }

      throw Exception("Invalid type for double: $value");
    }

    return GeoFenceConfig(
      lat: parseToDouble(json['lat']),
      long: parseToDouble(json['long']),
      radius: parseToDouble(json['radius']),
    );
  }
}

double dmsToDecimal(String dms) {
  final regex = RegExp(r"""(\d+)°(\d+)'([\d.]+)""");
  final match = regex.firstMatch(dms);

  if (match == null) {
    throw FormatException("Invalid DMS format: $dms");
  }

  final degrees = double.parse(match.group(1)!);
  final minutes = double.parse(match.group(2)!);
  final seconds = double.parse(match.group(3)!);

  return degrees + (minutes / 60) + (seconds / 3600);
}

class GeoFenceResult {
  final GeoFenceStatus status;
  final double? distanceMeters;
  final double? lat;
  final double? long;
  final String message;
  final DateTime timestamp;

  GeoFenceResult({
    required this.status,
    this.distanceMeters,
    this.lat,
    this.long,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isInsideZone => status == GeoFenceStatus.inside;
  bool get accessGranted => status == GeoFenceStatus.inside;
}

// ──────────────────────────────────────────────────────────────────────────────
// Service
// ──────────────────────────────────────────────────────────────────────────────

class GeoFenceService {
  static const String _geoFenceEndpoint =
      'https://175.100.181.203:50000/b1s/v2/'
      "SQLQueries('Breeder_Setting_GetGeoFencingDetails')/List";

  /// SAP session cookies are needed to reach the protected endpoint.
  /// Pass the current B1SESSION cookie value here.
  static Future<GeoFenceConfig?> fetchGeoFenceConfig({
    required String? sessionId,
  }) async {
    try {
      final dio = _buildDio();

      if (sessionId != null && sessionId.isNotEmpty) {
        dio.options.headers['Cookie'] = 'B1SESSION=$sessionId';
      }

      final response = await dio.get(_geoFenceEndpoint);

      if (response.statusCode == 200) {
        final data = response.data;

        // The SAP OData response may wrap the result in a 'value' array
        // or return the object directly.
        if (data is Map<String, dynamic> && data.containsKey('value')) {
          final List value = data['value'] as List;
          if (value.isNotEmpty) {
            return GeoFenceConfig.fromJson(value.first as Map<String, dynamic>);
          }
        } else if (data is Map<String, dynamic>) {
          return GeoFenceConfig.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[GeoFenceService] fetchGeoFenceConfig error: $e');
    }
    return null;
  }

  /// Request/check location permission, then fetch the current position.
  static Future<({Position? position, GeoFenceStatus status})>
      getCurrentPosition() async {
    // ── 1. Check if location services are enabled ──────────────────────────
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[GeoFenceService] Location services disabled');
      return (position: null, status: GeoFenceStatus.gpsUnavailable);
    }

    // ── 2. Check / request permission ────────────────────────────────────
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[GeoFenceService] Location permission denied');
      return (position: null, status: GeoFenceStatus.permissionDenied);
    }

    // ── 3. Fetch position ─────────────────────────────────────────────────
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      debugPrint(
        '[GeoFenceService] Position: ${position.latitude}, ${position.longitude}',
      );
      return (position: position, status: GeoFenceStatus.unknown);
    } catch (e) {
      debugPrint('[GeoFenceService] getCurrentPosition error: $e');
      return (position: null, status: GeoFenceStatus.gpsUnavailable);
    }
  }

  /// Full geo-fence check: fetches config + current position, returns result.
  static Future<GeoFenceResult> check({required String? sessionId}) async {
    // ── Fetch geo-fence config ────────────────────────────────────────────
    final config = await fetchGeoFenceConfig(sessionId: sessionId);

    if (config == null) {
      return GeoFenceResult(
        status: GeoFenceStatus.apiError,
        message: 'Unable to verify location restrictions. Please try again.',
      );
    }

    // ── Get current position ──────────────────────────────────────────────
    final (:position, :status) = await getCurrentPosition();

    if (position == null) {
      final msg = status == GeoFenceStatus.permissionDenied
          ? 'Location permission is required to access this module.'
          : 'GPS unavailable. Please enable location services and try again.';
      return GeoFenceResult(status: status, message: msg);
    }

    // ── Haversine distance ────────────────────────────────────────────────
    final distance = _haversineDistance(
      lat1: position.latitude,
      lon1: position.longitude,
      lat2: config.lat,
      lon2: config.long,
    );

    debugPrint(
      '[GeoFenceService] Distance: ${distance.toStringAsFixed(1)} m  |  '
      'Radius: ${config.radius} m',
    );

    final isInside = distance <= config.radius;

    return GeoFenceResult(
      status: isInside ? GeoFenceStatus.inside : GeoFenceStatus.outside,
      distanceMeters: distance,
      lat: position.latitude,
      long: position.longitude,
      message: isInside
          ? 'You are within the permitted area. Access granted.'
          : 'Access restricted. You are outside the permitted area.',
    );
  }

  // ── Haversine Formula ─────────────────────────────────────────────────────

  /// Public wrapper so other classes (e.g. the provider) can reuse the formula.
  static double publicHaversine({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      _haversineDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2);

  /// Returns the great-circle distance (in metres) between two lat/lon points.
  static double _haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371000; // metres
    final double dLat = _toRad(lat2 - lat1);
    final double dLon = _toRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  // ── Build Dio with SSL bypass (same pattern as ApiClient) ─────────────────

  static Dio _buildDio() {
    final dio = Dio();
    DioConfig.applyRobustSettings(dio);
    // Overwrite timeouts for GeoFence specifically if needed
    dio.options.connectTimeout = const Duration(seconds: 20);
    dio.options.receiveTimeout = const Duration(seconds: 20);
    return dio;
  }
}
