import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/municipality.dart';

/// Autocomplete search widget for selecting a Nepal municipality.
/// Searches via the `search_municipalities` Supabase RPC function.
class MunicipalityPickerWidget extends StatefulWidget {
  final Municipality? initialValue;
  final ValueChanged<Municipality?> onSelected;
  final String hintText;

  const MunicipalityPickerWidget({
    super.key,
    this.initialValue,
    required this.onSelected,
    this.hintText = 'Search municipality...',
  });

  @override
  State<MunicipalityPickerWidget> createState() =>
      _MunicipalityPickerWidgetState();
}

class _MunicipalityPickerWidgetState extends State<MunicipalityPickerWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Municipality> _results = [];
  Municipality? _selected;
  bool _isLoading = false;
  bool _showDropdown = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _results.isEmpty) {
        _search(_controller.text);
      }
      setState(() => _showDropdown = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.rpc('search_municipalities', params: {
        'p_query': query.isEmpty ? null : query,
        'p_limit': 15,
      });

      if (!mounted) return;

      final List<dynamic> data = response as List<dynamic>;
      setState(() {
        _results = data
            .map((json) =>
                Municipality.fromJson(json as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isLoading = false;
      });
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(query);
    });
  }

  void _selectMunicipality(Municipality m) {
    setState(() {
      _selected = m;
      _showDropdown = false;
    });
    _controller.clear();
    _focusNode.unfocus();
    widget.onSelected(m);
  }

  void _clear() {
    setState(() {
      _selected = null;
    });
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected!.nameEn,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                  Text(
                    '${_selected!.district}, ${_selected!.provinceNameEn}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF059669)),
              onPressed: _clear,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        if (_showDropdown && (_results.isNotEmpty || _isLoading))
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final m = _results[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, size: 18),
                  title: Text(m.nameEn),
                  subtitle: Text(
                    '${m.district}, ${m.provinceNameEn}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _selectMunicipality(m),
                );
              },
            ),
          ),
      ],
    );
  }
}
