import type { Server } from "node:http";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { startHttpServer } from "../src/httpServer.js";

const AUTH_TOKEN = "test-token-12345";

async function startTestServer(): Promise<{ server: Server; baseUrl: string }> {
  const server = startHttpServer(0);
  await new Promise<void>((resolve) => server.once("listening", resolve));
  const address = server.address();
  const port = typeof address === "object" && address ? address.port : 0;
  return { server, baseUrl: `http://127.0.0.1:${port}` };
}

function closeServer(server: Server): Promise<void> {
  return new Promise((resolve) => server.close(() => resolve()));
}

describe("startHttpServer", () => {
  it("refuses to start without MCP_AUTH_TOKEN set", () => {
    delete process.env.MCP_AUTH_TOKEN;
    expect(() => startHttpServer(0)).toThrow(/MCP_AUTH_TOKEN/);
  });

  describe("with a running server", () => {
    let server: Server;
    let baseUrl: string;

    beforeEach(async () => {
      process.env.MCP_AUTH_TOKEN = AUTH_TOKEN;
      ({ server, baseUrl } = await startTestServer());
    });

    afterEach(async () => {
      delete process.env.MCP_AUTH_TOKEN;
      await closeServer(server);
    });

    it("responds to /healthz without auth", async () => {
      const res = await fetch(`${baseUrl}/healthz`);
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ status: "ok" });
    });

    it("404s on an unknown path", async () => {
      const res = await fetch(`${baseUrl}/nonexistent`);
      expect(res.status).toBe(404);
    });

    it("401s on /mcp with no Authorization header", async () => {
      const res = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }),
      });
      expect(res.status).toBe(401);
    });

    it("401s on /mcp with the wrong bearer token", async () => {
      const res = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: {
          Authorization: "Bearer wrong-token",
          "Content-Type": "application/json",
          Accept: "application/json, text/event-stream",
        },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }),
      });
      expect(res.status).toBe(401);
    });

    it("400s on a malformed JSON body with the correct token", async () => {
      const res = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${AUTH_TOKEN}`,
          "Content-Type": "application/json",
          Accept: "application/json, text/event-stream",
        },
        body: "{not valid json",
      });
      expect(res.status).toBe(400);
    });

    it("413s on an oversized body", async () => {
      const res = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${AUTH_TOKEN}`,
          "Content-Type": "application/json",
          Accept: "application/json, text/event-stream",
        },
        body: "x".repeat(1_000_001),
      });
      expect(res.status).toBe(413);
    });

    it("reaches the MCP transport and completes an initialize handshake with the correct token", async () => {
      const res = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${AUTH_TOKEN}`,
          "Content-Type": "application/json",
          Accept: "application/json, text/event-stream",
        },
        body: JSON.stringify({
          jsonrpc: "2.0",
          id: 1,
          method: "initialize",
          params: {
            protocolVersion: "2025-06-18",
            capabilities: {},
            clientInfo: { name: "test", version: "0.0.1" },
          },
        }),
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { result?: { serverInfo?: { name?: string } } };
      expect(body.result?.serverInfo?.name).toBe("historical-weather");
    });
  });
});
