# Historical Weather MCP Server

An MCP server exposing the same historical-weather lookup as the [Historical
Weather Flutter app](../README.md) — Open-Meteo geocoding + archive, median/average
aggregation, metric/imperial units — as tools an LLM client (Claude Desktop, Claude
Code, etc.) can call directly. This is a standalone TypeScript reimplementation of the
app's domain logic (`lib/services/open_meteo_service.dart`,
`lib/services/weather_aggregator.dart`, `lib/models/*.dart`), not a wrapper around the
Flutter app — MCP's official SDKs don't cover Dart.

## Tools

### `search_locations`

Search Open-Meteo's geocoding database for places matching a free-text query. Returns
candidate matches (name, admin1, country, latitude, longitude, timezone) to disambiguate
before calling `get_historical_weather`.

### `get_historical_weather`

Looks up historical weather for a location and date range, aggregated into a single
summary. Returns the same JSON shape as the Flutter app's copy-paste JSON panel.

| Param | Type | Default | Notes |
|---|---|---|---|
| `location` | string | — | Free-text place name, resolved via geocoding to the best match. Omit if `latitude`/`longitude` are given. |
| `latitude`, `longitude` | number | — | Explicit coordinates. Required if `location` is omitted. |
| `start_date`, `end_date` | string (`YYYY-MM-DD`) | — | `start_date` must be on/after `1940-01-01`; `end_date` can't be in the future. |
| `method` | `"median" \| "average"` | `"median"` | Median resists a few extreme days skewing the result; average is the literal mean. Totals (precipitation/snowfall/ET0) are always sums; wind direction is always a circular mean — neither is affected by this choice. |
| `units` | `"metric" \| "imperial"` | `"imperial"` | Converted only at output time; doesn't affect what's fetched or cached. |

A date range longer than ~20 years adds a non-fatal `warning` field to the response,
noting that Open-Meteo can be slow (or occasionally time out) for very large requests —
mirrors the app's own heads-up for long ranges.

## Setup

Requires Node.js 18+.

```bash
npm install
npm run build
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "historical-weather": {
      "command": "node",
      "args": ["/absolute/path/to/mcp-server/dist/index.js"]
    }
  }
}
```

### Optional: Open-Meteo commercial API key

Set `OPEN_METEO_API_KEY` in the server's environment (e.g. in the `env` block of the
Claude Desktop config above) to use a commercial Open-Meteo plan. This switches requests
to the `customer-` prefixed hosts and adds the `apikey` query parameter — same behavior
as the Flutter app's Settings API key field. Without it, the free public API is used.

## Development

```bash
npm test         # run the test suite once
npm run test:watch
npm run dev       # tsc --watch
```

Manual protocol-level verification (no Claude Desktop needed) — requires Node 22+ for
the inspector itself, separate from the server's own Node 18+ requirement:

```bash
npx @modelcontextprotocol/inspector node dist/index.js
```
