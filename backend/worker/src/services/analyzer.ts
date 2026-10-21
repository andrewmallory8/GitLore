import type { Analysis, Node, SourceFile } from "../contracts";
import { resolveImports } from "./imports";

export const ANALYSIS_VERSION = "worker-static-v1";
const manifests = new Set([
  "package.json",
  "pubspec.yaml",
  "requirements.txt",
  "pyproject.toml",
  "Cargo.toml",
  "go.mod",
  "pom.xml",
  "Gemfile",
  "composer.json",
]);
const excluded = new Set([
  "node_modules",
  "vendor",
  "dist",
  "build",
  ".git",
  ".next",
  ".dart_tool",
  "coverage",
  "test",
  "tests",
  "__tests__",
  "fixtures",
  "examples",
  "docs",
]);
const basename = (path: string) => path.slice(path.lastIndexOf("/") + 1);
export function priority(path: string): number {
  const lower = path.toLowerCase(),
    name = basename(path),
    depth = path.split("/").length;
  if (
    path.split("/").some((p) => excluded.has(p)) ||
    lower.includes(".min.") ||
    lower.includes(".generated.") ||
    lower.endsWith(".g.dart") ||
    lower.includes(".test.") ||
    lower.includes(".spec.")
  )
    return 0;
  if (depth === 1 && lower.startsWith("readme")) return 100;
  if (manifests.has(name)) return depth === 1 ? 95 : 75 - depth;
  if (!/\.(dart|tsx?|jsx?|mjs|cjs|py|go|rs|java|rb|php|vue|svelte)$/.test(path))
    return 0;
  if (/^(main|index|app|server|manage|__init__)\./.test(name))
    return 90 - depth;
  if (
    /(^|\/)(routes?|controllers?|services?|models?|pages|api|components)(\/|\.)/.test(
      lower,
    )
  )
    return 65 - depth;
  return 40 - depth;
}
export interface Snapshot {
  repository: string;
  description: string | null;
  language: string | null;
  sha: string;
  treeSha: string;
  branch: string;
}
export function buildAnalysis(
  snapshot: Snapshot,
  files: SourceFile[],
  fileCount: number,
  warnings: string[],
): Analysis {
  const { repository, description, language, sha, branch } = snapshot;
  const technologies = new Set<string>(language ? [language] : []);
  for (const file of files) {
    const name = basename(file.path);
    if (name === "package.json") {
      try {
        const data = JSON.parse(file.content);
        const dependencies = {
          ...data?.dependencies,
          ...data?.devDependencies,
        };
        for (const dep of [
          "next",
          "react",
          "vue",
          "express",
          "fastify",
          "@nestjs/core",
          "mongoose",
          "pg",
          "prisma",
          "typescript",
        ])
          if (Object.hasOwn(dependencies, dep)) technologies.add(dep);
      } catch {
        /* The original manifest remains evidence. */
      }
    }
    if (name === "pubspec.yaml" && /^\s+flutter\s*:/m.test(file.content))
      technologies.add("Flutter");
    if (["requirements.txt", "pyproject.toml"].includes(name)) {
      for (const dep of ["django", "flask", "fastapi", "sqlalchemy"])
        if (
          new RegExp(`(^|[\\s"'])${dep}([\\s=<>~\\["']|$)`, "im").test(
            file.content,
          )
        )
          technologies.add(dep);
    }
  }
  const nodes: Node[] = [
    {
      id: "overview",
      label: "Repository overview",
      kind: "GITHUB METADATA",
      description: description?.trim()
        ? description
        : "No repository description was provided on GitHub.",
      files: [],
    },
  ];
  for (const file of files) {
    const name = basename(file.path),
      readme = name.toLowerCase().startsWith("readme"),
      manifest = manifests.has(name);
    let explanation: string;
    if (readme)
      explanation =
        "The project’s own documentation. Read the source excerpt for setup, usage, and the author’s description.";
    else if (manifest)
      explanation =
        "Declares project configuration and dependencies. A dependency declaration does not prove that it is used at runtime.";
    else if (/(^|\/)(routes?|controllers?|api)(\/|\.)/.test(file.path))
      explanation =
        "Its path suggests a request-handling component. Confirm the handlers and calls in the source; a complete request flow has not been traced.";
    else if (/(^|\/)(models?|db|database)(\/|\.)/.test(file.path))
      explanation =
        "Its path suggests data definitions or persistence code. This alone does not establish a database connection.";
    else if (/^(main|index|app|server|manage)\./.test(name))
      explanation =
        "Its filename suggests an entry point or module export. Inspect its imports and initialization code to confirm its responsibility.";
    else
      explanation =
        "A source file selected from the repository. Inspect its implementation and observed imports to understand its responsibility.";
    nodes.push({
      id: file.path,
      label: name,
      kind: readme
        ? "DOCUMENTATION"
        : manifest
          ? "DEPENDENCY MANIFEST"
          : "SOURCE · INFERRED ROLE",
      description: explanation,
      files: [file.path],
    });
  }
  return {
    schemaVersion: 1,
    repository,
    summary: `${description?.trim() ? description : `Public repository ${repository}.`} Analyzed ${files.length} selected files at commit ${sha.slice(0, 7)}. This is an evidence-backed code tour, not a verified execution trace.`,
    commitSha: sha,
    branch,
    fileCount,
    analysisKind: "static",
    analysisVersion: ANALYSIS_VERSION,
    model: null,
    generatedAt: new Date().toISOString(),
    technologies: [...technologies],
    warnings,
    files,
    nodes,
    edges: resolveImports(files),
    steps: nodes.map((n) => ({
      title: n.label,
      body: n.description,
      nodeId: n.id,
      evidence: [],
    })),
  };
}
