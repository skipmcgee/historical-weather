# Aeolus — Historical Weather

A Flutter app for looking up **historical weather patterns**: pick a location and a
date range, and it asks [Open-Meteo](https://open-meteo.com/) for the daily archive
and reports the median conditions over that period — both in the UI and as
copy-pasteable JSON. Named after Aeolus, the Greek keeper of the winds.

Targets **web**, **macOS**, **iOS**, and **Linux** from a single codebase.

## Features

- **Location** — search by name (Open-Meteo geocoding) or enter exact latitude/longitude.
- **Date range** — any range back to 1940 (the floor of Open-Meteo's ERA5 archive). A note
  in the UI explains that Open-Meteo moved to a higher-resolution model in 2017, so older
  years use a coarser data source.
- **Results** — median high/low/mean temperature, total precipitation, median wind
  speed/gusts, median sunshine, etc., shown as readable cards and as a copy-to-clipboard
  JSON panel with the exact same figures.
- **Settings** — an optional Open-Meteo commercial API key (for higher rate limits), a
  default location override, and a light/dark/system theme toggle.
- **Device location** — if no default override is set, the app makes a best-effort attempt
  to prefill your current location on launch (silently skipped if permission is denied).

## Development

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).

```bash
flutter pub get
flutter analyze
flutter test

flutter run -d chrome   # web
flutter run -d macos    # macOS
flutter run -d linux    # Linux desktop
```

## CI/CD

`.github/workflows/release.yml` runs `flutter analyze` + `flutter test` on every push and
pull request, then (if that passes) builds release artifacts for web, macOS, iOS, and Linux.
Every run uploads those as downloadable workflow artifacts (Actions tab → the run →
Artifacts); pushing a `v*.*.*` tag additionally attaches them to a GitHub Release.

Notes on the build artifacts:

- **Linux** and **macOS** produce directly runnable apps. The macOS build is unsigned (no
  Apple Developer certificate is configured), so Gatekeeper will block the first launch until
  you right-click → Open.
- **Web** is a static site — unzip it and serve the folder over HTTP (e.g.
  `python3 -m http.server`); opening `index.html` directly won't work.
- **iOS** is currently built unsigned for a real device, so it won't launch anywhere as-is.
  Testing it needs either a Simulator build (`flutter build ios --simulator`) or real Apple
  signing credentials wired up as repo secrets.

`.github/dependabot.yml` opens a weekly pull request for outdated pub packages and GitHub
Actions versions, which runs through the same CI gate automatically.
