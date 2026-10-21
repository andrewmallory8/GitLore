import { expect, it, vi } from "vitest";
import { enhance } from "../src/services/gemini";
import { ApiError } from "../src/contracts";
import { aiBody, result } from "./helpers";

it.each(["gemini-3.8-flash", "gemini-2.5-flash"])(
  "uses a supported reasoning configuration for %s",
  async (model) => {
    const output = await enhance(result(), {
      apiKey: "fixture",
      model,
      reserve: async () => true,
      fetcher: async (_url, init) => {
        const config = JSON.parse(String(init?.body)).generationConfig;
        expect(config.thinkingConfig).toEqual(
          model.startsWith("gemini-3") ? { thinkingLevel: "low" } : undefined,
        );
        expect(config.maxOutputTokens).toBe(4096);
        return Response.json(aiBody());
      },
    });
    expect(output.analysisKind).toBe("ai");
    expect(output.analysisVersion).toBe("worker-story-v2");
  },
);

it("reports incomplete generation without exposing provider details", async () => {
  const output = await enhance(result(), {
    apiKey: "fixture",
    model: "gemini-fixture",
    reserve: async () => true,
    fetcher: async () =>
      Response.json({
        candidates: [
          {
            finishReason: "MAX_TOKENS",
            content: { parts: [{ text: "private incomplete text" }] },
          },
        ],
      }),
  });
  expect(output.analysisKind).toBe("static");
  expect(output.warnings.at(-1)).toContain("incomplete explanation");
  expect(JSON.stringify(output)).not.toContain("private incomplete text");
});

it("distinguishes the provider deadline from evidence validation", async () => {
  const output = await enhance(result(), {
    apiKey: "fixture",
    model: "gemini-fixture",
    reserve: async () => true,
    fetcher: async () => {
      throw new ApiError(504, "upstream_timeout", "private diagnostic");
    },
  });
  expect(output.warnings.at(-1)).toContain("server time limit");
  expect(JSON.stringify(output)).not.toContain("private diagnostic");
});

it("returns evidence-backed chapters and sends credentials only as a header", async () => {
  const fetcher = vi.fn<typeof fetch>(async (url, init) => {
    expect(String(url)).not.toContain("fixture-secret");
    expect(new Headers(init?.headers).get("x-goog-api-key")).toBe(
      "fixture-secret",
    );
    expect(init?.body).not.toContain("fixture-secret");
    expect(init?.redirect).toBe("manual");
    expect(
      JSON.parse(String(init?.body)).generationConfig.responseSchema,
    ).toHaveProperty("properties.chapters");
    return Response.json(aiBody());
  });
  const reserve = vi.fn(async () => true);
  const output = await enhance(result(), {
    apiKey: "fixture-secret",
    model: "gemini-fixture",
    reserve,
    fetcher,
  });
  expect(output.analysisKind).toBe("ai");
  expect(output.steps[0].evidence[0].startLine).toBe(1);
  expect(reserve).toHaveBeenCalledWith(false);
});
it("retries a transient error once, reserving quota for both attempts", async () => {
  const fetcher = vi
    .fn<typeof fetch>()
    .mockResolvedValueOnce(
      new Response("private diagnostic", {
        status: 503,
        headers: { "Retry-After": "1" },
      }),
    )
    .mockResolvedValueOnce(Response.json(aiBody()));
  const reserve = vi.fn(async () => true),
    sleep = vi.fn(async () => {});
  const output = await enhance(result(), {
    apiKey: "fixture",
    model: "gemini-fixture",
    reserve,
    sleep,
    fetcher,
  });
  expect(output.analysisKind).toBe("ai");
  expect(fetcher).toHaveBeenCalledTimes(2);
  expect(reserve.mock.calls).toEqual([[false], [true]]);
  expect(sleep).toHaveBeenCalledWith(1000);
});
it.each([400, 401, 403, 404, 429, 503])(
  "falls back safely for provider HTTP %s",
  async (status) => {
    const fetcher = vi.fn<typeof fetch>(
      async () => new Response("private diagnostic fixture-secret", { status }),
    );
    const output = await enhance(result(), {
      apiKey: "fixture-secret",
      model: "gemini-fixture",
      reserve: async () => true,
      sleep: async () => {},
      fetcher,
    });
    expect(output.analysisKind).toBe("static");
    expect(output.steps).toEqual(result().steps);
    expect(JSON.stringify(output)).not.toMatch(
      /private diagnostic|fixture-secret/,
    );
    expect(fetcher).toHaveBeenCalledTimes(status === 503 ? 2 : 1);
  },
);
it("honors long Retry-After without an immediate retry", async () => {
  const fetcher = vi.fn<typeof fetch>(
    async () =>
      new Response(null, { status: 503, headers: { "Retry-After": "120" } }),
  );
  expect(
    (
      await enhance(result(), {
        apiKey: "fixture",
        model: "gemini-fixture",
        reserve: async () => true,
        fetcher,
      })
    ).analysisKind,
  ).toBe("static");
  expect(fetcher).toHaveBeenCalledTimes(1);
});
it("does not call the provider without a key or an available quota reservation", async () => {
  const fetcher = vi.fn<typeof fetch>();
  await enhance(result(), {
    apiKey: "",
    model: "gemini-fixture",
    reserve: async () => true,
    fetcher,
  });
  await enhance(result(), {
    apiKey: "fixture",
    model: "gemini-fixture",
    reserve: async () => false,
    fetcher,
  });
  expect(fetcher).not.toHaveBeenCalled();
});
it.each([
  aiBody("src/service.js", 1),
  aiBody("src/index.js", 90),
  { candidates: [] },
])(
  "rejects invalid, unrelated, or incomplete source evidence",
  async (body) => {
    const output = await enhance(result(), {
      apiKey: "fixture",
      model: "gemini-fixture",
      reserve: async () => true,
      fetcher: async () => Response.json(body),
    });
    expect(output.analysisKind).toBe("static");
    expect(output.warnings.at(-1)).toContain("evidence validation");
  },
);
