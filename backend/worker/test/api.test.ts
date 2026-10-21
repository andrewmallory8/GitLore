import { afterEach, expect, it, vi } from "vitest";
import worker from "../src/index";
import { AnalysisCoordinator } from "../src/coordinator";
import type { Env } from "../src/contracts";
import { mockGitHub, MemoryStorage, token, aiBody } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
});
function environment() {
  const storage = new MemoryStorage();
  const env = {
    TEAM_ACCESS_TOKEN: token,
    ALLOWED_ORIGINS: "https://app.example",
    GEMINI_API_KEY: "",
    GEMINI_MODEL: "gemini-fixture",
  } as Env;
  let coordinator = new AnalysisCoordinator(
    { storage: storage.asStorage() } as DurableObjectState,
    env,
  );
  env.ANALYSES = {
    idFromName: () => "fixture",
    get: () => ({ fetch: (r: Request) => coordinator.fetch(r) }),
  } as unknown as DurableObjectNamespace;
  return {
    env,
    storage,
    restart: () => {
      coordinator = new AnalysisCoordinator(
        { storage: storage.asStorage() } as DurableObjectState,
        env,
      );
    },
  };
}
function request(
  body: unknown = {
    schemaVersion: 1,
    url: "https://github.com/team/orchard",
    ai: false,
  },
  headers: Record<string, string> = {},
) {
  return new Request("https://api.example/v1/analyze", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...headers,
    },
    body: JSON.stringify(body),
  });
}
it("fetches a commit-pinned result and reuses snapshots across coordinator recreation", async () => {
  const { env, restart } = environment();
  const fetcher = vi.fn<typeof fetch>(async (url) => mockGitHub(url));
  vi.stubGlobal("fetch", fetcher);
  const response = await worker.fetch(request(), env),
    first = await response.json();
  expect(response.status).toBe(200);
  expect(first).toHaveProperty("schemaVersion", 1);
  expect(fetcher).toHaveBeenCalledTimes(7);
  expect(fetcher.mock.calls[1][0]).toContain("feature%2Fmain");
  restart();
  const second = await worker.fetch(request(), env);
  expect(await second.json()).toEqual(first);
  expect(fetcher).toHaveBeenCalledTimes(9); // Metadata and current commit are always rechecked.
});
it("rejects invalid auth, schema, content type, origin and URLs before crawling", async () => {
  const { env } = environment(),
    fetcher = vi.fn<typeof fetch>();
  vi.stubGlobal("fetch", fetcher);
  expect(
    (
      await worker.fetch(
        request(undefined, { Authorization: "Bearer wrong" }),
        env,
      )
    ).status,
  ).toBe(401);
  expect(
    (
      await worker.fetch(
        request(undefined, { Origin: "https://evil.example" }),
        env,
      )
    ).status,
  ).toBe(403);
  expect(
    (
      await worker.fetch(
        request({ schemaVersion: 2, url: "https://github.com/team/orchard" }),
        env,
      )
    ).status,
  ).toBe(400);
  expect(
    (
      await worker.fetch(
        request({ schemaVersion: 1, url: "http://169.254.169.254/" }),
        env,
      )
    ).status,
  ).toBe(400);
  expect(
    (
      await worker.fetch(
        request(undefined, { "Content-Type": "text/plain" }),
        env,
      )
    ).status,
  ).toBe(415);
  expect(
    (
      await worker.fetch(
        request({ schemaVersion: 1, url: "x".repeat(5000) }),
        env,
      )
    ).status,
  ).toBe(413);
  expect(fetcher).not.toHaveBeenCalled();
});
it("supports browser preflight and fails closed without team credentials", async () => {
  const { env } = environment();
  const response = await worker.fetch(
    new Request("https://api.example/v1/analyze", {
      method: "OPTIONS",
      headers: { Origin: "https://app.example" },
    }),
    env,
  );
  expect(response.status).toBe(204);
  expect(response.headers.get("Access-Control-Allow-Origin")).toBe(
    "https://app.example",
  );
  env.TEAM_ACCESS_TOKEN = "";
  expect((await worker.fetch(request(), env)).status).toBe(503);
});
it("returns static results without a Gemini key and does not cache AI failures", async () => {
  const { env } = environment();
  const fetcher = vi.fn<typeof fetch>(async (url) => mockGitHub(url));
  vi.stubGlobal("fetch", fetcher);
  const response = await worker.fetch(
    request({
      schemaVersion: 1,
      url: "https://github.com/team/orchard",
      ai: true,
    }),
    env,
  );
  expect(await response.json()).toHaveProperty("analysisKind", "static");
  const before = fetcher.mock.calls.length;
  await worker.fetch(
    request({
      schemaVersion: 1,
      url: "https://github.com/team/orchard",
      ai: true,
    }),
    env,
  );
  expect(fetcher.mock.calls.length - before).toBe(7);
});
it("reuses a validated AI result without another Gemini request", async () => {
  const { env } = environment();
  env.GEMINI_API_KEY = "fixture-secret";
  const provider = vi.fn(async () => Response.json(aiBody()));
  vi.stubGlobal("fetch", async (url: string | URL | Request) =>
    String(url).includes("generativelanguage.googleapis.com")
      ? provider()
      : mockGitHub(url),
  );
  const input = {
    schemaVersion: 1,
    url: "https://github.com/team/orchard",
    ai: true,
  };
  expect(await (await worker.fetch(request(input), env)).json()).toHaveProperty(
    "analysisKind",
    "ai",
  );
  expect(await (await worker.fetch(request(input), env)).json()).toHaveProperty(
    "analysisKind",
    "ai",
  );
  expect(provider).toHaveBeenCalledTimes(1);
});
it("coalesces overlapping requests for the same repository", async () => {
  const { env } = environment();
  const fetcher = vi.fn<typeof fetch>(async (url) => {
    await new Promise((r) => setTimeout(r, 5));
    return mockGitHub(url);
  });
  vi.stubGlobal("fetch", fetcher);
  const responses = await Promise.all([
    worker.fetch(request(), env),
    worker.fetch(request(), env),
  ]);
  expect(responses.every((r) => r.status === 200)).toBe(true);
  expect(fetcher).toHaveBeenCalledTimes(7);
});

it("refreshes a changed commit instead of serving the previous snapshot", async () => {
  const { env } = environment();
  let changed = false;
  const sha = "f".repeat(40);
  const fetcher = vi.fn<typeof fetch>(async (url) => {
    if (changed && String(url).includes("/commits/")) {
      const old = (await mockGitHub(url).json()) as { commit: unknown };
      return Response.json({ ...old, sha });
    }
    return mockGitHub(url);
  });
  vi.stubGlobal("fetch", fetcher);
  const first = (await (await worker.fetch(request(), env)).json()) as {
    commitSha: string;
  };
  changed = true;
  const next = await (await worker.fetch(request(), env)).json();
  expect(next).toHaveProperty("commitSha", sha);
  expect(first.commitSha).not.toBe(sha);
  expect(fetcher).toHaveBeenCalledTimes(14);
  expect(await (await worker.fetch(request(), env)).json()).toEqual(next);
  expect(fetcher).toHaveBeenCalledTimes(16);
});

it("rejects a third distinct job while two jobs are waiting on GitHub", async () => {
  const { env } = environment();
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const fetcher = vi.fn<typeof fetch>(async (url) => {
    await gate;
    return mockGitHub(url);
  });
  vi.stubGlobal("fetch", fetcher);
  const jobs = [
    worker.fetch(request(), env),
    worker.fetch(
      request({
        schemaVersion: 1,
        url: "https://github.com/team/orchard",
        ai: true,
      }),
      env,
    ),
  ];
  try {
    await vi.waitFor(() => expect(fetcher).toHaveBeenCalledTimes(2));
    const denied = await worker.fetch(
      request({
        schemaVersion: 1,
        url: "https://github.com/team/another",
        ai: false,
      }),
      env,
    );
    expect(denied.status).toBe(429);
    expect(fetcher).toHaveBeenCalledTimes(2);
  } finally {
    release();
  }
  expect((await Promise.all(jobs)).every((r) => r.status === 200)).toBe(true);
});
