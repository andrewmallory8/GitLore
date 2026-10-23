import { describe, expect, it } from "vitest";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import schema from "../../contracts/analysis-v1.schema.json";
import fixture from "./fixtures/static-analysis.json";
import { result } from "./helpers";
import { priority } from "../src/services/analyzer";
import { resolveImports } from "../src/services/imports";
import { repositoryFromUrl, validateAnalysis } from "../src/contracts";

it("matches the committed Dart analyzer fixture and published v1 schema", () => {
  const output = result();
  const ajv = new Ajv2020({ allErrors: true });
  addFormats(ajv);
  const validate = ajv.compile(schema);
  expect(validate(output), JSON.stringify(validate.errors)).toBe(true);
  expect(validateAnalysis(output)).toBe(output);
  expect({
    ...output,
    analysisVersion: fixture.analysisVersion,
    generatedAt: fixture.generatedAt,
  }).toEqual(fixture);
});

it.each([
  "https://evil.test/team/repo",
  "http://github.com/team/repo",
  "https://github.com:443/team/repo",
  "https://user@github.com/team/repo",
  "https://github.com/team/../repo",
  "https://github.com/team/repo?x=1",
  "https://github.com/team/repo#x",
  "https://github.com/team/repo/tree/main",
  "https://github.com/team/%2e%2e",
  "https://github.com/team/.git",
])("rejects unsafe or unsupported repository URL %s", (url) => {
  expect(() => repositoryFromUrl(url)).toThrow();
});
it("normalizes allowed URL suffixes without accepting URL-parser rewrites", () => {
  expect(repositoryFromUrl(" https://github.com/Team/Repo.git/ ")).toBe(
    "Team/Repo",
  );
});
it("rejects fabricated evidence and invalid graph/source relationships", () => {
  const a = result();
  a.steps[0].nodeId = "missing";
  expect(() => validateAnalysis(a)).toThrow();
  const b = result();
  b.analysisKind = "ai";
  b.model = "fixture";
  expect(() => validateAnalysis(b)).toThrow();
  const c = result();
  c.edges[0].to = "missing";
  expect(() => validateAnalysis(c)).toThrow();
  const d = result();
  d.files.push({ ...d.files[0] });
  expect(() => validateAnalysis(d)).toThrow();
});
it("keeps generated/vendor/test files outside the sample", () => {
  for (const path of [
    "node_modules/x/index.js",
    "src/a.test.ts",
    "lib/a.g.dart",
    "docs/main.ts",
    "build/main.js",
  ])
    expect(priority(path)).toBe(0);
  expect(priority("README.md")).toBeGreaterThan(priority("src/index.ts"));
});
describe("lexical imports", () => {
  const targets = (content: string, path = "src/main.ts") =>
    resolveImports([
      { path, content },
      ...["src/a.ts", "src/b/index.tsx", "src/c.cjs", "src/d.dart"].map(
        (path) => ({ path, content: "" }),
      ),
    ]).map((e) => e.to);
  it("supports static declarations, reexports, literal require and JS suffix fallback", () => {
    expect(
      targets(
        "import type {A} from './a.js'; export {B} from './b'; const c = require('./c'); import './a';",
      ),
    ).toEqual(["src/a.ts", "src/b/index.tsx", "src/c.cjs"]);
  });
  it("skips comments, quoted examples, templates, regex and unsupported imports", () => {
    expect(
      targets(
        "// import './a';\n/* require('./c') */ const x = \"import './b'\"; const y = `import './a'`; const r = /require('./c')/; import('./a'); object.require('./c'); require('./a' + suffix); import a from '@/a';",
      ),
    ).toEqual([]);
  });
  it("supports interleaved comments and relative Dart directives", () => {
    expect(
      targets(
        "import /* note */ {A} from /* note */ './a'; require /* note */ ('./b');",
      ),
    ).toEqual(["src/a.ts", "src/b/index.tsx"]);
    expect(
      targets("import 'd.dart'; export './d.dart';", "src/main.dart"),
    ).toEqual(["src/d.dart"]);
    expect(targets("import './a'", "src/main.py")).toEqual([]);
  });
  it("omits self, missing, escaped and malformed paths", () => {
    expect(
      targets(
        String.raw`import './missing'; import './main.ts'; import './\x61'; import './a`,
      ),
    ).toEqual([]);
  });
});
