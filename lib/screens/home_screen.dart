import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/location.dart';
import '../models/weather_summary.dart';
import '../services/archive_cache_service.dart';
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

DateTime _todayDateOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _service = OpenMeteoService();
  final _settingsService = SettingsService();
  final _cache = ArchiveCacheService();

  Location? _location;
  DateTime? _startDate;
  DateTime? _endDate = _todayDateOnly();

  bool _loading = false;
  String? _error;
  WeatherSummary? _summary;
  AppSettings _settings = const AppSettings();

  // Open-Meteo's archive endpoint gives no real progress signal -- the wait
  // is almost entirely server think-time before any bytes arrive (measured
  // directly: first-time lookups ~4s, repeats ~0.5s, near-identical whether
  // the response is 2 fields or 21). So rather than a raw spinner, this
  // narrates the real, discrete steps we *do* know about (cache check,
  // network fetch, local aggregation) via [_loadingStage], paired with an
  // animated percentage that eases toward ~92% and holds there until the
  // step actually finishes, then snaps to 100% -- honest about being a
  // heuristic, not a byte-accurate measurement, while still giving the user
  // continuous evidence that something is happening.
  AnimationController? _progressController;
  Animation<double>? _progressAnimation;
  String _loadingStage = '';

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
    _progressController?.dispose();
    _service.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _location != null && _startDate != null && _endDate != null && !_endDate!.isBefore(_startDate!);

  Future<void> _submit() async {
    if (!_canSubmit) return;

    _progressController?.dispose();
    final controller = AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _progressController = controller;
    _progressAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
    controller.forward();

    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
      _loadingStage = 'Checking local cache…';
    });

    try {
      var daily = await _cache.lookup(location: _location!, start: _startDate!, end: _endDate!);
      if (daily == null) {
        if (mounted) setState(() => _loadingStage = 'Asking Open-Meteo for historical data…');
        final raw = await _service.fetchDailyArchive(
          location: _location!,
          startDate: _startDate!,
          endDate: _endDate!,
        );
        daily = raw['daily'] as Map<String, dynamic>?;
        if (daily == null) {
          throw OpenMeteoException('No daily data returned for this location/date range.');
        }
        if (mounted) setState(() => _loadingStage = 'Caching results for next time…');
        await _cache.store(location: _location!, start: _startDate!, end: _endDate!, daily: daily);
      }

      if (mounted) setState(() => _loadingStage = 'Computing medians…');
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

      await controller.animateTo(1.0, duration: const Duration(milliseconds: 200));
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      await controller.animateTo(1.0, duration: const Duration(milliseconds: 150));
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
      _progressController?.dispose();
      _progressController = null;
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

  Widget _buildProgress(BuildContext context, double value) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(_loadingStage, style: textTheme.bodySmall)),
            Text('${(value * 100).round()}%', style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: scheme.surface.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        ),
      ],
    );
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
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _canSubmit && !_loading ? _submit : null,
                    style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 17)),
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.air, size: 24),
                    label: Text(
                      _loading ? 'Summoning the winds…' : 'Summon the median historical weather data',
                    ),
                  ),
                ),
                if (_loading && _progressAnimation != null) ...[
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _progressAnimation!,
                    builder: (context, _) => _buildProgress(context, _progressAnimation!.value),
                  ),
                ],
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
