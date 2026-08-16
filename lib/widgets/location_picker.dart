import 'package:flutter/material.dart';

import '../models/location.dart';
import '../services/open_meteo_service.dart';

/// Lets the user either search for a place by name (via Open-Meteo
/// geocoding) or expand a section to type exact latitude/longitude.
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
  final _searchController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  List<Location> _results = [];
  bool _searching = false;
  String? _error;
  bool _manualExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await widget.service.searchLocations(query);
      setState(() {
        _results = results;
        if (results.isEmpty) _error = 'No matching locations found.';
      });
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      setState(() => _searching = false);
    }
  }

  void _submitManualCoordinates() {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null || lat < -90 || lat > 90) {
      setState(() => _error = 'Latitude must be a number between -90 and 90.');
      return;
    }
    if (lon == null || lon < -180 || lon > 180) {
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.place),
              title: Text(widget.selected!.displayLabel),
              subtitle: Text(
                '${widget.selected!.latitude.toStringAsFixed(4)}, '
                '${widget.selected!.longitude.toStringAsFixed(4)}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search for a city or place',
                  hintText: 'e.g. Austin, TX',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _searching ? null : _search,
              child: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Search'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Card(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final location = _results[index];
                  return ListTile(
                    title: Text(location.displayLabel),
                    subtitle: Text(
                      '${location.latitude.toStringAsFixed(4)}, '
                      '${location.longitude.toStringAsFixed(4)}',
                    ),
                    onTap: () {
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
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lonController,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                  ),
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
