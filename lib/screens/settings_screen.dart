import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/location.dart';
import '../services/open_meteo_service.dart';
import '../services/settings_service.dart';
import '../theme_mode_notifier.dart';
import '../widgets/location_picker.dart';

/// Lets the user set an optional Open-Meteo API key, a default location
/// override, and the app's light/dark theme preference. Returns the saved
/// [AppSettings] via `Navigator.pop` so the caller can apply it immediately.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initialSettings});

  final AppSettings initialSettings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final OpenMeteoService _pickerService;
  late Location? _defaultLocation;
  late ThemeMode _themeMode;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.initialSettings.apiKey ?? '');
    _pickerService = OpenMeteoService();
    _defaultLocation = widget.initialSettings.defaultLocation;
    _themeMode = widget.initialSettings.themeMode;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _pickerService.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = AppSettings(
      apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
      defaultLocation: _defaultLocation,
      themeMode: _themeMode,
    );
    await SettingsService().save(settings);
    themeModeNotifier.value = _themeMode;
    if (mounted) Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (selection) {
                    final mode = selection.first;
                    setState(() => _themeMode = mode);
                    themeModeNotifier.value = mode;
                  },
                ),
                const SizedBox(height: 32),
                Text('Open-Meteo API key', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Optional. Only needed for a commercial Open-Meteo plan (higher rate limits). '
                  'Stored only on this device and sent only to Open-Meteo.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Default location override', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'If set, this location is used on launch instead of trying to detect your '
                  'device location.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                LocationPicker(
                  service: _pickerService,
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
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _save, child: const Text('Save')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
