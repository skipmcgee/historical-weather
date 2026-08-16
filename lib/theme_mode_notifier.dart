import 'package:flutter/material.dart';

/// App-wide theme mode, seeded from saved settings in `main()` and updated
/// live from the Settings screen.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);
