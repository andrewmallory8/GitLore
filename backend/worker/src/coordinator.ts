import {
  ApiError,
  parseRequest,
  parseDiagnosticRequest,
  validateAnalysis,
  type AnalyzeRequest,
  type Env,
} from "./contracts";
import { failure, json } from "./http";
import { SnapshotCache, digest, reserve } from "./limits";
import { ANALYSIS_VERSION } from "./services/analyzer";
import { GitHubCrawler } from "./services/github";
import { enhance, PROMPT_VERSION, DEFAULT_MODEL } from "./services/gemini";
import { diagnoseGemini } from "./diagnostics";

/** One SQLite-backed object coordinates this small team's workload and quotas. */
export class AnalysisCoordinator {
  private pending = new Map<string, Promise<string>>();
  private active = 0;
  private cache: SnapshotCache;
  constructor(
    private state: DurableObjectState,
    private env: Env,
  ) {
    this.cache = new SnapshotCache(state.storage);
  }

  async fetch(request: Request): Promise<Response> {
    try {
      const raw = await request.json();
      const diagnostic =
        new URL(request.url).pathname === "/v1/diagnostics/gemini";
      const diagnosticInput = diagnostic
        ? parseDiagnosticRequest(raw)
        : undefined;
      const input = diagnostic ? undefined : parseRequest(raw);
      if (!(await reserve(this.state.storage, "request")))
        throw new ApiError(
          429,
          "busy",
          "The team's analysis request limit was reached. Try later or use static analysis in the app.",
        );
      const key = input
        ? `${input.url.toLowerCase()}:${input.ai}`
        : `diagnostic:gemini:${diagnosticInput!.mode}`;
      let job = this.pending.get(key);
      if (!job) {
        if (this.active >= 2)
          throw new ApiError(
            429,
            "busy",
            "Two analyses are already running. Try again shortly.",
          );
        this.active++;
        job = (
          input ? this.run(input) : this.checkProvider(diagnosticInput!.mode)
        ).finally(() => {
          this.pending.delete(key);
          this.active--;
        });
        this.pending.set(key, job);
      }
      return new Response(await job, {
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Cache-Control": "no-store",
          "X-Content-Type-Options": "nosniff",
        },
      });
    } catch (error) {
      return failure(error);
    }
  }
  private async checkProvider(mode: "ping" | "story"): Promise<string> {
    return JSON.stringify(
      await diagnoseGemini(mode, {
        apiKey: this.env.GEMINI_API_KEY ?? "",
        model: this.env.GEMINI_MODEL ?? DEFAULT_MODEL,
        reserve: (retry) => reserve(this.state.storage, retry ? "retry" : "ai"),
      }),
    );
  }
  private async run(input: AnalyzeRequest): Promise<string> {
    const crawler = new GitHubCrawler();
    // Always resolve the current commit, even when the app requests a refresh.
    const snapshot = await crawler.snapshot(input.url);
    const model = this.env.GEMINI_MODEL ?? DEFAULT_MODEL;
    const cacheKey = await digest(
      `${snapshot.repository.toLowerCase()}@${snapshot.sha}:${ANALYSIS_VERSION}:${input.ai}:${model}:${PROMPT_VERSION}`,
    );
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;
    const analysis = validateAnalysis(await crawler.crawl(snapshot));
    const output = input.ai
      ? await enhance(analysis, {
          apiKey: this.env.GEMINI_API_KEY ?? "",
          model,
          reserve: (retry) =>
            reserve(this.state.storage, retry ? "retry" : "ai"),
        })
      : analysis;
    const serialized = JSON.stringify(validateAnalysis(output));
    // Never pin temporary provider/quota failures into the AI result cache.
    if (!input.ai || output.analysisKind === "ai")
      await this.cache.put(cacheKey, serialized);
    return serialized;
  }
}
