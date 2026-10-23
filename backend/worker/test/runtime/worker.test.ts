import { afterEach, expect, it, vi } from "vitest";
import { SELF, env, abortAllDurableObjects } from "cloudflare:test";
import { token, mockGitHub, snapshotInput, aiBody } from "../helpers";
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

it("runs protected diagnostics through the real SQLite coordinator without GitHub", async () => {
  const runtimeEnv = env as unknown as { GEMINI_API_KEY: string };
  const previous = runtimeEnv.GEMINI_API_KEY;
  runtimeEnv.GEMINI_API_KEY = "fixture-only";
  const outbound = vi.fn<typeof fetch>(async (url, init) => {
    const request = new Request(url, init);
    expect(request.url).toContain("generativelanguage.googleapis.com");
    return Response.json({
      candidates: [
        { finishReason: "STOP", content: { parts: [{ text: "OK" }] } },
      ],
    });
  });
  vi.stubGlobal("fetch", outbound);
  try {
    const response = await SELF.fetch("https://worker/v1/diagnostics/gemini", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: '{"schemaVersion":1}',
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      outcome: "ok",
      providerStatus: 200,
    });
    expect(outbound).toHaveBeenCalledTimes(1);
  } finally {
    runtimeEnv.GEMINI_API_KEY = previous;
  }
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

it("validates uploaded source and returns an AI overview through actual SQLite without GitHub", async () => {
  // The runtime tests share the singleton's real persisted cooldown. Advance
  // test time instead of resetting its quota state or waiting on a wall clock.
  const clock = vi.spyOn(Date, "now").mockReturnValue(Date.now() + 16000);
  const runtimeEnv = env as unknown as { GEMINI_API_KEY: string };
  const previous = runtimeEnv.GEMINI_API_KEY;
  runtimeEnv.GEMINI_API_KEY = "fixture-only";
  const outbound = vi.fn<typeof fetch>(async (url, init) => {
    expect(new Request(url, init).url).toContain(
      "generativelanguage.googleapis.com",
    );
    return Response.json(aiBody());
  });
  vi.stubGlobal("fetch", outbound);
  try {
    const response = await SELF.fetch("https://worker/v1/explain-snapshot", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(snapshotInput()),
    });
    expect(response.status).toBe(200);
    const body = (await response.json()) as {
      analysisKind: string;
      summary: string;
      warnings: string[];
    };
    expect(body.analysisKind, JSON.stringify(body.warnings)).toBe("ai");
    expect(body.summary).toBe("The entry point imports a service.");
    expect(outbound).toHaveBeenCalledTimes(1);
  } finally {
    runtimeEnv.GEMINI_API_KEY = previous;
    clock.mockRestore();
  }
});
