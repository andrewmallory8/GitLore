export interface SourceFile {
  path: string;
  content: string;
}
export interface Evidence {
  path: string;
  startLine: number;
  endLine: number;
}
export interface Node {
  id: string;
  label: string;
  kind: string;
  description: string;
  files: string[];
}
export interface Step {
  title: string;
  body: string;
  nodeId: string;
  evidence: Evidence[];
}
export interface Analysis {
  schemaVersion: 1;
  repository: string;
  summary: string;
  commitSha: string;
  branch: string;
  fileCount: number;
  analysisKind: "static" | "ai";
  analysisVersion: string;
  model: string | null;
  generatedAt: string | null;
  technologies: string[];
  warnings: string[];
  files: SourceFile[];
  nodes: Node[];
  edges: { from: string; to: string; kind: "imports" }[];
  steps: Step[];
}
export interface AnalyzeRequest {
  schemaVersion: 1;
  url: string;
  ai: boolean;
}
export interface Env {
  ANALYSES: DurableObjectNamespace;
  TEAM_ACCESS_TOKEN?: string;
  GEMINI_API_KEY?: string;
  GEMINI_MODEL?: string;
  ALLOWED_ORIGINS?: string;
}

export function parseDiagnosticRequest(value: unknown): {
  schemaVersion: 1;
  mode: "ping" | "story";
} {
  const input = record(value);
  if (
    input.schemaVersion !== 1 ||
    Object.keys(input).some((k) => !["schemaVersion", "mode"].includes(k)) ||
    (input.mode !== undefined &&
      input.mode !== "ping" &&
      input.mode !== "story")
  )
    throw new Error("Expected schemaVersion: 1 and optional ping/story mode");
  return { schemaVersion: 1, mode: input.mode === "story" ? "story" : "ping" };
}

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}
export function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value))
    throw new Error("Expected object");
  return value as Record<string, unknown>;
}
export function text(value: unknown, max: number, empty = false): string {
  if (
    typeof value !== "string" ||
    value.length > max ||
    (!empty && !value.trim())
  )
    throw new Error("Invalid text");
  return value;
}
export function list(value: unknown, max: number): unknown[] {
  if (!Array.isArray(value) || value.length > max)
    throw new Error("Invalid list");
  return value;
}
export function integer(value: unknown, min: number, max: number): number {
  if (
    !Number.isInteger(value) ||
    (value as number) < min ||
    (value as number) > max
  )
    throw new Error("Invalid integer");
  return value as number;
}
export function sourcePath(value: unknown): string {
  const path = text(value, 500);
  if (
    path.startsWith("/") ||
    path.includes("\\") ||
    /[\x00-\x1f\x7f]/.test(path) ||
    path.split("/").some((p) => !p || p === "." || p === "..")
  )
    throw new Error("Invalid source path");
  return path;
}
export function repositoryFromUrl(value: unknown): string {
  const invalid = () =>
    new ApiError(
      400,
      "invalid_request",
      "Enter a repository URL like https://github.com/owner/repo",
    );
  if (typeof value !== "string" || value.length > 1000) throw invalid();
  const raw = value.trim();
  // Validate raw syntax before URL normalization can erase ports/dot segments.
  const match =
    /^https:\/\/github\.com\/([a-zA-Z0-9_.-]+)\/([a-zA-Z0-9_.-]+)\/?$/.exec(
      raw,
    );
  if (!match) throw invalid();
  const owner = match[1],
    repo = match[2].replace(/\.git$/, "");
  if (
    [owner, repo].some((p) => !p || p === "." || p === "..") ||
    owner.length + repo.length + 1 > 250
  )
    throw invalid();
  return `${owner}/${repo}`;
}
export function parseRequest(raw: unknown): AnalyzeRequest {
  const data = record(raw);
  if (
    data.schemaVersion !== 1 ||
    Object.keys(data).some(
      (k) => !["schemaVersion", "url", "ai"].includes(k),
    ) ||
    ("ai" in data && typeof data.ai !== "boolean")
  )
    throw new Error("Invalid request");
  const repository = repositoryFromUrl(data.url);
  return {
    schemaVersion: 1,
    url: `https://github.com/${repository}`,
    ai: data.ai === true,
  };
}

/** Cross-reference checks supplement the published JSON schema. */
export function validateAnalysis(a: Analysis): Analysis {
  if (
    a.schemaVersion !== 1 ||
    repositoryFromUrl(`https://github.com/${a.repository}`) !== a.repository ||
    !/^[a-fA-F0-9]{40}$/.test(a.commitSha)
  )
    throw new Error("Invalid snapshot");
  text(a.summary, 12000);
  text(a.branch, 500);
  integer(a.fileCount, 0, 10000000);
  text(a.analysisVersion, 100);
  if (
    !["static", "ai"].includes(a.analysisKind) ||
    (a.model !== null && typeof a.model !== "string")
  )
    throw new Error("Invalid analysis kind");
  if (a.generatedAt !== null && !Number.isFinite(Date.parse(a.generatedAt)))
    throw new Error("Invalid timestamp");
  const files = new Map<string, SourceFile>();
  let bytes = 0;
  for (const item of list(a.files, 8)) {
    const f = item as SourceFile;
    sourcePath(f.path);
    text(f.content, 40000, true);
    if (files.has(f.path)) throw new Error("Duplicate source");
    bytes += new TextEncoder().encode(f.content).length;
    files.set(f.path, f);
  }
  if (bytes > 180000) throw new Error("Content budget exceeded");
  const nodes = new Map<string, Node>();
  for (const item of list(a.nodes, 100)) {
    const n = item as Node;
    text(n.id, 500);
    text(n.label, 500);
    text(n.kind, 100);
    text(n.description, 12000, true);
    if (nodes.has(n.id)) throw new Error("Duplicate node");
    for (const p of list(n.files, 8))
      if (!files.has(sourcePath(p))) throw new Error("Unknown node source");
    nodes.set(n.id, n);
  }
  if (!nodes.size || !a.steps.length) throw new Error("Empty result");
  for (const e of list(a.edges, 1000) as Analysis["edges"]) {
    if (
      e.kind !== "imports" ||
      !nodes.has(e.from) ||
      !nodes.has(e.to) ||
      e.from === e.to
    )
      throw new Error("Unknown edge");
  }
  for (const s of list(a.steps, 100) as Step[]) {
    text(s.title, 500);
    text(s.body, 12000);
    const node = nodes.get(s.nodeId);
    if (!node) throw new Error("Unknown chapter node");
    const evidence = list(s.evidence, 16) as Evidence[];
    if (a.analysisKind === "ai" && !evidence.length)
      throw new Error("Missing evidence");
    for (const e of evidence) {
      const f = files.get(sourcePath(e.path));
      integer(e.startLine, 1, 40000);
      integer(e.endLine, e.startLine, 40000);
      if (
        !f ||
        !node.files.includes(e.path) ||
        e.endLine > f.content.split("\n").length
      )
        throw new Error("Invalid evidence");
    }
  }
  for (const w of list(a.warnings, 100)) text(w, 3000);
  for (const t of list(a.technologies, 100)) text(t, 200);
  if (a.analysisKind === "ai") text(a.model, 100);
  if (new TextEncoder().encode(JSON.stringify(a)).length > 1500000)
    throw new Error("Response budget exceeded");
  return a;
}
