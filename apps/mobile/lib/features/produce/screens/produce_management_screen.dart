import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/produce_listing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import 'add_edit_produce_screen.dart';
import 'farmer_orders_screen.dart';

class ProduceManagementScreen extends StatefulWidget {
  const ProduceManagementScreen({super.key});

  @override
  State<ProduceManagementScreen> createState() =>
      _ProduceManagementScreenState();
}

class _ProduceManagementScreenState extends State<ProduceManagementScreen> {
  final _supabase = Supabase.instance.client;

  List<ProduceListing> _listings = [];
  bool _loading = true;
  int _pendingOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('produce_listings')
          .select(
              '*, category:produce_categories(name_en, name_ne)')
          .eq('farmer_id', userId)
          .order('created_at', ascending: false);

      // Count pending orders for farmer's produce
      final pendingData = await _supabase
          .from('order_items')
          .select('id')
          .eq('farmer_id', userId)
          .eq('pickup_confirmed', false);

      if (!mounted) return;

      setState(() {
        _listings = (data as List)
            .map((j) => ProduceListing.fromJson(j as Map<String, dynamic>))
            .toList();
        _pendingOrderCount = (pendingData as List).length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        centerTitle: false,
        actions: [
          if (_pendingOrderCount > 0)
            TextButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FarmerOrdersScreen(),
                ));
                _loadListings();
              },
              icon: Badge.count(
                count: _pendingOrderCount,
                child: const Icon(Icons.notifications_outlined),
              ),
              label: const Text('Orders'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditProduceScreen()),
          );
          _loadListings();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Listing'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadListings,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _listings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No produce listings yet',
                            style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('Tap + to add your first listing',
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _listings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildListingCard(_listings[index]),
                  ),
      ),
    );
  }

  Widget _buildListingCard(ProduceListing listing) {
    final dateFormat = DateFormat('MMM d');

    return Card(
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AddEditProduceScreen(listing: listing),
          ));
          _loadListings();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: listing.photos.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          listing.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.eco,
                              color: AppColors.secondary),
                        ),
                      )
                    : const Icon(Icons.eco, color: AppColors.secondary),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.nameEn,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: listing.isActive
                                ? AppColors.secondary.withAlpha(20)
                                : Colors.grey.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            listing.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: listing.isActive
                                  ? AppColors.secondary
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NPR ${listing.pricePerKg.toStringAsFixed(0)}/kg · ${listing.availableQtyKg.toStringAsFixed(0)} kg',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (listing.freshnessDate != null)
                      Text(
                        'Harvested: ${dateFormat.format(listing.freshnessDate!)}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'toggle') {
                    await _toggleActive(listing);
                  } else if (value == 'delete') {
                    await _deactivate(listing);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(listing.isActive ? 'Deactivate' : 'Activate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(ProduceListing listing) async {
    try {
      await _supabase.from('produce_listings').update({
        'is_active': !listing.isActive,
      }).eq('id', listing.id);
      _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  Future<void> _deactivate(ProduceListing listing) async {
    try {
      await _supabase.from('produce_listings').update({
        'is_active': false,
      }).eq('id', listing.id);
      _loadListings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deactivate: $e')),
      );
    }
  }
}
