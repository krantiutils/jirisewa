import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/constants/map_constants.dart';
import 'package:jirisewa_mobile/core/services/session_service.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/listings_map.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  bool _loading = true;
  String? _error;
  String _role = 'consumer';
  String? _userId;

  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _pendingPickups = [];
  Map<String, Map<String, dynamic>> _ordersById = {};

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFlowData();
  }

  Future<void> _loadFlowData() async {
    final session = _maybeSession();

    setState(() {
      _loading = true;
      _error = null;
      _role = session?.activeRole ?? 'consumer';
      _userId = session?.profile?.id;
    });

    try {
      if (_role == 'farmer' && _userId != null) {
        final myListings = await _supabase
            .from('produce_listings')
            .select(
              'id, farmer_id, name_en, name_ne, price_per_kg, available_qty_kg, is_active, municipality, created_at',
            )
            .eq('farmer_id', _userId!)
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(20);

        final pending = await _supabase
            .from('order_items')
            .select(
              'id, order_id, listing_id, quantity_kg, subtotal, pickup_confirmed',
            )
            .eq('farmer_id', _userId!)
            .eq('pickup_confirmed', false)
            .order('id')
            .limit(20);

        final pendingPickups = List<Map<String, dynamic>>.from(pending);
        final orderIds = pendingPickups
            .map((item) => item['order_id'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        Map<String, Map<String, dynamic>> ordersById = {};
        if (orderIds.isNotEmpty) {
          final orders = await _supabase
              .from('orders')
              .select('id, status, delivery_address, rider_id, rider_trip_id')
              .inFilter('id', orderIds);

          for (final row in List<Map<String, dynamic>>.from(orders)) {
            final id = row['id'] as String?;
            if (id != null) ordersById[id] = row;
          }
        }

        setState(() {
          _listings = List<Map<String, dynamic>>.from(myListings);
          _pendingPickups = pendingPickups;
          _ordersById = ordersById;
          _loading = false;
        });
        return;
      }

      final listings = await _supabase
          .from('produce_listings')
          .select(
            'id, farmer_id, name_en, name_ne, price_per_kg, available_qty_kg, is_active, municipality, created_at',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(30);

      setState(() {
        _listings = List<Map<String, dynamic>>.from(listings);
        _pendingPickups = [];
        _ordersById = {};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load marketplace flow: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _listings.asMap().entries.map((entry) {
      final index = entry.key;
      final listing = entry.value;
      return ProduceListingMarker(
        id: listing['id'] as String? ?? 'listing-$index',
        name: listing['name_en'] as String? ?? 'Produce',
        pricePerKg: (listing['price_per_kg'] as num?)?.toDouble() ?? 0,
        farmerName: _role == 'farmer' ? 'Your farm' : 'Local farmer',
        location: _listingLocation(listing, index),
      );
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                _role == 'farmer' ? 'Farmer Supply Flow' : 'Marketplace Flow',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _flowStrip(),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 220,
                  child: ListingsMapWidget(
                    listings: markers,
                    center: jiriCenter,
                    zoom: 10.8,
                    onMarkerTap: (listingId) {
                      final listing = _listings.firstWhere(
                        (item) => item['id'] == listingId,
                        orElse: () => _listings.first,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${listing['name_en'] ?? 'Produce'} • NPR ${listing['price_per_kg'] ?? 0}/kg',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadFlowData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _role == 'farmer'
                  ? _farmerFlowList()
                  : _consumerFlowList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowStrip() {
    final steps = _role == 'farmer'
        ? const [
            '1. Post produce',
            '2. Receive requests',
            '3. Hand off to rider',
          ]
        : const [
            '1. Browse produce',
            '2. Send purchase request',
            '3. Rider delivers',
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: steps
            .map(
              (step) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _consumerFlowList() {
    if (_listings.isEmpty) {
      return const Center(child: Text('No active produce listings yet.'));
    }

    return RefreshIndicator(
      onRefresh: _loadFlowData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _listings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final listing = _listings[index];
          return Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: AppColors.muted,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          listing['name_en'] as String? ?? 'Produce',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        'NPR ${(listing['price_per_kg'] as num?)?.toStringAsFixed(0) ?? '0'}/kg',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(listing['available_qty_kg'] as num?)?.toStringAsFixed(0) ?? '0'} kg available',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _showRequestSheet(listing),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Request Purchase'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _farmerFlowList() {
    return RefreshIndicator(
      onRefresh: _loadFlowData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(
            'Your Active Listings (${_listings.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (_listings.isEmpty)
            const Text('No active listings yet.')
          else
            ..._listings.map((listing) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: AppColors.muted,
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(listing['name_en'] as String? ?? 'Produce'),
                  subtitle: Text(
                    '${(listing['available_qty_kg'] as num?)?.toStringAsFixed(0) ?? '0'} kg · NPR ${(listing['price_per_kg'] as num?)?.toStringAsFixed(0) ?? '0'}/kg',
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            'Incoming Pickup Requests (${_pendingPickups.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (_pendingPickups.isEmpty)
            const Text('No pickup requests yet.')
          else
            ..._pendingPickups.map((item) {
              final orderId = item['order_id'] as String?;
              final order = orderId != null ? _ordersById[orderId] : null;
              final status = order?['status'] as String? ?? 'pending';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: AppColors.muted,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(item['quantity_kg'] as num?)?.toStringAsFixed(0) ?? '0'} kg pickup request',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Delivery: ${order?['delivery_address'] ?? 'Address pending'}',
                      ),
                      Text('Order status: ${_formatStatus(status)}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Pickup marked ready. Rider can now connect this order.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.local_shipping_outlined,
                            size: 18,
                          ),
                          label: const Text('Ready For Rider'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showRequestSheet(Map<String, dynamic> listing) async {
    final maxQty = ((listing['available_qty_kg'] as num?)?.toDouble() ?? 1)
        .clamp(1, 200)
        .toDouble();
    var requestQty = maxQty < 5 ? maxQty : 5.0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final total =
                requestQty *
                ((listing['price_per_kg'] as num?)?.toDouble() ?? 0);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request ${listing['name_en'] ?? 'produce'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Quantity: ${requestQty.toStringAsFixed(1)} kg'),
                  Slider(
                    value: requestQty,
                    min: 1,
                    max: maxQty,
                    divisions: maxQty.toInt() > 1 ? maxQty.toInt() - 1 : 1,
                    label: '${requestQty.toStringAsFixed(1)} kg',
                    onChanged: (value) {
                      setLocalState(() => requestQty = value);
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estimated produce cost: NPR ${total.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Purchase request sent. Farmer confirms, then rider matching starts.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Send Request'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  SessionService? _maybeSession() {
    try {
      return SessionProvider.of(context);
    } catch (_) {
      return null;
    }
  }

  LatLng _listingLocation(Map<String, dynamic> listing, int index) {
    final municipality = (listing['municipality'] as String?)?.toLowerCase();
    if (municipality != null) {
      if (municipality.contains('kathmandu')) {
        return const LatLng(27.7172, 85.3240);
      }
      if (municipality.contains('banepa')) {
        return const LatLng(27.6298, 85.5215);
      }
      if (municipality.contains('charikot')) {
        return const LatLng(27.6681, 86.0290);
      }
      if (municipality.contains('jiri')) {
        return const LatLng(27.6306, 86.2305);
      }
    }

    final id = listing['id']?.toString() ?? '$index';
    final hash = id.runes.fold<int>(0, (acc, rune) => acc + rune);
    final latOffset = ((hash % 7) - 3) * 0.01;
    final lngOffset = ((hash % 11) - 5) * 0.01;

    return LatLng(
      jiriCenter.latitude + latOffset,
      jiriCenter.longitude + lngOffset,
    );
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }
}
