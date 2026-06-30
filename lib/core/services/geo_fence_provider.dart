// lib/core/services/geo_fence_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:poultryos_farmer_app/core/services/geo_fence_service.dart';
import 'package:poultryos_farmer_app/core/services/local_storage_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// State
// ──────────────────────────────────────────────────────────────────────────────

class GeoFenceState {
  final GeoFenceResult result;
  final bool isLoading;

  const GeoFenceState({required this.result, this.isLoading = false});

  GeoFenceState copyWith({GeoFenceResult? result, bool? isLoading}) {
    return GeoFenceState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────────────────────────────────────────

class GeoFenceNotifier extends Notifier<GeoFenceState> {
  StreamSubscription<Position>? _positionSub;

  // Only re-validate if user moves more than this many metres
  static const double _movementThresholdMeters = 15.0;
  double? _lastLat;
  double? _lastLong;

  @override
  GeoFenceState build() {
    // Initial "unknown" state
    final initial = GeoFenceResult(
      status: GeoFenceStatus.unknown,
      message: 'Location not verified. Please enable location services.',
    );

    // Start check as soon as the notifier is created
    _performCheck();

    // Start real-time position listener
    _startLocationStream();

    // Cleanup when provider is disposed
    ref.onDispose(() {
      _positionSub?.cancel();
    });

    return GeoFenceState(result: initial, isLoading: true);
  }

    GeoFenceState build2() {
    ref.onDispose(() {
      _positionSub?.cancel();
    });

    return GeoFenceState(
      result: GeoFenceResult(
        status: GeoFenceStatus.inside, // ← TEMP: bypass
        message: 'Access granted.',
      ),
      isLoading: false,
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Manually trigger a geo-fence re-validation.
  Future<void> reCheck() async {
    state = state.copyWith(isLoading: true);
    await _performCheck();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _performCheck() async {
    try {
      final sessionId =
          LocalStorageService.getString('AuthToken') ??
          LocalStorageService.getString('session_id');

      final result = await GeoFenceService.check(sessionId: sessionId);

      // Update last known coords for movement detection
      if (result.lat != null) _lastLat = result.lat;
      if (result.long != null) _lastLong = result.long;

      debugPrint(
        '[GeoFenceNotifier] Status: ${result.status}  |  '
        'Message: ${result.message}',
      );

      state = GeoFenceState(result: result, isLoading: false);
    } catch (e) {
      debugPrint('[GeoFenceNotifier] _performCheck error: $e');
      state = GeoFenceState(
        result: GeoFenceResult(
          status: GeoFenceStatus.apiError,
          message: 'Unable to verify location restrictions. Please try again.',
        ),
        isLoading: false,
      );
    }
  }

  void _startLocationStream() {
    _positionSub?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // receive update every ≥10 m
    );

    _positionSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            // Only re-validate when user has moved significantly
            final moved = _hasMoved(position.latitude, position.longitude);
            if (moved) {
              debugPrint(
                '[GeoFenceNotifier] Significant movement detected – re-validating',
              );
              _performCheck();
            }
          },
          onError: (e) {
            debugPrint('[GeoFenceNotifier] Location stream error: $e');
          },
        );
  }

  bool _hasMoved(double lat, double long) {
    if (_lastLat == null || _lastLong == null) return true;

    final distance = GeoFenceService.publicHaversine(
      lat1: _lastLat!,
      lon1: _lastLong!,
      lat2: lat,
      lon2: long,
    );

    return distance >= _movementThresholdMeters;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────────────────────────────────────

final geoFenceProvider = NotifierProvider<GeoFenceNotifier, GeoFenceState>(
  GeoFenceNotifier.new,
);
