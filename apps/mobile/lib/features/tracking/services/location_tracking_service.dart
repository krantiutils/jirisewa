import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interval between location broadcasts when app is in foreground.
const Duration _foregroundInterval = Duration(seconds: 10);

/// Interval between location broadcasts when app is backgrounded.
const Duration _backgroundInterval = Duration(seconds: 30);

/// Service that broadcasts the rider's GPS location to the
/// rider_location_log table via Supabase while a trip is in_transit.
///
/// Usage:
/// ```dart
/// final tracker = LocationTrackingService();
/// await tracker.start(tripId: 'uuid');
/// // ... later
/// tracker.stop();
/// ```
class LocationTrackingService {
  final SupabaseClient _supabase;

  Timer? _timer;
  String? _activeTripId;
  bool _isBackgrounded = false;
  bool _isStarted = false;

  /// Exposed for the UI to show current location.
  Position? lastPosition;

  /// Callback fired after each successful location broadcast.
  void Function(Position position)? onLocationBroadcast;

  /// Callback fired on errors during broadcast.
  void Function(String error)? onError;

  LocationTrackingService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  bool get isTracking => _isStarted;
  String? get activeTripId => _activeTripId;

  /// Start broadcasting location for the given trip.
  ///
  /// Requests location permission if not already granted.
  /// Throws [LocationServiceException] if permission is denied.
  Future<void> start({required String tripId}) async {
    if (_isStarted && _activeTripId == tripId) return;

    // Stop any existing tracking
    stop();

    // Check and request location permission
    await _ensureLocationPermission();

    _activeTripId = tripId;
    _isStarted = true;

    // Broadcast immediately, then set up periodic timer
    await _broadcastLocation();
    _scheduleNextBroadcast();
  }

  /// Stop broadcasting location. Safe to call multiple times.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeTripId = null;
    _isStarted = false;
    lastPosition = null;
  }

  /// Call when app lifecycle changes to optimize battery usage.
  /// Reduces broadcast frequency when backgrounded.
  void setBackgrounded(bool backgrounded) {
    if (_isBackgrounded == backgrounded) return;
    _isBackgrounded = backgrounded;

    // Reschedule with new interval
    if (_isStarted) {
      _timer?.cancel();
      _scheduleNextBroadcast();
    }
  }

  void _scheduleNextBroadcast() {
    final interval =
        _isBackgrounded ? _backgroundInterval : _foregroundInterval;
    // Use one-shot timer to avoid overlapping broadcasts when GPS is slow
    _timer = Timer(interval, () async {
      await _broadcastLocation();
      if (_isStarted) _scheduleNextBroadcast();
    });
  }

  Future<void> _broadcastLocation() async {
    if (!_isStarted || _activeTripId == null) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      onError?.call('Not authenticated');
      stop();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _isBackgrounded
              ? LocationAccuracy.medium
              : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        ),
      );

      lastPosition = position;

      // Insert into rider_location_log
      // Location is stored as PostGIS POINT(lng lat)
      final wkt =
          'POINT(${position.longitude} ${position.latitude})';

      final speedKmh = position.speed >= 0
          ? position.speed * 3.6 // m/s to km/h
          : null;

      await _supabase.from('rider_location_log').insert({
        'rider_id': userId,
        'trip_id': _activeTripId,
        'location': wkt,
        'speed_kmh': speedKmh,
        'recorded_at': position.timestamp.toIso8601String(),
      });

      onLocationBroadcast?.call(position);
    } catch (e) {
      debugPrint('LocationTrackingService broadcast error: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> _ensureLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(
        'Location services are disabled. Please enable GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(
          'Location permission denied. Cannot track ride.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permission permanently denied. Please enable in Settings.',
      );
    }
  }

  /// Dispose resources. Call when the service is no longer needed.
  void dispose() {
    stop();
  }
}

/// Exception thrown when location services are unavailable.
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
