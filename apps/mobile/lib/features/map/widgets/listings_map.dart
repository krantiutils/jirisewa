import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/map_constants.dart';

/// A produce listing to display on the map.
class ProduceListingMarker {
  final String id;
  final String name;
  final double pricePerKg;
  final String farmerName;
  final LatLng location;

  const ProduceListingMarker({
    required this.id,
    required this.name,
    required this.pricePerKg,
    required this.farmerName,
    required this.location,
  });
}

/// Map widget showing nearby produce listings as markers.
class ListingsMapWidget extends StatelessWidget {
  final List<ProduceListingMarker> listings;
  final LatLng? center;
  final double? zoom;
  final void Function(String listingId)? onMarkerTap;

  const ListingsMapWidget({
    super.key,
    required this.listings,
    this.center,
    this.zoom,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center ?? mapDefaultCenter,
        initialZoom: zoom ?? mapDefaultZoom,
        minZoom: mapMinZoom,
        maxZoom: mapMaxZoom,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(nepalSouthWest, nepalNorthEast),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrl,
          userAgentPackageName: 'com.jirisewa.mobile',
        ),
        MarkerLayer(
          markers: listings.map((listing) {
            return Marker(
              point: listing.location,
              width: 160,
              height: 60,
              child: GestureDetector(
                onTap: onMarkerTap != null
                    ? () => onMarkerTap!(listing.id)
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        'NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_pin,
                      color: Color(0xFF10B981),
                      size: 28,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(mapAttribution),
          ],
        ),
      ],
    );
  }
}
