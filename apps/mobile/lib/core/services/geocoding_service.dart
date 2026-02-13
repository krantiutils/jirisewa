import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../constants/map_constants.dart';

/// Result from a geocoding operation
class GeocodingResult {
  final String displayName;
  final LatLng location;

  const GeocodingResult({
    required this.displayName,
    required this.location,
  });
}

/// Result from a routing operation
class RouteResult {
  final List<LatLng> coordinates;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Service for geocoding (Nominatim) and routing (OSRM) operations.
class GeocodingService {
  final http.Client _client;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Reverse geocode coordinates to an address string.
  Future<GeocodingResult?> reverseGeocode(LatLng location) async {
    try {
      final uri = Uri.parse(nominatimBaseUrl).replace(
        path: '/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': location.latitude.toString(),
          'lon': location.longitude.toString(),
        },
      );

      final response = await _client.get(
        uri,
        headers: {'User-Agent': nominatimUserAgent},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        return null;
      }

      return GeocodingResult(
        displayName: (data['display_name'] as String?) ?? '',
        location: LatLng(
          double.parse(data['lat'] as String),
          double.parse(data['lon'] as String),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Forward geocode a query to a list of locations, bounded to Nepal.
  Future<List<GeocodingResult>> forwardGeocode(String query) async {
    try {
      final uri = Uri.parse(nominatimBaseUrl).replace(
        path: '/search',
        queryParameters: {
          'format': 'jsonv2',
          'q': query,
          'countrycodes': 'np',
          'limit': '5',
        },
      );

      final response = await _client.get(
        uri,
        headers: {'User-Agent': nominatimUserAgent},
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as List<dynamic>;

      return data.map((item) {
        final map = item as Map<String, dynamic>;
        return GeocodingResult(
          displayName: (map['display_name'] as String?) ?? '',
          location: LatLng(
            double.parse(map['lat'] as String),
            double.parse(map['lon'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch a driving route between two points via OSRM.
  Future<RouteResult?> fetchRoute(LatLng origin, LatLng destination) async {
    try {
      final coords =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final uri = Uri.parse(
        '$osrmBaseUrl/route/v1/driving/$coords?overview=full&geometries=geojson',
      );

      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['code'] != 'Ok') {
        return null;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final rawCoords = geometry['coordinates'] as List<dynamic>;

      // GeoJSON is [lng, lat], convert to LatLng
      final coordinates = rawCoords.map((coord) {
        final pair = coord as List<dynamic>;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();

      return RouteResult(
        coordinates: coordinates,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
