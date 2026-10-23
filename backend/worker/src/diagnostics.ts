import {
  type GeminiOptions,
  checkConnection,
  enhance,
} from "./services/gemini";
import { buildAnalysis } from "./services/analyzer";

/** Synthetic source only. Never fetches GitHub or accepts client-supplied prompts. */
export async function diagnoseGemini(
  mode: "ping" | "story",
  options: GeminiOptions,
) {
  if (mode === "ping") return checkConnection(options);
  const now = options.now ?? Date.now;
  const start = now();
  const files = [
    {
      path: "src/index.js",
      content:
        'import { greeting } from "./greeting.js";\nexport function handleRequest(name) {\n  return greeting(name);\n}\n',
    },
    {
      path: "src/greeting.js",
      content:
        'export function greeting(name) {\n  return "Hello, " + name;\n}\n',
    },
  ];
  const analysis = buildAnalysis(
    {
      repository: "gitlore/diagnostic-fixture",
      branch: "fixture",
      sha: "0".repeat(40),
      treeSha: "1".repeat(40),
      description: "Synthetic connection check, not a crawled repository.",
      language: "JavaScript",
    },
    files,
    files.length,
    [],
  );
  const result = await enhance(analysis, options);
  return {
    schemaVersion: 1,
    model: options.model,
    mode: "story",
    outcome: result.analysisKind === "ai" ? "ok" : "fallback",
    durationMs: Math.max(0, now() - start),
    chapters: result.analysisKind === "ai" ? result.steps.length : 0,
    evidenceChecked: result.analysisKind === "ai",
    notice: result.analysisKind === "ai" ? null : result.warnings.at(-1),
  };
}
