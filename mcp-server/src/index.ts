#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { ArchiveCache } from "./cache.js";
import { startHttpServer } from "./httpServer.js";
import { createMcpServer } from "./server.js";

async function runStdio(): Promise<void> {
  const archiveCache = new ArchiveCache();
  const server = createMcpServer(archiveCache);
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

// Render (and most PaaS conventions) set PORT to indicate "run as an HTTP
// service" -- used here to select the transport without a separate CLI
// flag or entrypoint file, so `node dist/index.js` works unchanged both
// for local stdio usage (Claude Code/Desktop spawning it directly) and a
// Render deployment.
const port = process.env.PORT;
if (port) {
  startHttpServer(Number(port));
} else {
  runStdio().catch((err) => {
    console.error("Fatal error starting historical-weather MCP server:", err);
    process.exit(1);
  });
}
