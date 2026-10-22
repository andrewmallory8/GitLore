import {
  integer,
  list,
  record,
  repositoryFromUrl,
  sourcePath,
  text,
  type SourceFile,
} from "../contracts";
import { buildAnalysis } from "./analyzer";

export interface SnapshotRequest {
  schemaVersion: 1;
  url: string;
  commitSha: string;
  branch: string;
  fileCount: number;
  files: SourceFile[];
}

/** A client snapshot is untrusted source, never a trusted prebuilt graph. */
export function parseSnapshotRequest(raw: unknown): SnapshotRequest {
  const data = record(raw);
  if (
    data.schemaVersion !== 1 ||
    Object.keys(data).some(
      (k) =>
        ![
          "schemaVersion",
          "url",
          "commitSha",
          "branch",
          "fileCount",
          "files",
        ].includes(k),
    )
  )
    throw new Error("Invalid snapshot request");
  const repository = repositoryFromUrl(data.url);
  const commitSha = text(data.commitSha, 40);
  if (!/^[a-f0-9]{40}$/i.test(commitSha)) throw new Error("Invalid commit");
  let total = 0;
  const seen = new Set<string>();
  const files = list(data.files, 8).map((rawFile) => {
    const file = record(rawFile);
    if (Object.keys(file).some((k) => !["path", "content"].includes(k)))
      throw new Error("Invalid source");
    const path = sourcePath(file.path),
      content = text(file.content, 40000, true);
    const bytes = new TextEncoder().encode(content).length;
    if (seen.has(path) || bytes > 40000)
      throw new Error("Invalid source size/path");
    seen.add(path);
    total += bytes;
    return { path, content };
  });
  if (total > 180000) throw new Error("Snapshot content budget exceeded");
  return {
    schemaVersion: 1,
    url: `https://github.com/${repository}`,
    commitSha,
    branch: text(data.branch, 500),
    fileCount: integer(data.fileCount, files.length, 10000000),
    files,
  };
}

export function analyzeSnapshot(input: SnapshotRequest) {
  return buildAnalysis(
    {
      repository: repositoryFromUrl(input.url),
      branch: input.branch,
      sha: input.commitSha,
      treeSha: input.commitSha,
      description: "Client-supplied source snapshot",
      language: null,
    },
    input.files,
    input.fileCount,
    [
      "Source snapshot provided by the app; the server has not independently verified its GitHub provenance.",
    ],
  );
}
