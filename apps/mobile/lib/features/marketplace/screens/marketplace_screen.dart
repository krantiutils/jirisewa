import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/listings_map.dart';

const _demoListings = <ProduceListingMarker>[
  ProduceListingMarker(
    id: 'prod-1',
    name: 'Tomatoes',
    pricePerKg: 120,
    farmerName: 'Sita Fresh Farm',
    location: LatLng(27.6306, 86.2305),
  ),
  ProduceListingMarker(
    id: 'prod-2',
    name: 'Potatoes',
    pricePerKg: 65,
    farmerName: 'Dolakha Organics',
    location: LatLng(27.6450, 86.1800),
  ),
  ProduceListingMarker(
    id: 'prod-3',
    name: 'Spinach',
    pricePerKg: 90,
    farmerName: 'Khadya Krishi',
    location: LatLng(27.6140, 86.2600),
  ),
];

class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Marketplace',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Coming soon: full marketplace feed. Preview nearby listings on the map.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 220,
                  child: ListingsMapWidget(
                    listings: _demoListings,
                    center: jiriCenter,
                    zoom: 11,
                    onMarkerTap: (listingId) {
                      final listing = _demoListings.firstWhere(
                        (item) => item.id == listingId,
                        orElse: () => _demoListings.first,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${listing.name} by ${listing.farmerName} · NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _demoListings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final listing = _demoListings[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: AppColors.muted,
                    child: ListTile(
                      leading: const Icon(
                        Icons.eco_outlined,
                        color: AppColors.secondary,
                      ),
                      title: Text(listing.name),
                      subtitle: Text(listing.farmerName),
                      trailing: Text(
                        'NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
