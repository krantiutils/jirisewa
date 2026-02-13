import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/services/geocoding_service.dart';

/// A map widget that lets users pick a location by tapping.
/// Reverse geocodes the tapped point to an address string.
class LocationPickerWidget extends StatefulWidget {
  /// Initial location to show. If null, uses device GPS or Jiri default.
  final LatLng? initialLocation;

  /// Called when user taps a location on the map.
  final void Function(LatLng location, String address) onLocationSelected;

  const LocationPickerWidget({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  final MapController _mapController = MapController();
  final GeocodingService _geocodingService = GeocodingService();

  LatLng? _selectedLocation;
  String _address = '';
  bool _isGeocoding = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _geocodingService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _onTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _isGeocoding = true;
      _address = '';
    });

    final result = await _geocodingService.reverseGeocode(point);

    if (!mounted) return;

    final resolvedAddress = result?.displayName ?? '';

    setState(() {
      _address = resolvedAddress;
      _isGeocoding = false;
    });

    widget.onLocationSelected(point, resolvedAddress);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!mounted) return;
          setState(() => _isLocating = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);

      _mapController.move(latLng, 15.0);

      setState(() {
        _selectedLocation = latLng;
        _isLocating = false;
      });

      // Trigger reverse geocode
      await _onTap(TapPosition(Offset.zero, Offset.zero), latLng);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLocation ?? widget.initialLocation ?? mapDefaultCenter;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: mapDefaultZoom,
                  minZoom: mapMinZoom,
                  maxZoom: mapMaxZoom,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(nepalSouthWest, nepalNorthEast),
                  ),
                  onTap: _onTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrl,
                    userAgentPackageName: 'com.jirisewa.mobile',
                  ),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFF3B82F6),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(mapAttribution),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _isLocating ? null : _goToCurrentLocation,
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        if (_address.isNotEmpty || _isGeocoding)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF3F4F6),
            child: Text(
              _isGeocoding ? 'Resolving address...' : _address,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
