import type { Analysis, SourceFile } from "../contracts";

interface Token {
  value: string;
  string: boolean;
}
/** Matches the Dart resolver's lexical subset, including its documented limits. */
function tokens(source: string): Token[] {
  const result: Token[] = [];
  let i = 0;
  while (i < source.length) {
    const c = source[i];
    if (/\s/.test(c)) {
      i++;
      continue;
    }
    if (source.startsWith("//", i)) {
      const end = source.indexOf("\n", i + 2);
      i = end < 0 ? source.length : end + 1;
      continue;
    }
    if (source.startsWith("/*", i)) {
      const end = source.indexOf("*/", i + 2);
      i = end < 0 ? source.length : end + 2;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") {
      const start = ++i;
      let escaped = false;
      while (i < source.length && source[i] !== c) {
        if (source[i] === "\\") {
          escaped = true;
          i += 2;
        } else i++;
      }
      const closed = i < source.length;
      result.push({
        value: closed && !escaped && c !== "`" ? source.slice(start, i) : "",
        string: true,
      });
      if (closed) i++;
      continue;
    }
    if (
      c === "/" &&
      (!result.length ||
        ["=", "(", ":", ",", "return", "=>", "!", "[", ";"].includes(
          result[result.length - 1].value,
        ))
    ) {
      i++;
      let inClass = false;
      while (i < source.length) {
        const r = source[i++];
        if (r === "\\") {
          i++;
          continue;
        }
        if (r === "[") inClass = true;
        if (r === "]") inClass = false;
        if ((r === "/" && !inClass) || r === "\n") break;
      }
      result.push({ value: "", string: true });
      continue;
    }
    if (/[a-zA-Z0-9_$]/.test(c)) {
      const start = i++;
      while (i < source.length && /[a-zA-Z0-9_$]/.test(source[i])) i++;
      result.push({ value: source.slice(start, i), string: false });
    } else {
      result.push({ value: c, string: false });
      i++;
    }
  }
  return result;
}
function normalize(path: string): string {
  const parts: string[] = [];
  for (const part of path.split("/")) {
    if (!part || part === ".") continue;
    if (part === ".." && parts.length && parts[parts.length - 1] !== "..")
      parts.pop();
    else parts.push(part);
  }
  return parts.join("/");
}
export function resolveImports(files: SourceFile[]): Analysis["edges"] {
  const paths = new Set(files.map((f) => f.path)),
    seen = new Set<string>();
  const edges: Analysis["edges"] = [];
  for (const file of files) {
    const dart = file.path.endsWith(".dart");
    if (!dart && !/\.(js|jsx|ts|tsx|mjs|cjs)$/.test(file.path)) continue;
    const ts = tokens(file.content),
      specs: string[] = [];
    for (let i = 0; i < ts.length; i++) {
      const token = ts[i],
        previous = ts[i - 1]?.value;
      if (token.string || previous === "." || previous === "?") continue;
      if (
        !dart &&
        token.value === "require" &&
        ts[i + 1]?.value === "(" &&
        ts[i + 2]?.string &&
        ts[i + 3]?.value === ")"
      )
        specs.push(ts[i + 2].value);
      if (!["import", "export"].includes(token.value) || !ts[i + 1]) continue;
      if (ts[i + 1].string) {
        specs.push(ts[i + 1].value);
        continue;
      }
      if (dart || ["(", "."].includes(ts[i + 1].value)) continue;
      for (let j = i + 1; j < ts.length; j++) {
        if ([";", "=", "(", "import", "export"].includes(ts[j].value)) break;
        if (!ts[j].string && ts[j].value === "from" && ts[j + 1]?.string) {
          specs.push(ts[j + 1].value);
          break;
        }
      }
    }
    for (const spec of specs) {
      if (
        !spec ||
        (dart
          ? spec.includes(":") || spec.startsWith("/")
          : !spec.startsWith("./") && !spec.startsWith("../"))
      )
        continue;
      if (/[\\?#]/.test(spec)) continue;
      const dir = file.path.includes("/")
        ? file.path.slice(0, file.path.lastIndexOf("/") + 1)
        : "";
      const target = normalize(dir + spec);
      const extensions = dart
        ? [".dart"]
        : [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"];
      const candidates = [target];
      if (!/\.[^./]+$/.test(target)) {
        candidates.push(...extensions.map((e) => target + e));
        if (!dart)
          candidates.push(...extensions.map((e) => `${target}/index${e}`));
      }
      if (!dart && target.endsWith(".js"))
        candidates.push(
          target.slice(0, -3) + ".ts",
          target.slice(0, -3) + ".tsx",
        );
      const resolved = candidates.find((p) => paths.has(p));
      const key = JSON.stringify([file.path, resolved]);
      if (resolved && resolved !== file.path && !seen.has(key)) {
        seen.add(key);
        edges.push({ from: file.path, to: resolved, kind: "imports" });
      }
    }
  }
  return edges;
}
