import 'dart:async';

import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/open_meteo_service.dart';
import 'glass_card.dart';

/// Lets the user either search for a place by name (via Open-Meteo
/// geocoding, live as they type) or expand a section to type exact
/// latitude/longitude.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.service,
    required this.selected,
    required this.onSelected,
  });

  final OpenMeteoService service;
  final Location? selected;
  final ValueChanged<Location> onSelected;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  static const _debounceDuration = Duration(milliseconds: 350);
  static const _minQueryLength = 2;

  final _searchController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  List<Location> _results = [];
  bool _searching = false;
  String? _error;
  bool _manualExpanded = false;

  Timer? _debounce;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.length < _minQueryLength) {
      _requestGeneration++;
      setState(() {
        _results = [];
        _error = null;
        _searching = false;
      });
      return;
    }

    _debounce = Timer(_debounceDuration, () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    _debounce?.cancel();
    final generation = ++_requestGeneration;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await widget.service.searchLocations(query);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _error = 'No matching locations found.';
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _error = 'Search failed: $e');
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _searching = false);
      }
    }
  }

  void _submitManualCoordinates() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    // NaN compares false against every bound (`double.nan < -90` is false,
    // same for `> 90`), so it would otherwise sail through the range check
    // below -- `double.tryParse('NaN')` returns `double.nan`, not `null`.
    if (lat == null || lat.isNaN || lat < -90 || lat > 90) {
      setState(() => _error = 'Latitude must be a number between -90 and 90.');
      return;
    }
    if (lon == null || lon.isNaN || lon < -180 || lon > 180) {
      setState(() => _error = 'Longitude must be a number between -180 and 180.');
      return;
    }
    setState(() => _error = null);
    widget.onSelected(Location.manual(latitude: lat, longitude: lon));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.selected != null)
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.explore),
              title: Text(widget.selected!.displayLabel),
              subtitle: Text(
                '${widget.selected!.latitude.toStringAsFixed(4)}, '
                '${widget.selected!.longitude.toStringAsFixed(4)}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search for a city or place',
            hintText: 'e.g. Austin, TX',
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null),
          ),
          onSubmitted: _search,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final location = _results[index];
                  return ListTile(
                    leading: const Icon(Icons.air, size: 20),
                    title: Text(location.displayLabel),
                    subtitle: Text(
                      '${location.latitude.toStringAsFixed(4)}, '
                      '${location.longitude.toStringAsFixed(4)}',
                    ),
                    onTap: () {
                      _debounce?.cancel();
                      _requestGeneration++;
                      widget.onSelected(location);
                      setState(() => _results = []);
                      _searchController.clear();
                    },
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _manualExpanded = !_manualExpanded),
          icon: Icon(_manualExpanded ? Icons.expand_less : Icons.expand_more),
          label: const Text('Enter coordinates manually'),
        ),
        if (_manualExpanded) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lonController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _submitManualCoordinates,
                child: const Text('Use'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
