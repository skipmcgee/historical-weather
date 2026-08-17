# Historical Weather MCP Server

An MCP server exposing the same historical-weather lookup as the [Historical
Weather Flutter app](../README.md) — Open-Meteo geocoding + archive, median/average
aggregation, metric/imperial units — as tools an LLM client (Claude Code, Claude
Desktop, etc.) can call directly. This is a standalone TypeScript reimplementation of the
app's domain logic (`lib/services/open_meteo_service.dart`,
`lib/services/weather_aggregator.dart`, `lib/models/*.dart`), not a wrapper around the
Flutter app — MCP's official SDKs don't cover Dart.

Runs locally over stdio (a client spawns it as a subprocess) — see [Hosting](#hosting)
for the current status of running it as a remote/network-accessible service instead.

## Quick start

Requires Node.js 18+.

```bash
npm install
npm run build
npm test        # optional, but confirms everything's working: 25 tests
```

That produces `dist/index.js`, a self-contained entrypoint. It isn't meant to be run
directly by hand — an MCP client spawns it (see below) — but `npm start` (i.e.
`node dist/index.js`) is useful to sanity-check it launches without errors (it'll sit
waiting for stdio input; `Ctrl+C` to exit).

## Connecting a client

### Claude Code

```bash
claude mcp add historical-weather -- node /absolute/path/to/mcp-server/dist/index.js
```

With the optional API key (see below):

```bash
claude mcp add historical-weather --env OPEN_METEO_API_KEY=your-key-here -- node /absolute/path/to/mcp-server/dist/index.js
```

Or add a project-level `.mcp.json` at the repo root instead of using the CLI:

```json
{
  "mcpServers": {
    "historical-weather": {
      "type": "stdio",
      "command": "node",
      "args": ["/absolute/path/to/mcp-server/dist/index.js"],
      "env": { "OPEN_METEO_API_KEY": "your-key-here" }
    }
  }
}
```

Verify it connected: `claude mcp list` from a shell, or `/mcp` inside a Claude Code
session — both show each configured server's connection status.

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

Restart Claude Desktop after editing the config for it to pick up the new server.

### Optional: Open-Meteo commercial API key

Set `OPEN_METEO_API_KEY` in the server's environment (however the client above passes
env vars) to use a commercial Open-Meteo plan. This switches requests to the
`customer-` prefixed hosts and adds the `apikey` query parameter — same behavior as the
Flutter app's Settings API key field. Without it, the free public API is used.

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

## Caching

Archive responses are cached in memory (`src/cache.ts`) for the life of the server
process, keyed by location + date range: an exact repeat, or a narrower range fully
contained within one already fetched, is served instantly with no network call. Entries
expire after 30 days or once there are more than 50, whichever comes first. Resets on
restart — there's no persistence, which is fine for a process a client keeps running
locally. Mirrors `lib/services/archive_cache_service.dart` in the Flutter app, minus the
persistence (which exists there to survive between app launches; not a concern for a
long-running local server process).

## Hosting

Today: **local only.** The server implements the stdio transport, meaning a client
spawns `node dist/index.js` as a subprocess on the same machine (see above) — this is
how most MCP servers run today, and requires no deployment or auth of its own.

**Remote/network hosting is not yet supported.** Running this as a persistent service
other machines connect to would need the Streamable HTTP transport added, plus an auth
story (a bare unauthenticated public endpoint proxying to Open-Meteo is asking for
abuse) and a place to actually run it. That's a real architecture decision, not a docs
gap — planned as a follow-up, not yet built.

## Development

```bash
npm test         # run the test suite once
npm run test:watch
npm run dev       # tsc --watch
```

Manual protocol-level verification (no Claude Code/Desktop needed) — requires Node 22+
for the inspector itself, separate from the server's own Node 18+ requirement:

```bash
npx @modelcontextprotocol/inspector node dist/index.js
```

## Troubleshooting

- **Client shows the server as failed/disconnected**: almost always a stale or relative
  path in the config — `args` must be an *absolute* path to `dist/index.js`, and that
  file must exist (`npm run build` first; the config points at the build output, not
  `src/`).
- **Changes to `src/` don't show up**: rebuild (`npm run build`) and restart the client
  (or the server subprocess, if your client supports that) — it runs the compiled
  `dist/`, not `src/` directly.
- **"command not found" / wrong Node**: the client needs `node` on its `PATH`, and it
  needs to be Node 18+; if you manage Node versions per-shell (nvm, etc.), the client's
  own process may not inherit that — using an absolute path to the `node` binary in the
  config's `command` field sidesteps this.
- **`OPEN_METEO_API_KEY` doesn't seem to apply**: confirm it's in the *server's*
  environment (the config's `env` block / `--env` flag), not just your shell — MCP
  clients don't forward their own environment to spawned servers by default.
