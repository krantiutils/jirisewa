import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:jirisewa_mobile/core/providers/supabase_provider.dart';
import 'package:jirisewa_mobile/core/providers/session_provider.dart';

enum UserRole { farmer, consumer, rider }

enum VehicleType { bike, car, truck, bus, other }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _totalSteps = 3;

  int _step = 1;
  bool _loading = false;
  String? _error;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _municipalityController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _capacityController = TextEditingController();

  String _lang = 'ne';
  final Set<UserRole> _roles = {};
  VehicleType _vehicleType = VehicleType.bike;

  // Fixed route for bus/truck riders
  String? _fixedRouteOriginName;
  double? _fixedRouteOriginLat;
  double? _fixedRouteOriginLng;
  String? _fixedRouteDestName;
  double? _fixedRouteDestLat;
  double? _fixedRouteDestLng;

  final _fixedRouteOriginController = TextEditingController();
  final _fixedRouteDestController = TextEditingController();

  SupabaseClient get _supabase => ref.read(supabaseProvider);

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _municipalityController.dispose();
    _farmNameController.dispose();
    _capacityController.dispose();
    _fixedRouteOriginController.dispose();
    _fixedRouteDestController.dispose();
    super.dispose();
  }

  bool _validateStep() {
    if (_step == 1 && _nameController.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return false;
    }
    if (_step == 2 && _roles.isEmpty) {
      setState(() => _error = 'Please select at least one role');
      return false;
    }
    return true;
  }

  void _next() {
    if (!_validateStep()) return;
    setState(() {
      _step = (_step + 1).clamp(1, _totalSteps);
      _error = null;
    });
  }

  void _back() {
    setState(() {
      _step = (_step - 1).clamp(1, _totalSteps);
      _error = null;
    });
  }

  Future<void> _complete() async {
    if (!_validateStep()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();

      // 1a. Upsert user profile in `users` table (role is NOT NULL in DB)
      await _supabase.from('users').upsert({
        'id': user.id,
        'phone': user.phone ?? '',
        'name': name,
        'role': _roles.first.name,
        'lang': _lang,
        'address':
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        'municipality':
            _municipalityController.text.trim().isEmpty
                ? null
                : _municipalityController.text.trim(),
      });

      // 1b. Upsert `user_profiles` row for cross-platform compatibility.
      // The web app uses user_profiles (created via OAuth callback).
      // Mobile users also need this row so the web app recognises them.
      await _supabase.from('user_profiles').upsert({
        'id': user.id,
        'email': user.email ?? '',
        'full_name': name,
        'role': _roles.first.name,
        'onboarding_completed': true,
      });

      // 1c. Update user_profiles with vehicle type and fixed route for riders
      if (_roles.contains(UserRole.rider)) {
        final profileUpdate = <String, dynamic>{
          'vehicle_type': _vehicleType.name,
        };
        if (_vehicleType == VehicleType.bus ||
            _vehicleType == VehicleType.truck) {
          if (_fixedRouteOriginName != null) {
            profileUpdate['fixed_route_origin_name'] = _fixedRouteOriginName;
            if (_fixedRouteOriginLat != null &&
                _fixedRouteOriginLng != null) {
              profileUpdate['fixed_route_origin'] =
                  'POINT($_fixedRouteOriginLng $_fixedRouteOriginLat)';
            }
          }
          if (_fixedRouteDestName != null) {
            profileUpdate['fixed_route_destination_name'] = _fixedRouteDestName;
            if (_fixedRouteDestLat != null && _fixedRouteDestLng != null) {
              profileUpdate['fixed_route_destination'] =
                  'POINT($_fixedRouteDestLng $_fixedRouteDestLat)';
            }
          }
        }
        await _supabase
            .from('user_profiles')
            .update(profileUpdate)
            .eq('id', user.id);
      }

      // 2. Insert user roles
      final roleInserts =
          _roles.map((role) {
            final row = <String, dynamic>{
              'user_id': user.id,
              'role': role.name,
            };
            if (role == UserRole.farmer &&
                _farmNameController.text.trim().isNotEmpty) {
              row['farm_name'] = _farmNameController.text.trim();
            }
            if (role == UserRole.rider) {
              row['vehicle_type'] = _vehicleType.name;
              final capacity = double.tryParse(
                _capacityController.text.trim(),
              );
              if (capacity != null && capacity > 0) {
                row['vehicle_capacity_kg'] = capacity;
              }
            }
            return row;
          }).toList();

      await _supabase
          .from('user_roles')
          .upsert(roleInserts, onConflict: 'user_id,role');

      if (!mounted) return;

      // Refresh the Riverpod session so it picks up the new profile/roles,
      // then GoRouter redirect navigates to /home automatically.
      await ref.read(userSessionProvider.notifier).refresh();
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _error = 'Registration failed: ${e.message}';
      });
    } catch (e) {
      debugPrint('Registration error: $e');
      setState(() {
        _loading = false;
        _error = 'Registration failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Complete Your Profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tell us about yourself to get started',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Step $_step of $_totalSteps',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _step / _totalSteps,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFF3F4F6),
                ),
              ),
              const SizedBox(height: 24),

              // Step content
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                children: [
                  if (_step > 1) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child:
                        _step < _totalSteps
                            ? ElevatedButton(
                              onPressed: _next,
                              child: const Text('Next'),
                            )
                            : ElevatedButton(
                              onPressed: _loading ? null : _complete,
                              child: Text(
                                _loading
                                    ? 'Completing...'
                                    : 'Complete Registration',
                              ),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Full Name'),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Your full name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        _label('Preferred Language'),
        Row(
          children: [
            _langButton('ne', 'नेपाली'),
            const SizedBox(width: 12),
            _langButton('en', 'English'),
          ],
        ),
        const SizedBox(height: 16),
        _label('Address'),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(
            hintText: 'Your address or municipality',
          ),
        ),
        const SizedBox(height: 16),
        _label('Municipality'),
        TextField(
          controller: _municipalityController,
          decoration: const InputDecoration(
            hintText: 'e.g. Jiri, Kathmandu',
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'I am a...',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select all that apply',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 16),
        _roleButton(
          UserRole.farmer,
          'Farmer',
          'I grow and sell produce',
          const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),
        _roleButton(
          UserRole.consumer,
          'Consumer',
          'I buy fresh produce',
          const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _roleButton(
          UserRole.rider,
          'Rider',
          'I travel and can carry produce',
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final hasFarmer = _roles.contains(UserRole.farmer);
    final hasRider = _roles.contains(UserRole.rider);

    if (!hasFarmer && !hasRider) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Tell us about yourself to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFarmer) ...[
          _label('Farm Name'),
          TextField(
            controller: _farmNameController,
            decoration: const InputDecoration(hintText: 'Name of your farm'),
          ),
          const SizedBox(height: 16),
        ],
        if (hasRider) ...[
          _label('Vehicle Type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                VehicleType.values.map((vt) => _vehicleButton(vt)).toList(),
          ),
          const SizedBox(height: 16),
          _label('Carrying Capacity (kg)'),
          TextField(
            controller: _capacityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: const InputDecoration(hintText: 'e.g. 50'),
          ),
          if (_vehicleType == VehicleType.bus ||
              _vehicleType == VehicleType.truck) ...[
            const SizedBox(height: 24),
            Text(
              'Fixed Route',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _label('Route Origin'),
            TextField(
              controller: _fixedRouteOriginController,
              decoration: InputDecoration(
                hintText: 'e.g. Jiri',
                prefixIcon: const Icon(
                  Icons.trip_origin,
                  color: Color(0xFF10B981),
                ),
                suffixIcon:
                    _fixedRouteOriginController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _fixedRouteOriginController.clear();
                              _fixedRouteOriginName = null;
                              _fixedRouteOriginLat = null;
                              _fixedRouteOriginLng = null;
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                setState(() {
                  _fixedRouteOriginName =
                      value.trim().isEmpty ? null : value.trim();
                });
              },
            ),
            const SizedBox(height: 12),
            _label('Route Destination'),
            TextField(
              controller: _fixedRouteDestController,
              decoration: InputDecoration(
                hintText: 'e.g. Kathmandu',
                prefixIcon: const Icon(
                  Icons.location_on,
                  color: Color(0xFFEF4444),
                ),
                suffixIcon:
                    _fixedRouteDestController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _fixedRouteDestController.clear();
                              _fixedRouteDestName = null;
                              _fixedRouteDestLat = null;
                              _fixedRouteDestLng = null;
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                setState(() {
                  _fixedRouteDestName =
                      value.trim().isEmpty ? null : value.trim();
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Enter route names \u2014 GPS coordinates are optional for now',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ],
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _langButton(String lang, String label) {
    final selected = _lang == lang;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _lang = lang),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFFE5E7EB),
              width: 2,
            ),
            color:
                selected
                    ? Theme.of(context).colorScheme.primary.withAlpha(25)
                    : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color:
                  selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton(
    UserRole role,
    String label,
    String desc,
    Color color,
  ) {
    final selected = _roles.contains(role);
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _roles.remove(role);
          } else {
            _roles.add(role);
          }
          _error = null;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: 2,
          ),
          color: selected ? color.withAlpha(25) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: selected ? color : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 14,
                color: selected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleButton(VehicleType vt) {
    final selected = _vehicleType == vt;
    final label =
        vt.name[0].toUpperCase() + vt.name.substring(1); // capitalize
    return InkWell(
      onTap: () => setState(() => _vehicleType = vt),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                selected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFE5E7EB),
            width: 2,
          ),
          color:
              selected
                  ? Theme.of(context).colorScheme.primary.withAlpha(25)
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color:
                selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
