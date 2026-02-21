import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:jirisewa_mobile/core/routing/app_router.dart';
import 'package:jirisewa_mobile/core/theme.dart';
import 'package:jirisewa_mobile/features/map/widgets/location_picker.dart';
import 'package:jirisewa_mobile/features/map/widgets/municipality_picker.dart';
import 'package:jirisewa_mobile/features/map/widgets/route_map.dart';
import 'package:jirisewa_mobile/features/trips/providers/trip_creation_provider.dart';

// ---------------------------------------------------------------------------
// Step labels
// ---------------------------------------------------------------------------
const _stepLabels = ['Origin', 'Destination', 'Details', 'Review'];

// ---------------------------------------------------------------------------
// TripCreationScreen
// ---------------------------------------------------------------------------

/// 4-step trip creation flow for riders:
/// 0 - Origin (MunicipalityPicker + LocationPicker)
/// 1 - Destination (MunicipalityPicker + LocationPicker)
/// 2 - Details (departure datetime, capacity kg)
/// 3 - Review (route map, summary, confirm)
class TripCreationScreen extends ConsumerStatefulWidget {
  const TripCreationScreen({super.key});

  @override
  ConsumerState<TripCreationScreen> createState() =>
      _TripCreationScreenState();
}

class _TripCreationScreenState extends ConsumerState<TripCreationScreen> {
  @override
  void deactivate() {
    ref.read(tripCreationProvider.notifier).reset();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripCreationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New Trip',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(currentStep: tripState.currentStep),
          const Divider(height: 1),

          // Step content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (tripState.currentStep) {
                0 => _OriginStep(key: const ValueKey(0)),
                1 => _DestinationStep(key: const ValueKey(1)),
                2 => _DetailsStep(key: const ValueKey(2)),
                3 => _ReviewStep(key: const ValueKey(3)),
                _ => const SizedBox.shrink(),
              },
            ),
          ),

          // Bottom navigation bar
          _BottomBar(
            currentStep: tripState.currentStep,
            canProceed: tripState.canProceed,
            isCreating: tripState.isCreating,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step Indicator (reusable pattern from checkout)
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(_stepLabels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepBefore = index ~/ 2;
            final completed = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: completed ? AppColors.primary : AppColors.border,
              ),
            );
          }

          final step = index ~/ 2;
          final isActive = step == currentStep;
          final isCompleted = step < currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isActive
                      ? AppColors.primary
                      : AppColors.muted,
                  border: Border.all(
                    color: isCompleted || isActive
                        ? AppColors.primary
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${step + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isActive ? Colors.white : Colors.grey[500],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stepLabels[step],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive || isCompleted
                      ? AppColors.primary
                      : Colors.grey[500],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 0: Origin
// ---------------------------------------------------------------------------

class _OriginStep extends ConsumerWidget {
  const _OriginStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(tripCreationProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Origin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your starting municipality and tap the map for exact location',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // Municipality picker
          MunicipalityPickerWidget(
            initialValue: tripState.originMunicipality,
            hintText: 'Search origin municipality...',
            onSelected: (municipality) {
              ref
                  .read(tripCreationProvider.notifier)
                  .setOriginMunicipality(municipality);
            },
          ),
          const SizedBox(height: 12),

          // Location picker map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LocationPickerWidget(
                initialLocation: tripState.originLocation ??
                    tripState.originMunicipality?.center,
                onLocationSelected: (LatLng location, String address) {
                  ref
                      .read(tripCreationProvider.notifier)
                      .setOriginLocation(location, address);
                },
              ),
            ),
          ),

          // Selected address display
          if (tripState.originAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AddressChip(
              address: tripState.originAddress,
              icon: Icons.trip_origin,
              color: AppColors.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Destination
// ---------------------------------------------------------------------------

class _DestinationStep extends ConsumerWidget {
  const _DestinationStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripState = ref.watch(tripCreationProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destination',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your destination municipality and tap the map for exact location',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // Municipality picker
          MunicipalityPickerWidget(
            initialValue: tripState.destinationMunicipality,
            hintText: 'Search destination municipality...',
            onSelected: (municipality) {
              ref
                  .read(tripCreationProvider.notifier)
                  .setDestinationMunicipality(municipality);
            },
          ),
          const SizedBox(height: 12),

          // Location picker map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LocationPickerWidget(
                initialLocation: tripState.destinationLocation ??
                    tripState.destinationMunicipality?.center,
                onLocationSelected: (LatLng location, String address) {
                  ref
                      .read(tripCreationProvider.notifier)
                      .setDestinationLocation(location, address);
                },
              ),
            ),
          ),

          // Selected address display
          if (tripState.destinationAddress.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AddressChip(
              address: tripState.destinationAddress,
              icon: Icons.location_pin,
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Details (Departure DateTime + Capacity)
// ---------------------------------------------------------------------------

class _DetailsStep extends ConsumerStatefulWidget {
  const _DetailsStep({super.key});

  @override
  ConsumerState<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<_DetailsStep> {
  late TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    final kg = ref.read(tripCreationProvider).capacityKg;
    _capacityController = TextEditingController(
      text: kg > 0 ? kg.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final tripState = ref.read(tripCreationProvider);

    // Pick date
    final date = await showDatePicker(
      context: context,
      initialDate: tripState.departureAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    // Pick time
    final time = await showTimePicker(
      context: context,
      initialTime: tripState.departureAt != null
          ? TimeOfDay.fromDateTime(tripState.departureAt!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    ref.read(tripCreationProvider.notifier).setDepartureAt(combined);
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripCreationProvider);
    final dateFormatter = DateFormat('EEE, MMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');

    final isPastDeparture = tripState.departureAt != null &&
        tripState.departureAt!.isBefore(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set your departure time and available capacity',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // -- Departure DateTime --
          Text(
            'Departure Date & Time',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPastDeparture ? AppColors.error : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 22,
                    color: tripState.departureAt != null
                        ? AppColors.primary
                        : Colors.grey[500],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: tripState.departureAt != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateFormatter.format(tripState.departureAt!),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeFormatter.format(tripState.departureAt!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Tap to select departure time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          if (isPastDeparture) ...[
            const SizedBox(height: 6),
            const Text(
              'Departure time must be in the future',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],

          const SizedBox(height: 24),

          // -- Capacity --
          Text(
            'Available Capacity (kg)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _capacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            onChanged: (value) {
              final kg = double.tryParse(value) ?? 0;
              ref.read(tripCreationProvider.notifier).setCapacityKg(kg);
            },
            decoration: InputDecoration(
              hintText: 'e.g. 50',
              prefixIcon:
                  const Icon(Icons.fitness_center, size: 20),
              suffixText: 'kg',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.muted,
              errorText: _capacityController.text.isNotEmpty &&
                      tripState.capacityKg <= 0
                  ? 'Capacity must be greater than 0'
                  : null,
            ),
          ),

          const SizedBox(height: 24),

          // -- Route summary from previous steps --
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Route',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.trip_origin,
                  iconColor: AppColors.secondary,
                  label: 'From',
                  value: tripState.originMunicipality?.nameEn ??
                      tripState.originAddress,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.location_pin,
                  iconColor: AppColors.error,
                  label: 'To',
                  value: tripState.destinationMunicipality?.nameEn ??
                      tripState.destinationAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Review & Confirm
// ---------------------------------------------------------------------------

class _ReviewStep extends ConsumerStatefulWidget {
  const _ReviewStep({super.key});

  @override
  ConsumerState<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<_ReviewStep> {
  double? _distanceMeters;
  double? _durationSeconds;

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripCreationProvider);
    final dateFormatter = DateFormat('EEE, MMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Trip',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Review your trip details before creating',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // -- Route map preview --
          if (tripState.originLocation != null &&
              tripState.destinationLocation != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 220,
                child: RouteMapWidget(
                  origin: tripState.originLocation!,
                  destination: tripState.destinationLocation!,
                  originName: tripState.originMunicipality?.nameEn ??
                      tripState.originAddress,
                  destinationName:
                      tripState.destinationMunicipality?.nameEn ??
                          tripState.destinationAddress,
                  onRouteLoaded: (distance, duration) {
                    if (mounted) {
                      setState(() {
                        _distanceMeters = distance;
                        _durationSeconds = duration;
                      });
                    }
                  },
                ),
              ),
            ),

          const SizedBox(height: 16),

          // -- Route details --
          _SectionCard(
            title: 'Route',
            icon: Icons.route,
            child: Column(
              children: [
                _DetailRow(
                  label: 'Origin',
                  value: _buildLocationName(
                    tripState.originMunicipality?.nameEn,
                    tripState.originAddress,
                    'Origin',
                  ),
                ),
                _DetailRow(
                  label: 'Destination',
                  value: _buildLocationName(
                    tripState.destinationMunicipality?.nameEn,
                    tripState.destinationAddress,
                    'Destination',
                  ),
                ),
                if (_distanceMeters != null)
                  _DetailRow(
                    label: 'Distance',
                    value:
                        '${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                  ),
                if (_durationSeconds != null)
                  _DetailRow(
                    label: 'Est. Duration',
                    value: _formatDuration(_durationSeconds!),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // -- Trip details --
          _SectionCard(
            title: 'Details',
            icon: Icons.info_outline,
            child: Column(
              children: [
                if (tripState.departureAt != null) ...[
                  _DetailRow(
                    label: 'Departure Date',
                    value: dateFormatter.format(tripState.departureAt!),
                  ),
                  _DetailRow(
                    label: 'Departure Time',
                    value: timeFormatter.format(tripState.departureAt!),
                  ),
                ],
                _DetailRow(
                  label: 'Capacity',
                  value: '${tripState.capacityKg.toStringAsFixed(0)} kg',
                  bold: true,
                ),
              ],
            ),
          ),

          if (tripState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tripState.error!,
                      style:
                          const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildLocationName(
      String? municipalityName, String address, String fallback) {
    if (municipalityName != null && municipalityName.isNotEmpty) {
      return municipalityName;
    }
    if (address.isNotEmpty) {
      // Truncate long addresses for the summary
      return address.length > 50 ? '${address.substring(0, 50)}...' : address;
    }
    return fallback;
  }

  String _formatDuration(double seconds) {
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

// ---------------------------------------------------------------------------
// Shared UI components
// ---------------------------------------------------------------------------

class _AddressChip extends StatelessWidget {
  final String address;
  final IconData icon;
  final Color color;

  const _AddressChip({
    required this.address,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? AppColors.foreground : null,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation bar
// ---------------------------------------------------------------------------

class _BottomBar extends ConsumerWidget {
  final int currentStep;
  final bool canProceed;
  final bool isCreating;

  const _BottomBar({
    required this.currentStep,
    required this.canProceed,
    required this.isCreating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReview = currentStep == 3;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Back button (hidden on first step)
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: isCreating
                    ? null
                    : () => ref
                        .read(tripCreationProvider.notifier)
                        .previousStep(),
                child: const Text('Back'),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),

          // Next / Create Trip button
          Expanded(
            flex: currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: canProceed && !isCreating
                  ? () => _onProceed(context, ref, isReview)
                  : null,
              child: isCreating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(isReview ? 'Create Trip' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  void _onProceed(BuildContext context, WidgetRef ref, bool isReview) {
    if (isReview) {
      _handleCreateTrip(context, ref);
    } else {
      ref.read(tripCreationProvider.notifier).nextStep();
    }
  }

  Future<void> _handleCreateTrip(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(tripCreationProvider.notifier).createTrip();

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip created successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
        ),
      );
      ref.read(tripCreationProvider.notifier).reset();
      context.go(AppRoutes.trips);
    }
  }
}
