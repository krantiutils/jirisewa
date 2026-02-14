import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/order.dart' as models;
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';

/// Star rating + comment screen shown after delivery is confirmed.
class RatingScreen extends StatefulWidget {
  final String orderId;

  const RatingScreen({super.key, required this.orderId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final _supabase = Supabase.instance.client;
  final _commentController = TextEditingController();

  models.Order? _order;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  // Rating for farmer(s) and rider
  final Map<String, int> _scores = {};
  final Map<String, UserRole> _ratedRoles = {};

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _supabase
          .from('orders')
          .select(
              '*, consumer:users!consumer_id(name), rider:users!rider_id(name), order_items(*, farmer:users!farmer_id(name))')
          .eq('id', widget.orderId)
          .single();

      if (!mounted) return;

      final order = models.Order.fromJson(data);

      // Build list of people to rate
      final auth = context.read<AuthProvider>();
      final userId = auth.userId;

      // Consumer rates rider + farmers
      if (userId == order.consumerId) {
        if (order.riderId != null) {
          _scores[order.riderId!] = 0;
          _ratedRoles[order.riderId!] = UserRole.rider;
        }
        for (final item in order.items) {
          if (!_scores.containsKey(item.farmerId)) {
            _scores[item.farmerId] = 0;
            _ratedRoles[item.farmerId] = UserRole.farmer;
          }
        }
      }
      // Rider rates consumer
      else if (userId == order.riderId) {
        _scores[order.consumerId] = 0;
        _ratedRoles[order.consumerId] = UserRole.consumer;
      }

      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _submitRatings() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    // Validate all scores are set
    if (_scores.values.any((s) => s == 0)) {
      setState(() => _error = 'Please rate all participants');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final ratings = _scores.entries.map((entry) {
        return {
          'order_id': widget.orderId,
          'rater_id': userId,
          'rated_id': entry.key,
          'role_rated': _ratedRoles[entry.key]!.name,
          'score': entry.value,
          'comment': _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        };
      }).toList();

      await _supabase.from('ratings').insert(ratings);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ratings submitted. Thank you!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Failed to submit ratings. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Delivery')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'How was your experience?',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rate the people involved in this delivery.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),

                      // Rating widgets for each person
                      ..._scores.entries.map((entry) {
                        final role = _ratedRoles[entry.key]!;
                        String name = '';
                        if (role == UserRole.rider) {
                          name = _order!.riderName ?? 'Rider';
                        } else if (role == UserRole.consumer) {
                          name = _order!.consumerName ?? 'Consumer';
                        } else {
                          final item = _order!.items.firstWhere(
                            (i) => i.farmerId == entry.key,
                            orElse: () => _order!.items.first,
                          );
                          name = item.farmerName ?? 'Farmer';
                        }

                        return _buildRatingRow(
                          name: name,
                          role: role,
                          userId: entry.key,
                          score: entry.value,
                        );
                      }),

                      const SizedBox(height: 24),

                      // Comment
                      Text('Comment (optional)',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Share your experience...',
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 14)),
                      ],

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _submitting ? null : _submitRatings,
                        child: Text(
                            _submitting ? 'Submitting...' : 'Submit Ratings'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRatingRow({
    required String name,
    required UserRole role,
    required String userId,
    required int score,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    role == UserRole.rider
                        ? Icons.directions_bike
                        : role == UserRole.farmer
                            ? Icons.agriculture
                            : Icons.person,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(role.label,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _scores[userId] = starValue);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starValue <= score
                            ? Icons.star
                            : Icons.star_border,
                        size: 36,
                        color: AppColors.accent,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
