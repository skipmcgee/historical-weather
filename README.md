# Aeolus — Historical Weather

A Flutter app for looking up **historical weather patterns**: pick a location and a
date range, and it asks [Open-Meteo](https://open-meteo.com/) for the daily archive and
reports the aggregated conditions over that period — both in the UI and as
copy-pasteable JSON. Named after Aeolus, the Greek keeper of the winds, with a
matching visual identity (stormy indigo/gold theme, an animated wind-spiral
background, custom app icons).

Targets **web**, **macOS**, **iOS**, and **Linux** from a single codebase. A companion
[MCP server](mcp-server/) exposes the same lookup as tools for LLM clients (Claude
Code, Claude Desktop, etc.) — see [mcp-server/README.md](mcp-server/README.md).

## Features

- **Location** — search by name (Open-Meteo geocoding, live as you type, debounced) or
  enter exact latitude/longitude.
- **Date range** — any range back to 1940 (the floor of Open-Meteo's ERA5 archive). A note
  in the UI explains that Open-Meteo moved to a higher-resolution model in 2017, so older
  years use a coarser data source; ranges longer than ~20 years get a heads-up that
  Open-Meteo can be slow or occasionally time out for very large requests.
- **Median or average** — per-metric aggregation defaults to median (a handful of extreme
  days can't skew it the way they would a mean), with average available as an alternative.
  Totals (precipitation, snowfall, evapotranspiration) are always sums and wind direction is
  always a circular mean, regardless of this choice — a plain numeric average of compass
  degrees is meaningless (350° and 10° should average to ~0°, not 180°).
- **Metric or imperial units** — converted only at display/export time; doesn't affect what's
  fetched or cached, so switching is instant.
- **Results** — temperature (high/low/mean), precipitation, snowfall, relative humidity, dew
  point, cloud cover, surface pressure, wind (speed/gusts/direction), sunshine, solar
  radiation, evapotranspiration, and soil moisture/temperature at three depths (0–7cm,
  7–28cm, 28–100cm) — shown as readable cards grouped by category, and as a
  copy-to-clipboard JSON panel with the exact same figures plus explicit units.
- **Settings** — an optional Open-Meteo commercial API key (for higher rate limits), a
  default location override, a light/dark/system theme toggle, and default aggregation
  method / unit system. These are one-time preferences set in Settings rather than
  per-query controls on the home screen, by design.
- **Device location** — if no default location override is set, the app makes a best-effort
  attempt to prefill your current location on launch (silently skipped if permission is
  denied — this is a convenience, not a requirement).
- **Local caching** — an exact repeat, or a narrower range fully contained within one already
  fetched, is served from a local cache instead of re-fetched; entries expire after 30 days
  or once there are more than 50, whichever comes first.

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

## Project layout

```text
lib/
  models/      Location, WeatherSummary, AggregationMethod, UnitSystem, AppSettings
  services/    OpenMeteoService (geocoding + archive fetch), weather_aggregator
               (median/average/circular-mean), ArchiveCacheService, SettingsService,
               DeviceLocationService
  screens/     HomeScreen, SettingsScreen
  widgets/     LocationPicker, DateRangePicker, WeatherSummaryView, JsonOutputPanel,
               AeolusScaffold/AeolusBackground/GlassCard (shared visual theme)
  theme/       AeolusTheme (color palette, typography, component themes)
test/          Mirrors lib/ 1:1 for the pure Dart logic (aggregator, units, settings,
               cache), plus widget tests for HomeScreen/SettingsScreen
mcp-server/    Standalone TypeScript MCP server -- see its own README
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

`.github/workflows/mcp-server.yml` is a separate, path-filtered pipeline
(`mcp-server/**` only) for the MCP server: `npm ci`, build, test on Node 24.

`.github/dependabot.yml` opens a weekly pull request for outdated pub packages, npm
packages (in `mcp-server/`), and GitHub Actions versions. A `dependabot-merge` job in
`release.yml` auto-approves and squash-merges Dependabot's patch/minor updates once every
build job passes; major version bumps are left as regular PRs for manual review, since
those are more likely to carry breaking changes that compile/test cleanly but behave
differently at runtime.

## MCP server

[`mcp-server/`](mcp-server/) is a standalone TypeScript reimplementation of this app's
domain logic — not a wrapper around the Flutter app, since MCP's official SDKs don't cover
Dart — exposing the same location search and historical-weather lookup as `search_locations`
and `get_historical_weather` tools for LLM clients. Same median/average and metric/imperial
options, same 1940-01-01 floor, same JSON output shape as this app's copy-paste panel, plus
its own in-memory response cache. See [mcp-server/README.md](mcp-server/README.md) for setup
(Claude Code, Claude Desktop), tool docs, and current hosting status.
