import 'package:flutter/material.dart';

import '../models/aggregation_method.dart';
import '../models/app_settings.dart';
import '../models/location.dart';
import '../models/unit_system.dart';
import '../services/nominatim_service.dart';
import '../services/open_meteo_service.dart';
import '../services/settings_service.dart';
import '../theme_mode_notifier.dart';
import '../widgets/aeolus_scaffold.dart';
import '../widgets/glass_card.dart';
import '../widgets/location_picker.dart';

/// Lets the user set an optional Open-Meteo API key, a default location
/// override, the app's light/dark theme preference, and default aggregation
/// method / unit system. Returns the saved [AppSettings] via
/// `Navigator.pop` so the caller can apply it immediately.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initialSettings});

  final AppSettings initialSettings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final OpenMeteoService _pickerService;
  late final NominatimService _pickerNominatimService;
  late Location? _defaultLocation;
  late ThemeMode _themeMode;
  late AggregationMethod _aggregationMethod;
  late UnitSystem _unitSystem;
  bool _obscureApiKey = true;

  // The theme toggle below applies to [themeModeNotifier] immediately, for
  // an instant preview, unlike every other setting on this screen (which
  // only take effect on Save). If the user backs out without saving, that
  // live preview needs to be reverted -- otherwise the app-wide theme and
  // the persisted settings silently diverge until Settings is reopened.
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.initialSettings.apiKey ?? '');
    _pickerService = OpenMeteoService();
    _pickerNominatimService = NominatimService();
    _defaultLocation = widget.initialSettings.defaultLocation;
    _themeMode = widget.initialSettings.themeMode;
    _aggregationMethod = widget.initialSettings.aggregationMethod;
    _unitSystem = widget.initialSettings.unitSystem;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _pickerService.dispose();
    _pickerNominatimService.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = AppSettings(
      apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
      defaultLocation: _defaultLocation,
      themeMode: _themeMode,
      aggregationMethod: _aggregationMethod,
      unitSystem: _unitSystem,
    );
    await SettingsService().save(settings);
    themeModeNotifier.value = _themeMode;
    _saved = true;
    if (mounted) Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_saved) {
          themeModeNotifier.value = widget.initialSettings.themeMode;
        }
      },
      child: AeolusScaffold(
        title: 'Settings',
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {_themeMode},
                          onSelectionChanged: (selection) {
                            final mode = selection.first;
                            setState(() => _themeMode = mode);
                            themeModeNotifier.value = mode;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Units', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Used to prefill each lookup; can still be overridden per-query on the '
                          'home screen.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Text('Aggregation method', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        SegmentedButton<AggregationMethod>(
                          segments: const [
                            ButtonSegment(value: AggregationMethod.median, label: Text('Median')),
                            ButtonSegment(value: AggregationMethod.average, label: Text('Average')),
                          ],
                          selected: {_aggregationMethod},
                          onSelectionChanged: (selection) =>
                              setState(() => _aggregationMethod = selection.first),
                        ),
                        const SizedBox(height: 16),
                        Text('Units', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        SegmentedButton<UnitSystem>(
                          segments: const [
                            ButtonSegment(value: UnitSystem.imperial, label: Text('Imperial')),
                            ButtonSegment(value: UnitSystem.metric, label: Text('Metric')),
                          ],
                          selected: {_unitSystem},
                          onSelectionChanged: (selection) => setState(() => _unitSystem = selection.first),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Open-Meteo API key', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Optional. Only needed for a commercial Open-Meteo plan (higher rate limits). '
                          'Stored only on this device and sent only to Open-Meteo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            labelText: 'API key',
                            suffixIcon: IconButton(
                              icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Default location override', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'If set, this location is used on launch instead of trying to detect your '
                          'device location.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        LocationPicker(
                          service: _pickerService,
                          nominatimService: _pickerNominatimService,
                          selected: _defaultLocation,
                          onSelected: (location) => setState(() => _defaultLocation = location),
                        ),
                        if (_defaultLocation != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(() => _defaultLocation = null),
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear override'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
