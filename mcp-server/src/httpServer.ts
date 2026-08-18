import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";

import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";

import { checkBearerToken } from "./auth.js";
import { ArchiveCache } from "./cache.js";
import { createMcpServer } from "./server.js";

const MCP_PATH = "/mcp";
const HEALTH_PATH = "/healthz";

// MCP tool-call payloads are small; this is generous headroom while still
// bounding how much an (authenticated) caller can force this process to
// buffer in memory per request.
const MAX_BODY_BYTES = 1_000_000;

class BodyTooLargeError extends Error {}
class InvalidJsonError extends Error {}

function readJsonBody(req: IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    let tooLarge = false;
    req.on("data", (chunk: Buffer) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        // Don't destroy the socket here -- that would tear down the
        // connection before the 413 response below can be written back on
        // it. Just stop buffering (so an oversized body can't grow memory
        // unbounded) and keep draining the rest of what the client sends,
        // so the socket is left in a clean state for that response.
        if (!tooLarge) {
          tooLarge = true;
          reject(new BodyTooLargeError(`Request body exceeds ${MAX_BODY_BYTES} bytes`));
        }
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8");
      if (!raw) {
        resolve(undefined);
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new InvalidJsonError("Request body is not valid JSON"));
      }
    });
    req.on("error", reject);
  });
}

/** Discards any unread request body so the underlying socket is left in a
 * clean state for the next request on a keep-alive connection -- matters
 * for the early-return paths below (health check, 404, 401) that respond
 * without ever consuming the body. */
function drain(req: IncomingMessage): void {
  req.resume();
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
 *
 * Returns the underlying http.Server -- index.ts doesn't need it (the
 * process just keeps running), but tests do, to close it down cleanly
 * between cases instead of leaking a listening socket per test.
 */
export function startHttpServer(port: number): Server {
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
    res.on("error", (err) => console.error("Response stream error:", err));
    handleRequest(req, res, authToken, archiveCache).catch((err: unknown) => {
      // handleRequest already catches everything it can turn into a proper
      // HTTP response; this is the last-resort backstop so a truly
      // unexpected throw (e.g. from URL parsing, before the inner try
      // block) can't become an unhandled rejection that crashes the whole
      // process for every other in-flight request.
      console.error("Unhandled error handling MCP request:", err);
      if (!res.headersSent) {
        sendJson(res, 500, { error: "Internal server error" });
      } else {
        res.destroy();
      }
    });
  });

  httpServer.on("error", (err) => {
    console.error("HTTP server error:", err);
  });

  httpServer.listen(port, () => {
    console.error(`historical-weather MCP server listening on :${port} (HTTP, ${MCP_PATH})`);
  });

  return httpServer;
}

async function handleRequest(
  req: IncomingMessage,
  res: ServerResponse,
  authToken: string,
  archiveCache: ArchiveCache,
): Promise<void> {
  try {
    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);

    if (url.pathname === HEALTH_PATH) {
      drain(req);
      sendJson(res, 200, { status: "ok" });
      return;
    }

    if (url.pathname !== MCP_PATH) {
      drain(req);
      sendJson(res, 404, { error: "Not found" });
      return;
    }

    if (!checkBearerToken(req.headers.authorization, authToken)) {
      drain(req);
      sendJson(res, 401, { error: "Unauthorized" });
      return;
    }

    let parsedBody: unknown;
    if (req.method === "POST") {
      try {
        parsedBody = await readJsonBody(req);
      } catch (err) {
        if (err instanceof BodyTooLargeError) {
          sendJson(res, 413, { error: "Request body too large" });
        } else if (err instanceof InvalidJsonError) {
          sendJson(res, 400, { error: "Request body is not valid JSON" });
        } else {
          throw err;
        }
        return;
      }
    }

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
    await transport.handleRequest(req, res, parsedBody);
  } catch (err) {
    console.error("Error handling MCP request:", err);
    if (!res.headersSent) {
      sendJson(res, 500, { error: "Internal server error" });
    } else {
      res.destroy();
    }
  }
}
