import { afterEach, expect, it, vi } from "vitest";
import { SELF, abortAllDurableObjects } from "cloudflare:test";
import { token, mockGitHub } from "../helpers";
import { fetchJson } from "../../src/http";

afterEach(() => {
  vi.unstubAllGlobals();
});

it("uses native Workers Request options and never follows a provider redirect", async () => {
  for (const url of [
    "https://api.github.com/repos/team/orchard",
    "https://generativelanguage.googleapis.com/v1beta/models/fixture:generateContent",
  ]) {
    const outbound = vi.fn<typeof fetch>(async (input, init) => {
      const request = new Request(input, init);
      expect(request.redirect).toBe("manual");
      return new Response(null, {
        status: 302,
        headers: { Location: "https://untrusted.invalid/collect" },
      });
    });
    const result = await fetchJson(
      url,
      { headers: { "x-goog-api-key": "fixture-only" } },
      1000,
      1000,
      outbound,
    );
    expect(result.status).toBe(302);
    expect(result.body).toBeNull();
    expect(outbound).toHaveBeenCalledTimes(1);
  }
});

it("runs health, CORS and authentication in the real Workers runtime", async () => {
  expect((await SELF.fetch("https://worker/health")).status).toBe(200);
  expect(
    (
      await SELF.fetch("https://worker/v1/analyze", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      })
    ).status,
  ).toBe(401);
  const cors = await SELF.fetch("https://worker/v1/analyze", {
    method: "OPTIONS",
    headers: { Origin: "http://localhost:8086" },
  });
  expect(cors.status).toBe(204);
  expect(cors.headers.get("Access-Control-Allow-Origin")).toBe(
    "http://localhost:8086",
  );
});

it("uses the actual SQLite Durable Object and caches a validated snapshot", async () => {
  // Construct a native Request before returning the fixture so unsupported
  // Workers fetch options cannot be hidden by the network mock.
  const outbound = vi.fn<typeof fetch>(async (url, init) =>
    mockGitHub(new Request(url, init)),
  );
  vi.stubGlobal("fetch", outbound);
  const analyze = () =>
    SELF.fetch("https://worker/v1/analyze", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        schemaVersion: 1,
        url: "https://github.com/team/orchard",
        ai: false,
      }),
    });
  const first = await analyze();
  expect(first.status).toBe(200);
  const body = await first.json();
  expect(body).toHaveProperty("repository", "team/orchard");
  expect(outbound).toHaveBeenCalledTimes(7);
  await abortAllDurableObjects();
  expect(await (await analyze()).json()).toEqual(body);
  expect(outbound).toHaveBeenCalledTimes(9);
});
