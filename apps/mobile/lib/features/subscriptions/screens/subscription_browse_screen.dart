import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/subscriptions/models/subscription_plan.dart';
import 'package:jirisewa_mobile/features/subscriptions/providers/subscription_provider.dart';

/// Consumer screen for browsing subscription plans and managing existing
/// subscriptions.
class SubscriptionBrowseScreen extends ConsumerWidget {
  const SubscriptionBrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Subscriptions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Browse Plans'),
                Tab(text: 'My Subscriptions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BrowsePlansTab(),
                  _MySubscriptionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Browse Plans Tab
// ---------------------------------------------------------------------------

class _BrowsePlansTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(activeSubscriptionPlansProvider);

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load plans: $error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(activeSubscriptionPlansProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (plans) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeSubscriptionPlansProvider);
          await ref.read(activeSubscriptionPlansProvider.future);
        },
        child: plans.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.subscriptions_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No subscription plans available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: plans.length,
                itemBuilder: (context, index) =>
                    _PlanCard(plan: plans[index]),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan Card
// ---------------------------------------------------------------------------

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsLeft = plan.maxSubscribers - plan.subscriberCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name and price
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.nameEn,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rs ${plan.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),

            if (plan.descriptionEn != null &&
                plan.descriptionEn!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                plan.descriptionEn!,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Farmer info
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withAlpha(25),
                  backgroundImage: plan.farmer.avatarUrl != null
                      ? NetworkImage(plan.farmer.avatarUrl!)
                      : null,
                  child: plan.farmer.avatarUrl == null
                      ? Text(
                          plan.farmer.name.isNotEmpty
                              ? plan.farmer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.farmer.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (plan.farmer.ratingCount > 0) ...[
                  const Icon(Icons.star, size: 14, color: AppColors.accent),
                  const SizedBox(width: 2),
                  Text(
                    plan.farmer.ratingAvg.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Frequency, delivery day, spots
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.repeat,
                  label: _frequencyLabel(plan.frequency),
                ),
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: plan.deliveryDayLabel,
                ),
                _InfoChip(
                  icon: Icons.people_outline,
                  label: spotsLeft > 0 ? '$spotsLeft spots left' : 'Full',
                ),
              ],
            ),

            // Items preview
            if (plan.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Includes:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              ...plan.items.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '  ${item.categoryEn} (~${item.approxKg.toStringAsFixed(1)} kg)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ),
              if (plan.items.length > 3)
                Text(
                  '  +${plan.items.length - 3} more',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],

            const SizedBox(height: 16),

            // Subscribe button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: spotsLeft > 0
                    ? () => _showSubscribeDialog(context, ref)
                    : null,
                child: Text(spotsLeft > 0 ? 'Subscribe' : 'Plan Full'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscribeDialog(BuildContext context, WidgetRef ref) {
    String selectedMethod = 'cash';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Choose Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PaymentOptionTile(
                label: 'Cash on Delivery',
                icon: Icons.money,
                selected: selectedMethod == 'cash',
                onTap: () => setDialogState(() => selectedMethod = 'cash'),
              ),
              _PaymentOptionTile(
                label: 'eSewa',
                icon: Icons.account_balance_wallet,
                selected: selectedMethod == 'esewa',
                onTap: () => setDialogState(() => selectedMethod = 'esewa'),
              ),
              _PaymentOptionTile(
                label: 'Khalti',
                icon: Icons.payment,
                selected: selectedMethod == 'khalti',
                onTap: () => setDialogState(() => selectedMethod = 'khalti'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _subscribe(context, ref, selectedMethod);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _subscribe(
    BuildContext context,
    WidgetRef ref,
    String paymentMethod,
  ) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.subscribeToPlan(profile.id, plan.id, paymentMethod);

      ref.invalidate(mySubscriptionsProvider);
      ref.invalidate(activeSubscriptionPlansProvider);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Subscribed successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to subscribe: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Biweekly';
      case 'monthly':
        return 'Monthly';
      default:
        return frequency;
    }
  }
}

// ---------------------------------------------------------------------------
// My Subscriptions Tab
// ---------------------------------------------------------------------------

class _MySubscriptionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(mySubscriptionsProvider);

    return subsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load subscriptions: $error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(mySubscriptionsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (subs) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySubscriptionsProvider);
          await ref.read(mySubscriptionsProvider.future);
        },
        child: subs.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No subscriptions yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Browse plans and subscribe to get started',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: subs.length,
                itemBuilder: (context, index) =>
                    _SubscriptionCard(subscription: subs[index]),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription Card (consumer's existing subscription)
// ---------------------------------------------------------------------------

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.subscription});
  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = subscription.status == 'cancelled';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan name and status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    subscription.plan.nameEn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusBadge(status: subscription.status),
              ],
            ),

            const SizedBox(height: 8),

            // Farmer name
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  subscription.plan.farmer.name,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Price + frequency
            Row(
              children: [
                Text(
                  'Rs ${subscription.plan.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  ' / ${subscription.plan.frequency}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Next delivery
            if (!isCancelled)
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Next delivery: ${subscription.nextDeliveryDate}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),

            // Payment method
            Row(
              children: [
                const Icon(Icons.payment, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _paymentMethodLabel(subscription.paymentMethod),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),

            // Action buttons
            if (!isCancelled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (subscription.status == 'active')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pause(context, ref),
                        icon: const Icon(Icons.pause, size: 16),
                        label: const Text('Pause'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  if (subscription.status == 'paused')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _resume(context, ref),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmCancel(context, ref),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(0, 40),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pause(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.pauseSubscription(subscription.id, profile.id);
      ref.invalidate(mySubscriptionsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Subscription paused'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to pause: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.resumeSubscription(subscription.id, profile.id);
      ref.invalidate(mySubscriptionsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Subscription resumed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to resume: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text(
          'Are you sure you want to cancel this subscription? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('No, keep it'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cancel(context, ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider);
    if (profile == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.cancelSubscription(subscription.id, profile.id);
      ref.invalidate(mySubscriptionsProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Subscription cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static String _paymentMethodLabel(String method) {
    switch (method) {
      case 'esewa':
        return 'eSewa';
      case 'khalti':
        return 'Khalti';
      case 'cash':
        return 'Cash on Delivery';
      default:
        return method;
    }
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppColors.secondary.withAlpha(25);
        textColor = AppColors.secondary;
        label = 'Active';
      case 'paused':
        bgColor = AppColors.accent.withAlpha(25);
        textColor = AppColors.accent;
        label = 'Paused';
      case 'cancelled':
        bgColor = AppColors.error.withAlpha(25);
        textColor = AppColors.error;
        label = 'Cancelled';
      default:
        bgColor = Colors.grey.withAlpha(25);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
