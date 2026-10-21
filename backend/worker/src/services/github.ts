import {
  ApiError,
  integer,
  list,
  record,
  repositoryFromUrl,
  sourcePath,
  text,
  type Analysis,
  type SourceFile,
} from "../contracts";
import { fetchJson, type Fetcher } from "../http";
import { buildAnalysis, priority, type Snapshot } from "./analyzer";

/** All requests stay on GitHub's API; repository code is never executed. */
export class GitHubCrawler {
  private deadline: number;
  constructor(
    private fetcher: Fetcher = fetch,
    private now = Date.now,
  ) {
    this.deadline = now() + 90000;
  }
  private async json(
    path: string,
    max = 8000000,
  ): Promise<Record<string, unknown>> {
    const remaining = this.deadline - this.now();
    if (remaining <= 0)
      throw new ApiError(
        504,
        "timeout",
        "GitHub analysis exceeded its time limit.",
      );
    try {
      const r = await fetchJson(
        `https://api.github.com${path}`,
        {
          headers: {
            Accept: "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "GitLore-Worker/1",
          },
        },
        max,
        Math.min(20000, remaining),
        this.fetcher,
      );
      if (r.status === 404)
        throw new ApiError(
          502,
          "github_not_found",
          "Repository or file not found. Use an existing public GitHub repository.",
        );
      if (r.status === 409)
        throw new ApiError(
          502,
          "github_empty",
          "This repository is empty. Try one with committed source files.",
        );
      if ([403, 429].includes(r.status))
        throw new ApiError(
          502,
          "github_limit",
          "GitHub denied the request or its public API limit was reached. Wait before trying again.",
        );
      if (r.status !== 200)
        throw new ApiError(
          502,
          "github_error",
          `GitHub returned HTTP ${r.status}. Please try again later.`,
        );
      return record(r.body);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(
        502,
        "github_error",
        "Could not reach or read GitHub. Please try again later.",
      );
    }
  }
  async snapshot(url: string): Promise<Snapshot> {
    const repository = repositoryFromUrl(url),
      base = `/repos/${repository}`;
    const meta = await this.json(base);
    const canonical = text(meta.full_name, 250);
    if (repositoryFromUrl(`https://github.com/${canonical}`) !== canonical)
      throw new ApiError(
        502,
        "github_error",
        "GitHub returned invalid repository metadata.",
      );
    if (!meta.default_branch)
      throw new ApiError(
        502,
        "github_empty",
        "This repository has no default branch.",
      );
    const branch = text(meta.default_branch, 500);
    const commit = await this.json(
      `${base}/commits/${encodeURIComponent(branch)}`,
    );
    const sha = text(commit.sha, 40),
      treeSha = text(record(record(commit.commit).tree).sha, 40);
    if (![sha, treeSha].every((s) => /^[a-fA-F0-9]{40}$/.test(s)))
      throw new ApiError(
        502,
        "github_error",
        "GitHub returned invalid commit metadata.",
      );
    return {
      repository: canonical,
      branch,
      sha,
      treeSha,
      description:
        meta.description == null ? null : text(meta.description, 11000, true),
      language: meta.language == null ? null : text(meta.language, 200),
    };
  }
  async crawl(snapshot: Snapshot): Promise<Analysis> {
    const base = `/repos/${snapshot.repository}`;
    const tree = await this.json(
      `${base}/git/trees/${snapshot.treeSha}?recursive=1`,
    );
    // The 8 MB transport limit also bounds the input array before sorting/scanning.
    const blobs = list(tree.tree, 200000)
      .map(record)
      .filter((e) => e.type === "blob" && e.mode !== "120000");
    const warnings = [
      "Static code tour: roles are inferred from filenames and content. Import links are not proof of runtime data flow. No LLM is used.",
    ];
    if (tree.truncated === true)
      warnings.push(
        "GitHub returned a truncated tree; the inventory is incomplete.",
      );
    const candidates: {
      path: string;
      sha: string;
      size: number;
      rank: number;
    }[] = [];
    for (const entry of blobs) {
      let path: string;
      try {
        path = sourcePath(entry.path);
      } catch {
        continue;
      }
      const rank = priority(path);
      if (
        rank <= 0 ||
        typeof entry.size !== "number" ||
        !Number.isInteger(entry.size) ||
        entry.size < 0 ||
        entry.size > 40000
      )
        continue;
      const sha = text(entry.sha, 40);
      if (!/^[a-fA-F0-9]{40}$/.test(sha)) continue;
      candidates.push({ path, sha, size: entry.size, rank });
    }
    // Dart's default string ordering is ordinal, not locale-dependent.
    candidates.sort(
      (a, b) =>
        b.rank - a.rank || (a.path < b.path ? -1 : a.path > b.path ? 1 : 0),
    );
    const files: SourceFile[] = [];
    let totalBytes = 0;
    for (const entry of candidates.slice(0, 8)) {
      if (totalBytes + entry.size > 180000) {
        warnings.push(
          `Skipped ${entry.path} to stay within the content budget.`,
        );
        continue;
      }
      try {
        const blob = await this.json(`${base}/git/blobs/${entry.sha}`, 70000);
        if (blob.encoding !== "base64") {
          warnings.push(`Skipped ${entry.path}: unsupported file encoding.`);
          continue;
        }
        let bytes: Uint8Array, content: string;
        try {
          const decoded = atob(
            text(blob.content, 70000, true).replace(/\s/g, ""),
          );
          bytes = Uint8Array.from(decoded, (c) => c.charCodeAt(0));
          if (bytes.length > 40000 || bytes.includes(0)) {
            warnings.push(`Skipped ${entry.path}: binary or too large.`);
            continue;
          }
          content = new TextDecoder("utf-8", {
            fatal: true,
            ignoreBOM: false,
          }).decode(bytes);
        } catch {
          warnings.push(`Skipped ${entry.path}: not valid UTF-8 text.`);
          continue;
        }
        if (totalBytes + bytes.length > 180000) {
          warnings.push(
            `Skipped ${entry.path} to stay within the content budget.`,
          );
          continue;
        }
        totalBytes += bytes.length;
        files.push({ path: entry.path, content });
      } catch (error) {
        if (!(error instanceof ApiError) || error.code !== "github_not_found")
          throw error;
        warnings.push(`Could not fetch ${entry.path}.`);
      }
    }
    if (!files.length)
      warnings.push(
        "No supported small text files were available; only repository metadata could be analyzed.",
      );
    warnings.push(
      `Read ${files.length} selected files out of ${blobs.length} tree entries. Files over 40 KB, generated files, and lockfiles are excluded.`,
    );
    return buildAnalysis(
      snapshot,
      files,
      integer(blobs.length, 0, 10000000),
      warnings,
    );
  }
}
