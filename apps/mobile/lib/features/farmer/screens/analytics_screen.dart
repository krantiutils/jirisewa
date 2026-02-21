import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/farmer/providers/analytics_provider.dart';
import 'package:jirisewa_mobile/features/ratings/widgets/star_rating.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(farmerAnalyticsProvider(_selectedDays));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final days in [7, 30, 90])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${days}d'),
                      selected: _selectedDays == days,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedDays = days);
                        }
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _selectedDays == days
                            ? Colors.white
                            : AppColors.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: analyticsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Failed to load analytics: $e')),
              data: (data) {
                if (data.isEmpty) {
                  return const Center(child: Text('No analytics data'));
                }
                return _buildAnalyticsContent(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(Map<String, dynamic> data) {
    final revenueTrend = data['revenueTrend'] as List? ?? [];
    final salesByCategory = data['salesByCategory'] as List? ?? [];
    final topProducts = data['topProducts'] as List? ?? [];
    final priceBenchmarks = data['priceBenchmarks'] as List? ?? [];
    final fulfillment =
        data['fulfillment'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final ratingDistribution = data['ratingDistribution'] as List? ?? [];
    final ratingAvg = (data['ratingAvg'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRevenueTrendCard(revenueTrend),
        const SizedBox(height: 16),
        _buildSalesByCategoryCard(salesByCategory),
        const SizedBox(height: 16),
        _buildTopProductsCard(topProducts),
        const SizedBox(height: 16),
        _buildPriceBenchmarksCard(priceBenchmarks),
        const SizedBox(height: 16),
        _buildFulfillmentCard(fulfillment),
        const SizedBox(height: 16),
        _buildRatingSummaryCard(ratingAvg, ratingCount, ratingDistribution),
        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Revenue Trend
  // ---------------------------------------------------------------------------
  Widget _buildRevenueTrendCard(List<dynamic> revenueTrend) {
    return _AnalyticsCard(
      title: 'Revenue Trend',
      child: revenueTrend.isEmpty
          ? const _EmptySection(message: 'No revenue data yet')
          : SizedBox(
              height: 200,
              child: _RevenueTrendChart(data: revenueTrend),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sales by Category
  // ---------------------------------------------------------------------------
  Widget _buildSalesByCategoryCard(List<dynamic> salesByCategory) {
    if (salesByCategory.isEmpty) {
      return const _AnalyticsCard(
        title: 'Sales by Category',
        child: _EmptySection(message: 'No sales data yet'),
      );
    }

    final maxRevenue = salesByCategory.fold<double>(
      0,
      (max, item) {
        final rev = ((item as Map<String, dynamic>)['total_revenue'] as num?)
                ?.toDouble() ??
            0;
        return rev > max ? rev : max;
      },
    );

    return _AnalyticsCard(
      title: 'Sales by Category',
      child: Column(
        children: [
          for (final item in salesByCategory)
            _buildCategoryRow(item as Map<String, dynamic>, maxRevenue),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(Map<String, dynamic> item, double maxRevenue) {
    final name = item['category_name'] as String? ?? 'Unknown';
    final revenue = (item['total_revenue'] as num?)?.toDouble() ?? 0;
    final orderCount = (item['order_count'] as num?)?.toInt() ?? 0;
    final fraction = maxRevenue > 0 ? revenue / maxRevenue : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Rs ${revenue.toStringAsFixed(0)} ($orderCount orders)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.muted,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Products
  // ---------------------------------------------------------------------------
  Widget _buildTopProductsCard(List<dynamic> topProducts) {
    if (topProducts.isEmpty) {
      return const _AnalyticsCard(
        title: 'Top Products',
        child: _EmptySection(message: 'No product data yet'),
      );
    }

    final displayProducts = topProducts.take(5).toList();

    return _AnalyticsCard(
      title: 'Top Products',
      child: Column(
        children: [
          for (var i = 0; i < displayProducts.length; i++)
            _buildProductRow(
                displayProducts[i] as Map<String, dynamic>, i + 1),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item, int rank) {
    final name = item['name_en'] as String? ?? 'Unknown';
    final totalQty = (item['total_qty_kg'] as num?)?.toDouble() ?? 0;
    final totalRevenue = (item['total_revenue'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${totalQty.toStringAsFixed(1)} kg sold',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${totalRevenue.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Price Benchmarks
  // ---------------------------------------------------------------------------
  Widget _buildPriceBenchmarksCard(List<dynamic> priceBenchmarks) {
    if (priceBenchmarks.isEmpty) {
      return const _AnalyticsCard(
        title: 'Price Benchmarks',
        child: _EmptySection(message: 'No benchmark data yet'),
      );
    }

    return _AnalyticsCard(
      title: 'Price Benchmarks',
      child: Column(
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('My Price',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 16),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Market Avg',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          for (final item in priceBenchmarks)
            _buildBenchmarkRow(item as Map<String, dynamic>),
        ],
      ),
    );
  }

  Widget _buildBenchmarkRow(Map<String, dynamic> item) {
    final name = item['category_name'] as String? ?? 'Unknown';
    final myAvg = (item['my_avg_price'] as num?)?.toDouble() ?? 0;
    final marketAvg = (item['market_avg_price'] as num?)?.toDouble() ?? 0;
    final maxPrice = math.max(myAvg, marketAvg);
    final myFraction = maxPrice > 0 ? myAvg / maxPrice : 0.0;
    final marketFraction = maxPrice > 0 ? marketAvg / maxPrice : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  'Rs ${myAvg.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.primary),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: myFraction,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  'Rs ${marketAvg.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: marketFraction,
                    minHeight: 6,
                    backgroundColor: AppColors.muted,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fulfillment Rate
  // ---------------------------------------------------------------------------
  Widget _buildFulfillmentCard(Map<String, dynamic> fulfillment) {
    final fulfillmentPct =
        (fulfillment['fulfillment_pct'] as num?)?.toDouble() ?? 0;
    final totalOrders = (fulfillment['total_orders'] as num?)?.toInt() ?? 0;
    final delivered = (fulfillment['delivered'] as num?)?.toInt() ?? 0;
    final cancelled = (fulfillment['cancelled'] as num?)?.toInt() ?? 0;

    return _AnalyticsCard(
      title: 'Fulfillment Rate',
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: fulfillmentPct / 100,
                    strokeWidth: 10,
                    backgroundColor: AppColors.muted,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fulfillmentPct >= 80
                          ? AppColors.secondary
                          : fulfillmentPct >= 50
                              ? AppColors.accent
                              : AppColors.error,
                    ),
                  ),
                ),
                Text(
                  '${fulfillmentPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Total', totalOrders.toString()),
              _buildStatItem('Delivered', delivered.toString()),
              _buildStatItem('Cancelled', cancelled.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Rating Summary
  // ---------------------------------------------------------------------------
  Widget _buildRatingSummaryCard(
    double ratingAvg,
    int ratingCount,
    List<dynamic> ratingDistribution,
  ) {
    return _AnalyticsCard(
      title: 'Rating Summary',
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ratingAvg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                  ),
                  StarRating(rating: ratingAvg.round()),
                  const SizedBox(height: 4),
                  Text(
                    '$ratingCount ratings',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildRatingDistribution(
                    ratingDistribution, ratingCount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution(
      List<dynamic> distribution, int totalCount) {
    // Build a map of star -> count
    final starCounts = <int, int>{};
    for (final item in distribution) {
      final map = item as Map<String, dynamic>;
      final stars = (map['stars'] as num?)?.toInt() ?? 0;
      final count = (map['count'] as num?)?.toInt() ?? 0;
      starCounts[stars] = count;
    }

    return Column(
      children: [
        for (int star = 5; star >= 1; star--)
          _buildRatingBar(star, starCounts[star] ?? 0, totalCount),
      ],
    );
  }

  Widget _buildRatingBar(int star, int count, int total) {
    final fraction = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$star',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.muted,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Revenue Trend Chart
// =============================================================================

class _RevenueTrendChart extends StatelessWidget {
  final List<dynamic> data;

  const _RevenueTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final spots = <FlSpot>[];
    double maxY = 0;

    for (var i = 0; i < data.length; i++) {
      final item = data[i] as Map<String, dynamic>;
      final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), revenue));
      if (revenue > maxY) maxY = revenue;
    }

    // Add some padding to maxY
    maxY = maxY * 1.1;
    if (maxY == 0) maxY = 100;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 0.5,
          ),
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: maxY / 4,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatNumber(value),
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: math.max(1, (data.length / 5).ceilToDouble()),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                final item = data[index] as Map<String, dynamic>;
                final day = item['day'] as String? ?? '';
                // Show only month-day
                final parts = day.split('-');
                final label =
                    parts.length >= 3 ? '${parts[1]}/${parts[2]}' : day;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withAlpha(30),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Rs ${spot.y.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _AnalyticsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
      ),
    );
  }
}
