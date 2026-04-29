import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jirisewa_mobile/features/hubs/providers/hub_providers.dart';
import 'package:jirisewa_mobile/features/hubs/repositories/hub_repository.dart';

class HubInventoryScreen extends ConsumerStatefulWidget {
  const HubInventoryScreen({super.key});

  @override
  ConsumerState<HubInventoryScreen> createState() => _HubInventoryScreenState();
}

class _HubInventoryScreenState extends ConsumerState<HubInventoryScreen> {
  String _filter = 'all';
  String? _actionError;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final hubAsync = ref.watch(myOperatedHubProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hub inventory')),
      body: hubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
        data: (hub) {
          if (hub == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'You are not assigned as the operator of any active hub. '
                  'Ask an admin to assign you.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final inventoryAsync = ref.watch(hubInventoryProvider(hub.id));
          return inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (rows) {
              final counts = <String, int>{
                for (final s in const [
                  'dropped_off',
                  'in_inventory',
                  'dispatched',
                  'expired',
                  'spoiled',
                ])
                  s: rows.where((r) => r.status == s).length,
              };
              final filtered =
                  _filter == 'all' ? rows : rows.where((r) => r.status == _filter).toList();

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hub.nameEn,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(hub.address,
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _Tab(
                          label: 'All (${rows.length})',
                          active: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                          tabKey: 'tab-all',
                        ),
                        _Tab(
                          label: 'Awaiting (${counts['dropped_off']})',
                          active: _filter == 'dropped_off',
                          onTap: () => setState(() => _filter = 'dropped_off'),
                          tabKey: 'tab-dropped_off',
                        ),
                        _Tab(
                          label: 'In inventory (${counts['in_inventory']})',
                          active: _filter == 'in_inventory',
                          onTap: () => setState(() => _filter = 'in_inventory'),
                          tabKey: 'tab-in_inventory',
                        ),
                        _Tab(
                          label: 'Dispatched (${counts['dispatched']})',
                          active: _filter == 'dispatched',
                          onTap: () => setState(() => _filter = 'dispatched'),
                          tabKey: 'tab-dispatched',
                        ),
                        _Tab(
                          label: 'Expired (${counts['expired']})',
                          active: _filter == 'expired',
                          onTap: () => setState(() => _filter = 'expired'),
                          tabKey: 'tab-expired',
                        ),
                        _Tab(
                          label: 'Spoiled (${counts['spoiled']})',
                          active: _filter == 'spoiled',
                          onTap: () => setState(() => _filter = 'spoiled'),
                          tabKey: 'tab-spoiled',
                        ),
                      ],
                    ),
                  ),
                  if (_actionError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      color: Colors.red.shade50,
                      child: Text(_actionError!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            key: Key('empty'),
                            child: Text(
                              'No dropoffs in this state.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final d = filtered[i];
                              return _InventoryTile(
                                key: Key('inventory-row-${d.id}'),
                                d: d,
                                busy: _busy,
                                onReceive: () => _doAction(
                                  () => ref
                                      .read(hubRepositoryProvider)
                                      .markReceived(d.id),
                                  hubId: hub.id,
                                ),
                                onSpoil: () => _doAction(
                                  () => ref
                                      .read(hubRepositoryProvider)
                                      .markSpoiled(d.id),
                                  hubId: hub.id,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _doAction(Future<void> Function() fn, {required String hubId}) async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await fn();
      ref.invalidate(hubInventoryProvider(hubId));
    } catch (e) {
      setState(() => _actionError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String tabKey;
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.tabKey,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        key: Key(tabKey),
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final DropoffInfo d;
  final bool busy;
  final VoidCallback onReceive;
  final VoidCallback onSpoil;
  const _InventoryTile({
    super.key,
    required this.d,
    required this.busy,
    required this.onReceive,
    required this.onSpoil,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lot ${d.lotCode} · ${d.listingName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text(d.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${d.farmerName} · ${d.quantityKg.toStringAsFixed(1)} kg',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              'Dropped ${_short(d.droppedAt)} · expires ${_short(d.expiresAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (d.status == 'dropped_off')
                  ElevatedButton(
                    key: Key('receive-${d.id}'),
                    onPressed: busy ? null : onReceive,
                    child: const Text('Mark received'),
                  ),
                if (d.status == 'dropped_off' || d.status == 'in_inventory')
                  OutlinedButton(
                    key: Key('spoil-${d.id}'),
                    onPressed: busy ? null : onSpoil,
                    child: const Text('Spoiled'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _short(DateTime t) {
    final local = t.toLocal();
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
