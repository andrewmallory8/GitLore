import { expect, it } from "vitest";
import {
  parseSnapshotRequest,
  analyzeSnapshot,
} from "../src/services/snapshot";
import { result, snapshotInput } from "./helpers";

it("rebuilds the graph from bounded source and labels unverified provenance", () => {
  const a = analyzeSnapshot(parseSnapshotRequest(snapshotInput()));
  expect(a.edges).toEqual(result().edges);
  expect(a.warnings.join(" ")).toContain("not independently verified");
  expect(a.analysisKind).toBe("static");
});

it.each([
  { commitSha: "not-a-commit" },
  { url: "http://169.254.169.254/private" },
  { summary: "Forged prebuilt AI result" },
  {
    files: Array.from({ length: 9 }, (_, i) => ({
      path: `${i}.js`,
      content: "x",
    })),
  },
  { files: [{ path: "../private", content: "x" }] },
  {
    files: [
      { path: "a.js", content: "x" },
      { path: "a.js", content: "y" },
    ],
  },
  { files: [{ path: "a.js", content: "é".repeat(21000) }] },
  {
    files: Array.from({ length: 5 }, (_, i) => ({
      path: `${i}.js`,
      content: "x".repeat(40000),
    })),
    fileCount: 5,
  },
])("rejects unsafe or over-budget snapshot input %#", (patch) => {
  expect(() =>
    parseSnapshotRequest({ ...snapshotInput(), ...patch }),
  ).toThrow();
});
