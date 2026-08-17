import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

import { checkBearerToken } from "./auth.js";
import { ArchiveCache } from "./cache.js";
import { createMcpServer } from "./server.js";

const MCP_PATH = "/mcp";
const HEALTH_PATH = "/healthz";

function readJsonBody(req: IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", (chunk: Buffer) => chunks.push(chunk));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      if (!raw) {
        resolve(undefined);
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

/**
 * Runs the server over the MCP Streamable HTTP transport instead of stdio
 * -- for a remote deployment (e.g. Render) rather than a client spawning
 * this as a local subprocess. Selected by index.ts based on the `PORT` env
 * var being set.
 *
 * Stateless: a fresh McpServer + StreamableHTTPServerTransport pair is
 * created per request (`sessionIdGenerator: undefined`), since the
 * low-level Server only supports one connected transport at a time and
 * concurrent HTTP requests shouldn't share a session. The ArchiveCache is
 * the one thing kept at module scope across all requests -- a fresh cache
 * per request would defeat the point of caching for exactly the
 * deployment (many independent requests over time) where it matters most.
 *
 * Auth: every /mcp request must carry `Authorization: Bearer <token>`
 * matching MCP_AUTH_TOKEN (checked with a constant-time comparison, see
 * auth.ts). This is Claude's officially-supported `static_headers` auth
 * type for remote MCP connectors -- simple and sufficient for a
 * single-operator deployment, though it doesn't plug into ChatGPT's
 * connector UI, which expects OAuth. /healthz is intentionally
 * unauthenticated, for Render's own health checks.
 */
export function startHttpServer(port: number): void {
  const authToken = process.env.MCP_AUTH_TOKEN;
  if (!authToken) {
    throw new Error(
      "MCP_AUTH_TOKEN must be set to run the HTTP transport -- this exposes the server " +
        "publicly, so it refuses to start unauthenticated. Generate one however you like " +
        "(e.g. `openssl rand -hex 32`) and set it as an env var on the deployment.",
    );
  }

  const archiveCache = new ArchiveCache();

  const httpServer = createServer((req, res) => {
    void handleRequest(req, res, authToken, archiveCache);
  });

  httpServer.listen(port, () => {
    console.error(`historical-weather MCP server listening on :${port} (HTTP, ${MCP_PATH})`);
  });
}

async function handleRequest(
  req: IncomingMessage,
  res: ServerResponse,
  authToken: string,
  archiveCache: ArchiveCache,
): Promise<void> {
  const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);

  if (url.pathname === HEALTH_PATH) {
    sendJson(res, 200, { status: "ok" });
    return;
  }

  if (url.pathname !== MCP_PATH) {
    sendJson(res, 404, { error: "Not found" });
    return;
  }

  if (!checkBearerToken(req.headers.authorization, authToken)) {
    sendJson(res, 401, { error: "Unauthorized" });
    return;
  }

  try {
    const server = createMcpServer(archiveCache);
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });

    res.on("close", () => {
      void transport.close();
      void server.close();
    });

    await server.connect(transport);

    const parsedBody = req.method === "POST" ? await readJsonBody(req) : undefined;
    await transport.handleRequest(req, res, parsedBody);
  } catch (err) {
    console.error("Error handling MCP request:", err);
    if (!res.headersSent) {
      sendJson(res, 500, { error: "Internal server error" });
    }
  }
}
