import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/enums.dart';
import '../../../core/models/rider_trip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../map/widgets/location_picker.dart';

class PostTripScreen extends StatefulWidget {
  const PostTripScreen({super.key});

  @override
  State<PostTripScreen> createState() => _PostTripScreenState();
}

class _PostTripScreenState extends State<PostTripScreen> {
  final _supabase = Supabase.instance.client;
  final _capacityController = TextEditingController();

  LatLng? _origin;
  String _originName = '';
  LatLng? _destination;
  String _destinationName = '';
  DateTime _departureDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _departureTime = TimeOfDay.now();

  bool _pickingOrigin = false;
  bool _pickingDestination = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _departureDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked != null) {
      setState(() => _departureTime = picked);
    }
  }

  DateTime get _combinedDeparture {
    return DateTime(
      _departureDate.year,
      _departureDate.month,
      _departureDate.day,
      _departureTime.hour,
      _departureTime.minute,
    );
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;
    if (userId == null) return;

    if (_origin == null) {
      setState(() => _error = 'Please select origin location');
      return;
    }
    if (_destination == null) {
      setState(() => _error = 'Please select destination location');
      return;
    }
    final capacity = double.tryParse(_capacityController.text.trim());
    if (capacity == null || capacity <= 0) {
      setState(() => _error = 'Please enter available capacity in kg');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final trip = RiderTrip(
        id: '',
        riderId: userId,
        origin: _origin!,
        originName: _originName,
        destination: _destination!,
        destinationName: _destinationName,
        departureAt: _combinedDeparture,
        availableCapacityKg: capacity,
        remainingCapacityKg: capacity,
        status: TripStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('rider_trips').insert(trip.toInsertJson());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip posted successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Failed to post trip. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Location pickers as full-screen overlays
    if (_pickingOrigin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Origin')),
        body: LocationPickerWidget(
          initialLocation: _origin,
          onLocationSelected: (location, address) {
            setState(() {
              _origin = location;
              _originName = address.isNotEmpty ? address : 'Selected location';
              _pickingOrigin = false;
            });
          },
        ),
      );
    }

    if (_pickingDestination) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Destination')),
        body: LocationPickerWidget(
          initialLocation: _destination,
          onLocationSelected: (location, address) {
            setState(() {
              _destination = location;
              _destinationName =
                  address.isNotEmpty ? address : 'Selected location';
              _pickingDestination = false;
            });
          },
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Post a Trip')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Origin
            _label('Origin'),
            _locationButton(
              icon: Icons.trip_origin,
              color: AppColors.secondary,
              label: _originName.isNotEmpty ? _originName : 'Select origin',
              onTap: () => setState(() => _pickingOrigin = true),
            ),
            const SizedBox(height: 16),

            // Destination
            _label('Destination'),
            _locationButton(
              icon: Icons.location_pin,
              color: AppColors.error,
              label: _destinationName.isNotEmpty
                  ? _destinationName
                  : 'Select destination',
              onTap: () => setState(() => _pickingDestination = true),
            ),
            const SizedBox(height: 16),

            // Departure date and time
            _label('Departure'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(dateFormat.format(_departureDate)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_departureTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Capacity
            _label('Available Capacity (kg)'),
            TextField(
              controller: _capacityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                hintText: 'e.g. 50',
                suffixText: 'kg',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Posting...' : 'Post Trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _locationButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: AppColors.muted,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: label.startsWith('Select')
                      ? Colors.grey[500]
                      : AppColors.foreground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
