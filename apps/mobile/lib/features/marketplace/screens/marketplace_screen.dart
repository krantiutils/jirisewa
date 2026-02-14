import 'package:flutter/material.dart';

import 'package:jirisewa_mobile/core/theme.dart';

/// Placeholder marketplace screen — browse produce listings.
/// Full implementation will be in ts-72g8.
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.storefront, color: AppColors.secondary, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  'Marketplace',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse fresh produce from local farmers.\nComing soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
