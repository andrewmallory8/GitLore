import { expect, it, vi } from "vitest";
import { GitHubCrawler } from "../src/services/github";
import { fetchJson, readBytes } from "../src/http";
import { mockGitHub } from "./helpers";

it("resolves a branch to a commit and reads blobs by immutable SHA", async () => {
  const fetcher = vi.fn<typeof fetch>(async (url, init) => {
    expect(init?.headers).toHaveProperty("User-Agent", "GitLore-Worker/1");
    expect(init?.redirect).toBe("manual");
    return mockGitHub(url);
  });
  const crawler = new GitHubCrawler(fetcher),
    snapshot = await crawler.snapshot("https://github.com/team/orchard");
  const output = await crawler.crawl(snapshot);
  expect(output.files).toHaveLength(4);
  expect(output.edges).toHaveLength(1);
  expect(output.technologies).toEqual(["JavaScript", "express", "pg"]);
  expect(
    fetcher.mock.calls
      .slice(3)
      .every(([url]) => /\/git\/blobs\/[a-f0-9]{40}$/.test(String(url))),
  ).toBe(true);
});
it.each([403, 404, 409, 429, 500])(
  "translates GitHub HTTP %s without echoing upstream bodies",
  async (status) => {
    const crawler = new GitHubCrawler(
      async () => new Response("private upstream diagnostics", { status }),
    );
    await expect(
      crawler.snapshot("https://github.com/team/orchard"),
    ).rejects.not.toThrow("private upstream diagnostics");
  },
);
it("keeps metadata-only and truncated results usable", async () => {
  const crawler = new GitHubCrawler(async (url) =>
    String(url).includes("/git/trees/")
      ? Response.json({ truncated: true, tree: [] })
      : mockGitHub(url),
  );
  const result = await crawler.crawl(
    await crawler.snapshot("https://github.com/team/orchard"),
  );
  expect(result.nodes).toHaveLength(1);
  expect(result.steps).toHaveLength(1);
  expect(result.warnings.join(" ")).toContain("truncated");
});
it("enforces eight-file and actual-byte budgets even when blob sizes are understated", async () => {
  const crawler = new GitHubCrawler(async (url) => {
    if (String(url).includes("/git/trees/"))
      return Response.json({
        tree: Array.from({ length: 12 }, (_, i) => ({
          path: `src/${i}.js`,
          type: "blob",
          mode: "100644",
          size: 1,
          sha: i.toString(16).repeat(40),
        })),
      });
    if (String(url).includes("/git/blobs/"))
      return Response.json({
        encoding: "base64",
        content: btoa("x".repeat(40000)),
      });
    return mockGitHub(url);
  });
  const result = await crawler.crawl(
    await crawler.snapshot("https://github.com/team/orchard"),
  );
  expect(result.files).toHaveLength(4);
  expect(
    result.files.reduce((n, f) => n + f.content.length, 0),
  ).toBeLessThanOrEqual(180000);
  expect(result.warnings.join(" ")).toContain("content budget");
});
it("rejects oversized streamed responses and cancels further reading", async () => {
  const cancel = vi.fn();
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(11));
    },
    cancel,
  });
  await expect(readBytes(new Response(stream), 10)).rejects.toThrow(
    "safe size limit",
  );
  expect(cancel).toHaveBeenCalled();
});
it("aborts the upstream transport at its deadline", async () => {
  const fetcher: typeof fetch = async (_, init) =>
    new Promise((_, reject) => {
      init?.signal?.addEventListener(
        "abort",
        () => reject(new Error("aborted")),
        { once: true },
      );
    });
  await expect(
    fetchJson("https://api.github.com/fixture", {}, 100, 5, fetcher),
  ).rejects.toMatchObject({ status: 504, code: "upstream_timeout" });
});

it("cancels a stalled incoming body at its deadline", async () => {
  const cancel = vi.fn();
  const stream = new ReadableStream<Uint8Array>({ cancel });
  await expect(readBytes(new Response(stream), 4096, 5)).rejects.toMatchObject({
    status: 408,
    code: "request_timeout",
  });
  expect(cancel).toHaveBeenCalledTimes(1);
});
