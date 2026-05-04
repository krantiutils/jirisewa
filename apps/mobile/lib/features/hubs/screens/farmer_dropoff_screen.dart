import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/features/hubs/providers/hub_providers.dart';
import 'package:jirisewa_mobile/features/hubs/repositories/hub_repository.dart';

class FarmerDropoffScreen extends ConsumerStatefulWidget {
  const FarmerDropoffScreen({super.key});

  @override
  ConsumerState<FarmerDropoffScreen> createState() => _FarmerDropoffScreenState();
}

class _FarmerDropoffScreenState extends ConsumerState<FarmerDropoffScreen> {
  String? _selectedHubId;
  String? _selectedListingId;
  final _qtyController = TextEditingController(text: '5');
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Derive selected ids from provider data at submit time, falling back to
    // the first available row. This avoids a race where build sets the
    // member fields after layout but before the user taps submit.
    final hubsValue = ref.read(originHubsProvider).valueOrNull ?? const <HubInfo>[];
    final listingsValue =
        ref.read(myActiveListingsProvider).valueOrNull ?? const <Map<String, dynamic>>[];
    final hubId = _selectedHubId ?? (hubsValue.isNotEmpty ? hubsValue.first.id : null);
    final listingId = _selectedListingId ??
        (listingsValue.isNotEmpty ? listingsValue.first['id'] as String : null);
    final qty = double.tryParse(_qtyController.text.trim());
    if (hubId == null || listingId == null || qty == null || qty <= 0) {
      setState(() => _error = 'Please fill in all fields with valid values.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final repo = ref.read(hubRepositoryProvider);
      final result = await repo.recordDropoff(
        hubId: hubId,
        listingId: listingId,
        quantityKg: qty,
      );
      ref.invalidate(myDropoffsProvider);
      if (!mounted) return;
      setState(() {
        _lastResult = result;
        _qtyController.text = '5';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hubsAsync = ref.watch(originHubsProvider);
    final listingsAsync = ref.watch(myActiveListingsProvider);
    final dropoffsAsync = ref.watch(myDropoffsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Drop off at hub')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Drop your produce at a hub. The hub operator will confirm '
              'receipt and a rider will pick it up — you don\'t need to wait '
              'at your farm.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            hubsAsync.when(
              data: (hubs) {
                if (hubs.isEmpty) {
                  return const _Notice(
                    icon: Icons.warning_amber,
                    text: 'No active origin hubs available right now.',
                  );
                }
                _selectedHubId ??= hubs.first.id;
                return DropdownButtonFormField<String>(
                  key: const Key('dropoff-hub'),
                  decoration: const InputDecoration(labelText: 'Hub'),
                  initialValue: _selectedHubId,
                  items: hubs
                      .map((h) => DropdownMenuItem(
                            value: h.id,
                            child: Text('${h.nameEn} — ${h.address}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedHubId = v),
                );
              },
              loading: () => const _Loading(),
              error: (e, _) => _Notice(
                icon: Icons.error_outline,
                text: 'Failed to load hubs: $e',
              ),
            ),
            const SizedBox(height: 12),
            listingsAsync.when(
              data: (listings) {
                if (listings.isEmpty) {
                  return const _Notice(
                    icon: Icons.warning_amber,
                    text: 'Create an active listing first, then drop off here.',
                  );
                }
                _selectedListingId ??= listings.first['id'] as String;
                return DropdownButtonFormField<String>(
                  key: const Key('dropoff-listing'),
                  decoration: const InputDecoration(labelText: 'Listing'),
                  initialValue: _selectedListingId,
                  items: listings
                      .map((l) => DropdownMenuItem(
                            value: l['id'] as String,
                            child: Text(l['name_en'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedListingId = v),
                );
              },
              loading: () => const _Loading(),
              error: (e, _) => _Notice(
                icon: Icons.error_outline,
                text: 'Failed to load listings: $e',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dropoff-qty'),
              controller: _qtyController,
              decoration: const InputDecoration(labelText: 'Quantity (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade50,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_lastResult != null)
              Container(
                key: const Key('dropoff-success'),
                padding: const EdgeInsets.all(12),
                color: Colors.green.shade50,
                child: Text(
                  'Lot code: ${_lastResult!['lot_code']} — keep this for reference.',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('dropoff-submit'),
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Recording…' : 'Record dropoff'),
            ),
            const SizedBox(height: 24),
            const Text('Your recent dropoffs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            dropoffsAsync.when(
              data: (rows) => rows.isEmpty
                  ? const Text('No dropoffs yet.',
                      style: TextStyle(color: Colors.grey))
                  : Column(
                      children: rows
                          .map((d) => _DropoffTile(d: d))
                          .toList(growable: false),
                    ),
              loading: () => const _Loading(),
              error: (e, _) => Text('Failed to load: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropoffTile extends StatelessWidget {
  final DropoffInfo d;
  const _DropoffTile({required this.d});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${d.listingName} — ${d.quantityKg.toStringAsFixed(1)} kg'),
        subtitle: Text(
          'Lot ${d.lotCode} · ${d.hubName} · ${d.status}',
        ),
        trailing: Text(
          _shortTime(d.droppedAt),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  String _shortTime(DateTime t) {
    final local = t.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Notice({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.amber.shade50,
        child: Row(
          children: [
            Icon(icon, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
