import { describe, expect, it } from "vitest";
import { checkBearerToken } from "../src/auth.js";

const TOKEN = "s3cr3t-token-value";

describe("checkBearerToken", () => {
  it("accepts the correct bearer token", () => {
    expect(checkBearerToken(`Bearer ${TOKEN}`, TOKEN)).toBe(true);
  });

  it("rejects a wrong token", () => {
    expect(checkBearerToken("Bearer wrong-token", TOKEN)).toBe(false);
  });

  it("rejects a token of different length", () => {
    expect(checkBearerToken("Bearer short", TOKEN)).toBe(false);
    expect(checkBearerToken(`Bearer ${TOKEN}-and-then-some-more`, TOKEN)).toBe(false);
  });

  it("rejects a missing header", () => {
    expect(checkBearerToken(undefined, TOKEN)).toBe(false);
    expect(checkBearerToken(null, TOKEN)).toBe(false);
  });

  it("rejects a header without the Bearer prefix", () => {
    expect(checkBearerToken(TOKEN, TOKEN)).toBe(false);
    expect(checkBearerToken(`Basic ${TOKEN}`, TOKEN)).toBe(false);
  });

  it("rejects an empty header", () => {
    expect(checkBearerToken("", TOKEN)).toBe(false);
  });

  it("is case-sensitive on the token value", () => {
    expect(checkBearerToken(`Bearer ${TOKEN.toUpperCase()}`, TOKEN)).toBe(false);
  });
});
