import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'theme/aeolus_theme.dart';
import 'theme_mode_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService().load();
  themeModeNotifier.value = settings.themeMode;
  runApp(const HistoricalWeatherApp());
}

class HistoricalWeatherApp extends StatelessWidget {
  const HistoricalWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Aeolus — Historical Weather',
          theme: AeolusTheme.light(),
          darkTheme: AeolusTheme.dark(),
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
