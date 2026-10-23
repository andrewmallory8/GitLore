import fixture from "./fixtures/repository.json";
import { buildAnalysis } from "../src/services/analyzer";
import type { Analysis } from "../src/contracts";
export const token = "fixture-only-token-with-at-least-32-characters";
export const result = (): Analysis =>
  buildAnalysis(fixture, fixture.files, fixture.fileCount, fixture.warnings);
export function snapshotInput() {
  const a = result();
  return {
    schemaVersion: 1,
    url: `https://github.com/${a.repository}`,
    commitSha: a.commitSha,
    branch: a.branch,
    fileCount: a.fileCount,
    files: a.files,
  };
}
export function aiBody(path = "src/index.js"): unknown {
  return {
    candidates: [
      {
        finishReason: "STOP",
        content: {
          parts: [
            {
              text: JSON.stringify({
                chapters: [
                  {
                    title: "Start",
                    body: "The entry point imports a service.",
                    sourcePath: path,
                  },
                ],
              }),
            },
          ],
        },
      },
    ],
  };
}
export function mockGitHub(url: string | URL | Request): Response {
  const u = new URL(
    typeof url === "string" ? url : url instanceof URL ? url.href : url.url,
  );
  if (u.host !== "api.github.com") throw new Error("Unexpected external host");
  if (u.pathname === "/repos/team/orchard")
    return Response.json({
      full_name: fixture.repository,
      default_branch: fixture.branch,
      description: fixture.description,
      language: fixture.language,
    });
  if (u.pathname.includes("/commits/"))
    return Response.json({
      sha: fixture.sha,
      commit: { tree: { sha: fixture.treeSha } },
    });
  if (u.pathname.includes("/git/trees/"))
    return Response.json({
      truncated: false,
      tree: fixture.files.map((f, i) => ({
        path: f.path,
        type: "blob",
        mode: "100644",
        sha: `${i}`.repeat(40),
        size: new TextEncoder().encode(f.content).length,
      })),
    });
  const f = fixture.files[Number(u.pathname.split("/").pop()![0])];
  if (!f) return Response.json({}, { status: 404 });
  return Response.json({ encoding: "base64", content: btoa(f.content) });
}
/** Deterministic storage fake with serialized transactions and copy semantics. */
export class MemoryStorage {
  data = new Map<string, unknown>();
  private queue: Promise<unknown> = Promise.resolve();
  async get<T>(key: string): Promise<T | undefined> {
    return structuredClone(this.data.get(key)) as T | undefined;
  }
  async put(key: string, value: unknown): Promise<void> {
    this.data.set(key, structuredClone(value));
  }
  async delete(key: string): Promise<boolean> {
    return this.data.delete(key);
  }
  async list<T>({ prefix = "" }: { prefix?: string } = {}): Promise<
    Map<string, T>
  > {
    return new Map(
      [...this.data]
        .filter(([k]) => k.startsWith(prefix))
        .map(([k, v]) => [k, structuredClone(v) as T]),
    );
  }
  transaction<T>(
    action: (tx: DurableObjectTransaction) => Promise<T>,
  ): Promise<T> {
    const task = this.queue.then(() =>
      action(this as unknown as DurableObjectTransaction),
    );
    this.queue = task.catch(() => {});
    return task;
  }
  asStorage(): DurableObjectStorage {
    return this as unknown as DurableObjectStorage;
  }
}
