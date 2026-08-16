import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/location.dart';
import '../models/weather_summary.dart';
import '../services/device_location_service.dart';
import '../services/open_meteo_service.dart';
import '../services/settings_service.dart';
import '../services/weather_aggregator.dart';
import '../widgets/aeolus_scaffold.dart';
import '../widgets/date_range_picker.dart';
import '../widgets/json_output_panel.dart';
import '../widgets/location_picker.dart';
import '../widgets/weather_summary_view.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = OpenMeteoService();
  final _settingsService = SettingsService();

  Location? _location;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = false;
  String? _error;
  WeatherSummary? _summary;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _loadInitialSettingsAndLocation();
  }

  Future<void> _loadInitialSettingsAndLocation() async {
    final settings = await _settingsService.load();
    _service.apiKey = settings.apiKey;

    Location? initialLocation = settings.defaultLocation;
    initialLocation ??= await DeviceLocationService().tryGetCurrentLocation();

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _location ??= initialLocation;
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _location != null && _startDate != null && _endDate != null && !_endDate!.isBefore(_startDate!);

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
    });

    try {
      final raw = await _service.fetchDailyArchive(
        location: _location!,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      final daily = raw['daily'] as Map<String, dynamic>?;
      if (daily == null) {
        throw OpenMeteoException('No daily data returned for this location/date range.');
      }
      final summary = aggregateDailyArchive(
        location: _location!,
        startDate: _startDate!,
        endDate: _endDate!,
        daily: daily,
      );
      if (!summary.hasAnyData) {
        throw OpenMeteoException(
          'Open-Meteo has no historical data for this location and date range.',
        );
      }
      setState(() => _summary = summary);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<AppSettings>(
      MaterialPageRoute(builder: (_) => SettingsScreen(initialSettings: _settings)),
    );
    if (result == null) return;

    setState(() {
      _settings = result;
      _service.apiKey = result.apiKey;
      _location ??= result.defaultLocation;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AeolusScaffold(
      title: 'Historical Weather',
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.tune),
          onPressed: _openSettings,
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationPicker(
                  service: _service,
                  selected: _location,
                  onSelected: (location) => setState(() => _location = location),
                ),
                const SizedBox(height: 24),
                DateRangePicker(
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartDateChanged: (date) => setState(() {
                    _startDate = date;
                    if (_endDate != null && _endDate!.isBefore(date)) _endDate = date;
                  }),
                  onEndDateChanged: (date) => setState(() => _endDate = date),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canSubmit && !_loading ? _submit : null,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.air),
                    label: const Text('Summon the winds'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_summary != null) ...[
                  const SizedBox(height: 24),
                  WeatherSummaryView(summary: _summary!),
                  const SizedBox(height: 16),
                  JsonOutputPanel(data: _summary!.toJson()),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
