import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';
import 'package:jirisewa_mobile/features/earnings/models/earning_item.dart';
import 'package:jirisewa_mobile/features/earnings/providers/earnings_provider.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  int _page = 1;
  final _amountController = TextEditingController();
  String _payoutMethod = 'esewa';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showPayoutSheet() {
    _amountController.clear();
    _payoutMethod = 'esewa';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Request Payout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (NPR)',
                      prefixText: 'NPR ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _payoutMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payout Method',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'esewa', child: Text('eSewa')),
                      DropdownMenuItem(value: 'khalti', child: Text('Khalti')),
                      DropdownMenuItem(
                          value: 'bank', child: Text('Bank Transfer')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => _payoutMethod = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(_amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Enter a valid amount')),
                        );
                        return;
                      }

                      final profile = ref.read(userProfileProvider);
                      if (profile == null) return;

                      final repo = ref.read(earningsRepositoryProvider);
                      try {
                        await repo.requestPayout(
                          userId: profile.id,
                          amount: amount,
                          method: _payoutMethod,
                        );
                        ref.invalidate(earningsSummaryProvider);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Payout request submitted')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Payout failed: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Submit Request'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(earningsSummaryProvider);
    final earningsAsync = ref.watch(earningsListProvider(_page));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Earnings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(earningsSummaryProvider);
          ref.invalidate(earningsListProvider(_page));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary cards
            summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (summary) => _buildSummaryCards(summary),
            ),
            const SizedBox(height: 16),

            // Payout request button
            OutlinedButton.icon(
              onPressed: _showPayoutSheet,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Request Payout'),
            ),
            const SizedBox(height: 24),

            // Earnings history title
            const Text(
              'Earnings History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),

            // Earnings list
            earningsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading earnings: $e'),
              data: (items) => _buildEarningsList(items),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(EarningsSummary summary) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          label: 'Total Earned',
          amount: summary.totalEarned,
          color: AppColors.secondary,
        ),
        _SummaryCard(
          label: 'Pending',
          amount: summary.pendingBalance,
          color: AppColors.accent,
        ),
        _SummaryCard(
          label: 'Settled',
          amount: summary.settledBalance,
          color: AppColors.primary,
        ),
        _SummaryCard(
          label: 'Withdrawn',
          amount: summary.totalWithdrawn,
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildEarningsList(List<EarningItem> items) {
    if (items.isEmpty && _page == 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No earnings yet',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final item in items) _buildEarningTile(item),
        if (items.length >= 20)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: () => setState(() => _page++),
              child: const Text('Load more'),
            ),
          ),
      ],
    );
  }

  Widget _buildEarningTile(EarningItem item) {
    final dateStr = DateFormat('MMM d, y').format(item.createdAt);

    Color badgeColor;
    switch (item.status) {
      case 'settled':
        badgeColor = AppColors.secondary;
        break;
      case 'pending':
        badgeColor = AppColors.accent;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NPR ${item.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Each card takes roughly half width minus spacing.
    final cardWidth = (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2;

    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          border: Border.all(color: color.withAlpha(60)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'NPR ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
